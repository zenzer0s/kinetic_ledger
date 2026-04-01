import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'sentiment.dart';


// ── News Article ───────────────────────────────────────────────────────────────
class NewsArticle {
  final int id;
  final String headline;
  final String summary;
  final String source;
  final String url;
  final String? imageUrl;
  final DateTime datetime;

  const NewsArticle({
    required this.id,
    required this.headline,
    required this.summary,
    required this.source,
    required this.url,
    this.imageUrl,
    required this.datetime,
  });

  Sentiment get sentiment {
    final text = '${headline.toLowerCase()} ${summary.toLowerCase()}';
    const bullish = [
      'rise', 'rises', 'surge', 'surges', 'gain', 'gains', 'rally', 'rallies',
      'strengthen', 'advance', 'advances', 'positive', 'optimism', 'beat',
      'beats', 'exceed', 'jump', 'jumps', 'climbs', 'higher', 'soars',
    ];
    const bearish = [
      'fall', 'falls', 'drop', 'drops', 'decline', 'declines', 'weaken',
      'plunge', 'plunges', 'slip', 'slips', 'lower', 'negative', 'concern',
      'fears', 'worry', 'disappoint', 'miss', 'recession', 'slowdown',
      'pressure', 'tumbles', 'sinks', 'slumps',
    ];
    final b = bullish.where((w) => text.contains(w)).length;
    final r = bearish.where((w) => text.contains(w)).length;
    if (b > r) return Sentiment.bullish;
    if (r > b) return Sentiment.bearish;
    return Sentiment.neutral;
  }

  String get timeAgo {
    final d = DateTime.now().difference(datetime);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  factory NewsArticle.fromJson(Map<String, dynamic> j) => NewsArticle(
        id: (j['id'] as num?)?.toInt() ?? 0,
        headline: j['headline'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        source: j['source'] as String? ?? '',
        url: j['url'] as String? ?? '',
        imageUrl: j['image'] as String?,
        datetime: DateTime.fromMillisecondsSinceEpoch(
            ((j['datetime'] as num?)?.toInt() ?? 0) * 1000),
      );
}

// ── Economic Event ─────────────────────────────────────────────────────────────
class EconomicEvent {
  final String event;
  final String country;
  final String impact; // high | medium | low
  final DateTime time;
  final String? actual;
  final String? estimate;
  final String? previous;
  final String unit;

  const EconomicEvent({
    required this.event,
    required this.country,
    required this.impact,
    required this.time,
    this.actual,
    this.estimate,
    this.previous,
    required this.unit,
  });

  String get flag => _currencyFlag[country] ?? '🌐';

  String get timeLabel {
    final diff = time.difference(DateTime.now());
    if (diff.isNegative) {
      final ago = diff.abs();
      if (ago.inHours < 24) return '${ago.inHours}h ago';
      return '${ago.inDays}d ago';
    }
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'in ${diff.inHours}h';
    if (diff.inDays == 1) return 'Tomorrow';
    return 'in ${diff.inDays}d';
  }

  bool get isPast => time.isBefore(DateTime.now());

  factory EconomicEvent.fromJson(Map<String, dynamic> j) {
    DateTime t = DateTime.now();
    try { t = DateTime.parse(j['time'] as String? ?? ''); } catch (_) {}
    return EconomicEvent(
      event: j['event'] as String? ?? '',
      country: j['country'] as String? ?? '',
      impact: j['impact'] as String? ?? 'low',
      time: t,
      actual: j['actual']?.toString(),
      estimate: j['estimate']?.toString(),
      previous: j['prev']?.toString(),
      unit: j['unit'] as String? ?? '',
    );
  }

  /// Parse Forex Factory JSON format.
  /// FF fields: title, country (currency code), date (ISO), time (HH:mm:ss UTC), impact, forecast, previous, actual
  factory EconomicEvent.fromForexFactory(Map<String, dynamic> j) {
    final dateStr = j['date'] as String? ?? '';
    final timeStr = j['time'] as String? ?? '';
    DateTime t = DateTime.now();
    try {
      // FF date: '2025-04-01T00:00:00-0400' or '2025-04-01'
      if (dateStr.contains('T')) {
        t = DateTime.parse(dateStr).toLocal();
      } else {
        final d = DateTime.parse(dateStr);
        // time like '08:30:00' or empty
        if (timeStr.isNotEmpty && timeStr != 'Tentative' && timeStr != 'All Day') {
          final parts = timeStr.split(':');
          final h = int.tryParse(parts[0]) ?? 0;
          final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
          // FF times are UTC
          t = DateTime.utc(d.year, d.month, d.day, h, m).toLocal();
        } else {
          t = DateTime(d.year, d.month, d.day, 12, 0);
        }
      }
    } catch (_) {}

    final impactRaw = (j['impact'] as String? ?? '').toLowerCase();
    final impact = impactRaw == 'high'
        ? 'high'
        : impactRaw == 'medium' || impactRaw == 'moderate'
            ? 'medium'
            : 'low';

    return EconomicEvent(
      event: j['title'] as String? ?? '',
      country: j['country'] as String? ?? '',
      impact: impact,
      time: t,
      actual: (j['actual'] as String?)?.isNotEmpty == true ? j['actual'] as String : null,
      estimate: (j['forecast'] as String?)?.isNotEmpty == true ? j['forecast'] as String : null,
      previous: (j['previous'] as String?)?.isNotEmpty == true ? j['previous'] as String : null,
      unit: '',
    );
  }
} // end EconomicEvent

// ─────────────────────────────────────────────────────────────────────────────
// Currency → flag map (supports both currency codes and ISO-2)
// ─────────────────────────────────────────────────────────────────────────────
const _currencyFlag = {
  'USD': '🇺🇸', 'EUR': '🇪🇺', 'GBP': '🇬🇧', 'JPY': '🇯🇵',
  'CHF': '🇨🇭', 'AUD': '🇦🇺', 'CAD': '🇨🇦', 'NZD': '🇳🇿',
  'CNY': '🇨🇳', 'INR': '🇮🇳', 'ALL': '🌐',
  'US': '🇺🇸', 'EU': '🇪🇺', 'GB': '🇬🇧', 'JP': '🇯🇵',
  'CH': '🇨🇭', 'AU': '🇦🇺', 'CA': '🇨🇦', 'NZ': '🇳🇿',
  'CN': '🇨🇳', 'IN': '🇮🇳', 'DE': '🇩🇪', 'FR': '🇫🇷',
  'SG': '🇸🇬', 'HK': '🇭🇰',
};

// ─────────────────────────────────────────────────────────────────────────────
// NewsService
// ─────────────────────────────────────────────────────────────────────────────
class NewsService {
  static const _key = 'd76kj89r01qtg3nduoj0d76kj89r01qtg3nduojg';
  static const _base = 'https://finnhub.io/api/v1';

  Future<List<NewsArticle>> fetchNews() async {
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$_base/news?category=forex&token=$_key')),
        http.get(Uri.parse('$_base/news?category=general&token=$_key')),
      ]);

      final all = <NewsArticle>[];
      for (final r in results) {
        if (r.statusCode == 200) {
          final list = jsonDecode(r.body) as List;
          all.addAll(list.map((e) => NewsArticle.fromJson(e)));
        }
      }

      final seen = <int>{};
      return all
          .where((a) => a.headline.isNotEmpty && seen.add(a.id))
          .toList()
        ..sort((a, b) => b.datetime.compareTo(a.datetime));
    } catch (_) {
      return [];
    }
  }

  // ── Calendar cache keys ────────────────────────────────────────────────────
  static const _calDataKey = 'cal_cache_v1_data';
  static const _calTsKey   = 'cal_cache_v1_ts';
  static const _calDayKey  = 'cal_cache_v1_day';
  /// Cache valid for 4 hours or until the calendar day rolls over.
  static const _calTtl = Duration(hours: 4);

  /// Returns economic calendar. Serves from SharedPreferences cache when fresh.
  /// Pass [forceRefresh] = true (pull-to-refresh) to bypass cache.
  Future<List<EconomicEvent>> fetchCalendar({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month}-${now.day}';

    // ── Try cache ──────────────────────────────────────────────────────────
    if (!forceRefresh) {
      final cachedJson = prefs.getString(_calDataKey);
      final cachedTs   = prefs.getInt(_calTsKey);
      final cachedDay  = prefs.getString(_calDayKey);

      if (cachedJson != null && cachedTs != null && cachedDay != null) {
        final age = now.millisecondsSinceEpoch - cachedTs;
        final fresh = age < _calTtl.inMilliseconds && cachedDay == todayStr;
        if (fresh) {
          debugPrint('[Calendar] Cache HIT (age ${(age / 60000).toStringAsFixed(1)}min)');
          try {
            final raw = jsonDecode(cachedJson) as List;
            final events = <EconomicEvent>[];
            for (final item in raw) {
              try {
                events.add(EconomicEvent.fromForexFactory(item as Map<String, dynamic>));
              } catch (_) {}
            }
            if (events.isNotEmpty) {
              return events..sort((a, b) => a.time.compareTo(b.time));
            }
          } catch (_) {}
        } else {
          debugPrint('[Calendar] Cache MISS (${fresh ? "stale" : cachedDay != todayStr ? "new day" : "expired"})');
        }
      } else {
        debugPrint('[Calendar] Cache MISS (no data)');
      }
    } else {
      debugPrint('[Calendar] Force refresh — bypassing cache');
    }

    // ── Fetch from Forex Factory ───────────────────────────────────────────
    try {
      final results = await Future.wait([
        http.get(
          Uri.parse('https://nfs.faireconomy.media/ff_calendar_thisweek.json'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 12)),
        http.get(
          Uri.parse('https://nfs.faireconomy.media/ff_calendar_nextweek.json'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 12)),
      ]);

      final rawItems = <dynamic>[];
      for (final r in results) {
        if (r.statusCode == 200) {
          rawItems.addAll(jsonDecode(r.body) as List);
        }
      }

      if (rawItems.isNotEmpty) {
        // Persist raw JSON so we can deserialize it later
        await prefs.setString(_calDataKey, jsonEncode(rawItems));
        await prefs.setInt(_calTsKey, now.millisecondsSinceEpoch);
        await prefs.setString(_calDayKey, todayStr);
        debugPrint('[Calendar] Fetched ${rawItems.length} events from Forex Factory — cached');

        final events = <EconomicEvent>[];
        for (final item in rawItems) {
          try {
            events.add(EconomicEvent.fromForexFactory(item as Map<String, dynamic>));
          } catch (_) {}
        }
        return events..sort((a, b) => a.time.compareTo(b.time));
      }
    } catch (e) {
      debugPrint('[Calendar] FF fetch error: $e — trying Finnhub fallback');
    }

    // ── Fallback: Finnhub (limited free tier) ──────────────────────────────
    try {
      String fmt(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final from = fmt(now.subtract(const Duration(days: 2)));
      final to   = fmt(now.add(const Duration(days: 30)));
      final r = await http
          .get(Uri.parse('$_base/calendar/economic?from=$from&to=$to&token=$_key'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final list = (data['economicCalendar'] as List? ?? []);
        debugPrint('[Calendar] Finnhub returned ${list.length} events');
        return list.map((e) => EconomicEvent.fromJson(e)).toList()
          ..sort((a, b) => a.time.compareTo(b.time));
      }
    } catch (_) {}

    // ── Last resort: serve stale cache if present ──────────────────────────
    final stale = prefs.getString(_calDataKey);
    if (stale != null) {
      debugPrint('[Calendar] Serving stale cache as last resort');
      try {
        final raw = jsonDecode(stale) as List;
        final events = <EconomicEvent>[];
        for (final item in raw) {
          try { events.add(EconomicEvent.fromForexFactory(item as Map<String, dynamic>)); } catch (_) {}
        }
        if (events.isNotEmpty) return events..sort((a, b) => a.time.compareTo(b.time));
      } catch (_) {}
    }

    return [];
  }

  /// Call this to wipe the calendar cache (e.g. from a debug menu).
  static Future<void> clearCalendarCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_calDataKey);
    await prefs.remove(_calTsKey);
    await prefs.remove(_calDayKey);
    debugPrint('[Calendar] Cache cleared');
  }
}
