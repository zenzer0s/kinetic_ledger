import 'dart:io';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'news_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Notification IDs (deterministic so we can cancel by ID)
// ─────────────────────────────────────────────────────────────────────────────
// 0        — reserved (daily digest)
// 1–499    — 15-min pre-event alerts
// 500–999  — 5-min pre-event alerts
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _scheduling = false; // mutex: prevents concurrent scheduling runs

  // ── Android notification channels ─────────────────────────────────────────
  static const _channelPreEvent = AndroidNotificationChannel(
    'zenith_pre_event',
    'Pre-Event Alerts',
    description: 'Alerts 15 and 5 minutes before high-impact economic events',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Color(0xFFEF4444),
  );

  static const _channelDigest = AndroidNotificationChannel(
    'zenith_digest',
    'Daily Digest',
    description: 'Morning summary of today\'s high-impact economic events',
    importance: Importance.defaultImportance,
    playSound: false,
  );

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    // Timezone setup — use Dart's built-in localeName
    tz.initializeTimeZones();
    try {
      // DateTime.now().timeZoneName gives 'IST', 'EST', 'PST', etc.
      // We try matching it; fall back to UTC offset if unknown.
      final tzName = _resolveLocalTz();
      tz.setLocalLocation(tz.getLocation(tzName));
      debugPrint('[Notifications] Timezone: $tzName');
    } catch (e) {
      // Last resort: derive from UTC offset
      final offset = DateTime.now().timeZoneOffset;
      final sign = offset.isNegative ? '-' : '+';
      final h = offset.inHours.abs().toString().padLeft(2, '0');
      final m = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
      debugPrint('[Notifications] TZ fallback UTC$sign$h:$m — $e');
    }

    // Android init settings — use app icon
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Create channels (Android 8+)
    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channelPreEvent);
    await android?.createNotificationChannel(_channelDigest);

    _initialized = true;
    debugPrint('[Notifications] Initialized');
  }

  // ── Permission request ────────────────────────────────────────────────────
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission() ?? false;
      debugPrint('[Notifications] Android permission granted: $granted');
      return granted;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      debugPrint('[Notifications] iOS permission granted: $granted');
      return granted;
    }
    return false;
  }

  // ── Schedule all Tier-1 alerts from calendar data ─────────────────────────
  /// Call this every time fresh calendar data is loaded.
  /// Cancels all previous event alerts before rescheduling.
  Future<void> scheduleCalendarAlerts(List<EconomicEvent> events) async {
    if (!_initialized) await init();
    // Drop concurrent calls — only one scheduling run at a time
    if (_scheduling) {
      debugPrint('[Notifications] Scheduling already in progress, skipping');
      return;
    }
    _scheduling = true;

    try {
      // Cancel all existing notifications in one call (not a 999-loop)
      await _plugin.cancelAll();
      final now = DateTime.now();
      int alertIndex15 = 1;
      int alertIndex5 = 500;

      // Only schedule HIGH impact events in the next 7 days
      final upcoming = events.where((e) {
        if (e.impact.toLowerCase() != 'high') return false;
        if (e.time.isBefore(now)) return false;
        if (e.time.difference(now).inDays > 7) return false;
        return true;
      }).toList();

      debugPrint('[Notifications] Scheduling alerts for ${upcoming.length} HIGH events');

      for (final event in upcoming) {
        final fireAt15 = event.time.subtract(const Duration(minutes: 15));
        final fireAt5 = event.time.subtract(const Duration(minutes: 5));

        // ── 15-min warning ──────────────────────────────────────────────────
        if (fireAt15.isAfter(now) && alertIndex15 < 500) {
          await _schedulePreEvent(
            id: alertIndex15++,
            event: event,
            fireAt: fireAt15,
            minutesBefore: 15,
          );
        }

        // ── 5-min warning ───────────────────────────────────────────────────
        if (fireAt5.isAfter(now) && alertIndex5 < 1000) {
          await _schedulePreEvent(
            id: alertIndex5++,
            event: event,
            fireAt: fireAt5,
            minutesBefore: 5,
          );
        }
      }

      debugPrint('[Notifications] Scheduled ${alertIndex15 - 1} × 15min + '
          '${alertIndex5 - 500} × 5min alerts');
    } finally {
      _scheduling = false;
    }
  }

  Future<void> _schedulePreEvent({
    required int id,
    required EconomicEvent event,
    required DateTime fireAt,
    required int minutesBefore,
  }) async {
    final isUrgent = minutesBefore <= 5;
    final impact = event.impact.toLowerCase();
    final emoji = impact == 'high' ? '🔴' : impact == 'medium' ? '🟡' : '🔵';

    final title = '$emoji $minutesBefore min — ${event.event}';

    // Build body with available data
    final parts = <String>[];
    if (event.estimate != null) parts.add('Forecast: ${event.estimate}${event.unit}');
    if (event.previous != null) parts.add('Prev: ${event.previous}${event.unit}');
    final body = parts.isNotEmpty ? parts.join('  •  ') : 'XAU/USD watch level';

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(fireAt, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelPreEvent.id,
            _channelPreEvent.name,
            channelDescription: _channelPreEvent.description,
            importance: isUrgent ? Importance.max : Importance.high,
            priority: isUrgent ? Priority.max : Priority.high,
            ticker: title,
            icon: '@mipmap/ic_launcher',
            color: isUrgent
                ? const Color(0xFFEF4444)
                : const Color(0xFFFBBF24),
            enableLights: true,
            ledColor: const Color(0xFFEF4444),
            ledOnMs: 500,
            ledOffMs: 1000,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'pre_event',
            interruptionLevel: isUrgent
                ? InterruptionLevel.timeSensitive
                : InterruptionLevel.active,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('[Notifications] Scheduled ${minutesBefore}min alert: ${event.event} @ $fireAt');
    } catch (e) {
      debugPrint('[Notifications] Failed to schedule: $e');
    }
  }

  // ── Daily Digest — 7:00 AM local time ────────────────────────────────────
  Future<void> scheduleDailyDigest(List<EconomicEvent> events) async {
    if (!_initialized) await init();
    await _plugin.cancel(0); // Cancel existing digest

    final today = DateTime.now();
    final todayHighCount = events.where((e) {
      return e.impact.toLowerCase() == 'high' &&
          e.time.year == today.year &&
          e.time.month == today.month &&
          e.time.day == today.day;
    }).length;

    final tomorrow = today.add(const Duration(days: 1));
    final fire = tz.TZDateTime(
      tz.local,
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      7, // 7:00 AM
    );

    // Build a preview of tomorrow's high-impact events
    final tomorrowEvents = events
        .where((e) =>
            e.impact.toLowerCase() == 'high' &&
            e.time.year == tomorrow.year &&
            e.time.month == tomorrow.month &&
            e.time.day == tomorrow.day)
        .take(3)
        .map((e) => '• ${e.flag} ${e.event}')
        .join('\n');

    final body = tomorrowEvents.isNotEmpty
        ? tomorrowEvents
        : 'No high-impact events tomorrow.';

    const title = '📅 Today\'s Market Calendar';
    final todayBody = todayHighCount > 0
        ? '$todayHighCount HIGH impact event${todayHighCount > 1 ? "s" : ""} today — stay sharp!'
        : 'Light economic news today.';

    try {
      // Today's digest (show immediately if before 7AM, else tomorrow)
      final now = DateTime.now();
      final todayFire = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        7,
      );
      final digestFire = todayFire.isAfter(tz.TZDateTime.now(tz.local))
          ? todayFire
          : fire; // tomorrow 7AM

      await _plugin.zonedSchedule(
        0,
        title,
        todayBody,
        digestFire,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelDigest.id,
            _channelDigest.name,
            channelDescription: _channelDigest.description,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            styleInformation: BigTextStyleInformation(
              '$todayBody\n\nTomorrow:\n$body',
              contentTitle: title,
            ),
          ),
          iOS: const DarwinNotificationDetails(
            categoryIdentifier: 'daily_digest',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // repeats daily
      );
      debugPrint('[Notifications] Daily digest scheduled @ ${digestFire.toLocal()}');
    } catch (e) {
      debugPrint('[Notifications] Digest schedule failed: $e');
    }
  }

  // ── Cancel all ────────────────────────────────────────────────────────────
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('[Notifications] All notifications cancelled');
  }

  // ── Pending count (for debug) ─────────────────────────────────────────────
  Future<int> pendingCount() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.length;
  }

  // ── Timezone resolution without native plugin ─────────────────────────────
  /// Maps common TZ abbreviations to IANA names. Falls back to UTC+offset name.
  static String _resolveLocalTz() {
    final abbr = DateTime.now().timeZoneName;
    // Common mappings
    const map = {
      'IST': 'Asia/Kolkata',
      'EST': 'America/New_York',
      'EDT': 'America/New_York',
      'CST': 'America/Chicago',
      'CDT': 'America/Chicago',
      'MST': 'America/Denver',
      'MDT': 'America/Denver',
      'PST': 'America/Los_Angeles',
      'PDT': 'America/Los_Angeles',
      'GMT': 'Europe/London',
      'BST': 'Europe/London',
      'CET': 'Europe/Paris',
      'CEST': 'Europe/Paris',
      'JST': 'Asia/Tokyo',
      'AEST': 'Australia/Sydney',
      'AEDT': 'Australia/Sydney',
      'SGT': 'Asia/Singapore',
      'HKT': 'Asia/Hong_Kong',
      'UAE': 'Asia/Dubai',
      'GST': 'Asia/Dubai',
      'PKT': 'Asia/Karachi',
      'BDT': 'Asia/Dhaka',
      'ICT': 'Asia/Bangkok',
      'WIB': 'Asia/Jakarta',
      'KST': 'Asia/Seoul',
    };
    return map[abbr] ?? 'UTC';
  }
}
