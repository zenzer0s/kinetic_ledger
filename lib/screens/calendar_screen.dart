import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/news_provider.dart';
import '../services/cerebras_service.dart';
import '../services/news_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILTER ENUM
// ─────────────────────────────────────────────────────────────────────────────
enum CalFilter { all, high, usd, eur, gbp }

// ─────────────────────────────────────────────────────────────────────────────
// ECONOMIC CALENDAR WIDGET (drop-in for the calendar tab)
// ─────────────────────────────────────────────────────────────────────────────
class EconomicCalendarWidget extends ConsumerStatefulWidget {
  final ZenithColors zc;
  const EconomicCalendarWidget({super.key, required this.zc});

  @override
  ConsumerState<EconomicCalendarWidget> createState() =>
      _EconomicCalendarWidgetState();
}

class _EconomicCalendarWidgetState
    extends ConsumerState<EconomicCalendarWidget>
    with TickerProviderStateMixin {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;
  CalFilter _filter = CalFilter.all;

  late AnimationController _gridCtrl;
  late Animation<double> _gridAnim;
  late AnimationController _listCtrl;
  late Animation<double> _listAnim;
  late Timer _ticker;
  Duration _countdown = Duration.zero;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();

    _gridCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _gridAnim = CurvedAnimation(parent: _gridCtrl, curve: Curves.easeOutCubic);
    _gridCtrl.forward();

    _listCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _listAnim = CurvedAnimation(parent: _listCtrl, curve: Curves.easeOutCubic);
    _listCtrl.forward();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _gridCtrl.dispose();
    _listCtrl.dispose();
    _ticker.cancel();
    super.dispose();
  }

  List<EconomicEvent> _applyFilter(List<EconomicEvent> events) {
    switch (_filter) {
      case CalFilter.all:
        return events;
      case CalFilter.high:
        return events.where((e) => e.impact.toLowerCase() == 'high').toList();
      case CalFilter.usd:
        // FF uses 'USD', Finnhub uses 'US'
        return events.where((e) => e.country == 'USD' || e.country == 'US').toList();
      case CalFilter.eur:
        return events.where((e) => e.country == 'EUR' || e.country == 'EU' || e.country == 'DE').toList();
      case CalFilter.gbp:
        return events.where((e) => e.country == 'GBP' || e.country == 'GB').toList();
    }
  }

  List<EconomicEvent> _eventsForDay(
      List<EconomicEvent> all, DateTime day) {
    return all.where((e) {
      return e.time.year == day.year &&
          e.time.month == day.month &&
          e.time.day == day.day;
    }).toList();
  }

  EconomicEvent? _nextHighImpact(List<EconomicEvent> events) {
    final now = DateTime.now();
    final upcoming = events
        .where((e) => e.impact.toLowerCase() == 'high' && e.time.isAfter(now))
        .toList();
    if (upcoming.isEmpty) return null;
    return upcoming.reduce(
        (a, b) => a.time.isBefore(b.time) ? a : b);
  }

  void _changeMonth(int delta) {
    _gridCtrl.reset();
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + delta,
      );
      _selectedDay = null;
    });
    _gridCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final zc = widget.zc;
    final async = ref.watch(calendarProvider);

    return async.when(
      loading: () => _CalendarSkeleton(zc: zc),
      error: (e, _) => _CalendarError(
        zc: zc,
        onRetry: () => ref.invalidate(calendarProvider),
      ),
      data: (rawEvents) {
        final events = _applyFilter(rawEvents);
        final selectedEvents = _selectedDay != null
            ? _eventsForDay(events, _selectedDay!)
            : <EconomicEvent>[];
        final topEvent = _nextHighImpact(rawEvents);
        if (topEvent != null) {
          _countdown = topEvent.time.difference(DateTime.now());
        }

        return RefreshIndicator(
          onRefresh: () async {
            await NewsService.clearCalendarCache();
            ref.invalidate(calendarProvider);
          },
          color: zc.accent,
          backgroundColor: zc.surface,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Countdown Banner ─────────────────────────────────────
              if (topEvent != null)
                SliverToBoxAdapter(
                  child: _CountdownBanner(
                    zc: zc,
                    event: topEvent,
                    countdown: _countdown,
                  ),
                ),

              // ── Filter Chips ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: _FilterRow(
                    selected: _filter,
                    zc: zc,
                    onChanged: (f) {
                      HapticFeedback.selectionClick();
                      setState(() => _filter = f);
                    },
                  ),
                ),
              ),

              // ── Month Header ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _MonthHeader(
                    month: _focusedMonth,
                    zc: zc,
                    onPrev: () => _changeMonth(-1),
                    onNext: () => _changeMonth(1),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // ── Calendar Grid ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _gridAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _CalendarGrid(
                      focusedMonth: _focusedMonth,
                      allEvents: events,
                      selectedDay: _selectedDay,
                      zc: zc,
                      onDayTap: (day) {
                        HapticFeedback.selectionClick();
                        _listCtrl.reset();
                        setState(() => _selectedDay = day);
                        _listCtrl.forward();
                      },
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Day divider ───────────────────────────────────────────
              if (_selectedDay != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Text(
                          _dayLabel(_selectedDay!),
                          style: GoogleFonts.chakraPetch(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: zc.textDim,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: zc.border,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: zc.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '${selectedEvents.length} events',
                            style: GoogleFonts.chakraPetch(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: zc.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // ── Events for selected day ───────────────────────────────
              if (selectedEvents.isEmpty && _selectedDay != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Center(
                      child: Text(
                        'No events scheduled',
                        style: GoogleFonts.chakraPetch(
                          fontSize: 13,
                          color: zc.textDim,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      // Guard against stale index after setState
                      if (i >= selectedEvents.length) return null;
                      return FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _listAnim,
                          curve: Interval(
                            (i * 0.12).clamp(0.0, 0.7),
                            1.0,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.12),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _listAnim,
                            curve: Interval(
                              (i * 0.12).clamp(0.0, 0.7),
                              1.0,
                              curve: Curves.easeOutCubic,
                            ),
                          )),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _EventCard(
                              event: selectedEvents[i],
                              zc: zc,
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: selectedEvents.length,
                  ),
                ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).viewPadding.bottom + 120,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final diff = DateTime(d.year, d.month, d.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'TOMORROW';
    if (diff == -1) return 'YESTERDAY';
    final months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return '${days[(d.weekday - 1) % 7]}  ${d.day} ${months[d.month - 1]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COUNTDOWN BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _CountdownBanner extends StatelessWidget {
  final ZenithColors zc;
  final EconomicEvent event;
  final Duration countdown;
  const _CountdownBanner({
    required this.zc,
    required this.event,
    required this.countdown,
  });

  @override
  Widget build(BuildContext context) {
    final isNear = countdown.inHours < 1;
    final color = isNear ? zc.red : zc.accent;

    final hh = countdown.inHours.toString().padLeft(2, '0');
    final mm = (countdown.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (countdown.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 4, 24, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: isNear ? zc.red : zc.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isNear ? zc.red : zc.green).withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT HIGH IMPACT',
                  style: GoogleFonts.chakraPetch(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: color.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${event.flag} ${event.event}',
                  style: GoogleFonts.chakraPetch(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: zc.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Live countdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              countdown.isNegative ? 'LIVE' : '$hh:$mm:$ss',
              style: GoogleFonts.chakraPetch(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER ROW
// ─────────────────────────────────────────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  final CalFilter selected;
  final ZenithColors zc;
  final ValueChanged<CalFilter> onChanged;

  const _FilterRow({
    required this.selected,
    required this.zc,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const filters = [
      (CalFilter.all, 'ALL'),
      (CalFilter.high, '🔴 HIGH'),
      (CalFilter.usd, '🇺🇸 USD'),
      (CalFilter.eur, '🇪🇺 EUR'),
      (CalFilter.gbp, '🇬🇧 GBP'),
    ];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final (filter, label) = filters[i];
          final active = selected == filter;
          return GestureDetector(
            onTap: () => onChanged(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? zc.accent.withValues(alpha: 0.15)
                    : zc.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active
                      ? zc.accent.withValues(alpha: 0.4)
                      : zc.border,
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.chakraPetch(
                  fontSize: 11,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? zc.accentSoft : zc.textMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MONTH HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final ZenithColors zc;
  final VoidCallback onPrev, onNext;

  const _MonthHeader({
    required this.month,
    required this.zc,
    required this.onPrev,
    required this.onNext,
  });

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '${_months[month.month - 1]} ${month.year}',
          style: GoogleFonts.chakraPetch(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: zc.textPrimary,
          ),
        ),
        const Spacer(),
        _NavBtn(zc: zc, icon: Icons.chevron_left_rounded, onTap: onPrev),
        const SizedBox(width: 4),
        _NavBtn(zc: zc, icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  final ZenithColors zc;
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.zc, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: zc.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: zc.border),
        ),
        child: Icon(icon, color: zc.textMuted, size: 18),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CALENDAR GRID
// ─────────────────────────────────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final List<EconomicEvent> allEvents;
  final DateTime? selectedDay;
  final ZenithColors zc;
  final ValueChanged<DateTime> onDayTap;

  const _CalendarGrid({
    required this.focusedMonth,
    required this.allEvents,
    required this.selectedDay,
    required this.zc,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    // Monday=1 → offset 0, Sunday=7 → offset 6
    final startOffset = (firstDay.weekday - 1) % 7;
    final today = DateTime.now();
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    // Pre-compute event dots per day
    final dotMap = <int, List<String>>{}; // day → [impact colors]
    for (final e in allEvents) {
      if (e.time.month == focusedMonth.month &&
          e.time.year == focusedMonth.year) {
        dotMap.putIfAbsent(e.time.day, () => []).add(e.impact);
      }
    }

    return Column(
      children: [
        // Weekday headers
        Row(
          children: weekdays
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: GoogleFonts.chakraPetch(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: zc.textDim,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),

        // Grid cells
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.9,
          ),
          itemCount: startOffset + daysInMonth,
          itemBuilder: (ctx, index) {
            if (index < startOffset) return const SizedBox();
            final day = index - startOffset + 1;
            final date =
                DateTime(focusedMonth.year, focusedMonth.month, day);
            final isToday = date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
            final isSelected = selectedDay != null &&
                date.year == selectedDay!.year &&
                date.month == selectedDay!.month &&
                date.day == selectedDay!.day;
            final isPast = date.isBefore(DateTime(today.year, today.month, today.day));
            final dots = dotMap[day] ?? [];
            final hasHigh = dots.contains('high');
            final hasMed = dots.contains('medium');
            final hasLow = dots.contains('low');

            return GestureDetector(
              onTap: () => onDayTap(date),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? zc.accent.withValues(alpha: 0.18)
                      : isToday
                          ? zc.accent.withValues(alpha: 0.08)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? zc.accent.withValues(alpha: 0.5)
                        : isToday
                            ? zc.accent.withValues(alpha: 0.3)
                            : Colors.transparent,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: GoogleFonts.chakraPetch(
                        fontSize: 13,
                        fontWeight: isToday || isSelected
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: isPast && !isToday && !isSelected
                            ? zc.textDim.withValues(alpha: 0.4)
                            : isSelected
                                ? zc.accentSoft
                                : isToday
                                    ? zc.accent
                                    : zc.textPrimary,
                      ),
                    ),
                    if (dots.isNotEmpty)
                      const SizedBox(height: 2),
                    if (dots.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasHigh)
                            _Dot(color: const Color(0xFFEF4444)),
                          if (hasMed)
                            _Dot(color: const Color(0xFFFBBF24)),
                          if (hasLow && !hasHigh && !hasMed)
                            _Dot(color: const Color(0xFF3B82F6)),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 3,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EVENT CARD  (tap to expand + AI summary)
// ─────────────────────────────────────────────────────────────────────────────
class _EventCard extends StatefulWidget {
  final EconomicEvent event;
  final ZenithColors zc;
  const _EventCard({required this.event, required this.zc});

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard>
    with TickerProviderStateMixin {
  // Press animation
  late AnimationController _pressCtrl;
  late Animation<double> _scale;

  // Expand animation
  late AnimationController _expandCtrl;
  late Animation<double> _expandAnim;

  // Glow animation (today's upcoming events only)
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  bool _isExpanded = false;

  // Inline impact analysis (shown collapsed)
  String? _aiAnalysis;
  bool _aiLoading = false;

  // Expanded: "what happened" summary
  String? _summary;
  bool _summaryLoading = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );

    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _expandAnim = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeOutCubic,
    );

    // Auto-load impact analysis for HIGH impact events
    if (widget.event.impact.toLowerCase() == 'high') {
      _loadAiAnalysis();
    }

    // Glow controller — pulses for today's future events
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
    if (_isUpcomingToday(widget.event)) {
      _glowCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _expandCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAiAnalysis() async {
    if (_aiLoading || _aiAnalysis != null) return;
    setState(() => _aiLoading = true);
    final e = widget.event;
    final result = await CerebrasSentimentService().analyzeCalendarEvent(
      eventName: e.event,
      country: e.country,
      impact: e.impact,
      estimate: e.estimate,
      previous: e.previous,
    );
    if (mounted) {
      setState(() {
        _aiAnalysis = result.isEmpty ? null : result;
        _aiLoading = false;
      });
    }
  }

  Future<void> _loadSummary() async {
    if (_summaryLoading || _summary != null) return;
    setState(() => _summaryLoading = true);
    final e = widget.event;
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateLabel = '${months[e.time.month - 1]} ${e.time.day}, ${e.time.year}';
    final result = await CerebrasSentimentService().getEventNewsSummary(
      eventName: e.event,
      country: e.country,
      isPast: e.isPast,
      actual: e.actual,
      estimate: e.estimate,
      previous: e.previous,
      dateLabel: dateLabel,
    );
    if (mounted) {
      setState(() {
        _summary = result.isEmpty ? null : result;
        _summaryLoading = false;
      });
    }
  }

  void _toggleExpand() {
    HapticFeedback.selectionClick();
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _expandCtrl.forward();
      _loadSummary();
      if (_aiAnalysis == null) _loadAiAnalysis();
    } else {
      _expandCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final zc = widget.zc;
    final (impactColor, impactLabel) = _impactStyle(e.impact, zc);
    final isPast = e.isPast;
    final isUpcomingToday = _isUpcomingToday(e);
    final sessionLabel = _sessionLabel(e.time);

    return ScaleTransition(
      scale: _scale,
      child: AnimatedBuilder(
        animation: _glowAnim,
        builder: (ctx, child) {
          final glow = isUpcomingToday ? _glowAnim.value : 0.0;
          return Opacity(
            opacity: isPast ? 0.38 : 1.0,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                // Pulsing outer glow for upcoming today events
                boxShadow: isUpcomingToday
                    ? [
                        BoxShadow(
                          color: impactColor
                              .withValues(alpha: 0.12 + 0.22 * glow),
                          blurRadius: 6 + 14 * glow,
                          spreadRadius: 0.5 + 1.5 * glow,
                        ),
                      ]
                    : const [],
              ),
              child: GestureDetector(
                onTapDown: (_) => _pressCtrl.forward(),
                onTapUp: (_) {
                  _pressCtrl.reverse();
                  _toggleExpand();
                },
                onTapCancel: () => _pressCtrl.reverse(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: _isExpanded
                        ? impactColor.withValues(alpha: 0.04)
                        : zc.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isUpcomingToday && !_isExpanded
                          ? impactColor.withValues(alpha: 0.35 + 0.25 * glow)
                          : _isExpanded
                              ? impactColor.withValues(alpha: 0.3)
                              : isPast
                                  ? zc.border
                                  : impactColor.withValues(alpha: 0.18),
                      width: isUpcomingToday ? 1.5 : _isExpanded ? 1.5 : 1,
                    ),
                  ),
                  child: child!,
                ),
              ),
            ),
          );
        },
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Collapsed content (always visible) ───────────────
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row
                    Row(
                      children: [
                        Text(
                          '${e.flag} ',
                          style: const TextStyle(fontSize: 16),
                        ),
                        Expanded(
                          child: Text(
                            e.event,
                            style: GoogleFonts.chakraPetch(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: zc.textPrimary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Impact badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: impactColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: impactColor.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            impactLabel,
                            style: GoogleFonts.chakraPetch(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: impactColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Expand chevron
                        AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: zc.textDim,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Data Row
                    Row(
                      children: [
                        if (sessionLabel.isNotEmpty)
                          _Tag(label: sessionLabel, color: zc.accent, zc: zc),
                        if (sessionLabel.isNotEmpty) const SizedBox(width: 6),
                        if (e.estimate != null)
                          _DataChip(
                            label: 'EST',
                            value: '${e.estimate}${e.unit}',
                            color: zc.accent,
                            zc: zc,
                          ),
                        if (e.previous != null) ...[
                          const SizedBox(width: 6),
                          _DataChip(
                            label: 'PRV',
                            value: '${e.previous}${e.unit}',
                            color: zc.textMuted,
                            zc: zc,
                          ),
                        ],
                        if (e.actual != null) ...[
                          const SizedBox(width: 6),
                          _DataChip(
                            label: 'ACT',
                            value: '${e.actual}${e.unit}',
                            color: zc.green,
                            zc: zc,
                          ),
                        ],
                        const Spacer(),
                        Text(
                          _timeStr(e.time),
                          style: GoogleFonts.chakraPetch(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isPast ? zc.textDim : zc.textMuted,
                          ),
                        ),
                      ],
                    ),

                    // Inline AI impact (small, always shown when available)
                    if (_aiLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(children: [
                          SizedBox(
                            width: 9, height: 9,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: zc.accent),
                          ),
                          const SizedBox(width: 6),
                          Text('AI analyzing...',
                              style: GoogleFonts.chakraPetch(
                                  fontSize: 10, color: zc.textDim)),
                        ]),
                      )
                    else if (_aiAnalysis != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 10, color: impactColor),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _aiAnalysis!,
                                style: GoogleFonts.chakraPetch(
                                  fontSize: 10,
                                  color: impactColor.withValues(alpha: 0.8),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (e.impact.toLowerCase() != 'high')
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Tap to expand & analyze',
                          style: GoogleFonts.chakraPetch(
                            fontSize: 9,
                            color: zc.textDim.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Expanded panel ────────────────────────────────────
              SizeTransition(
                sizeFactor: _expandAnim,
                axisAlignment: -1,
                child: FadeTransition(
                  opacity: _expandAnim,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: impactColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: impactColor.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Panel header
                        Row(
                          children: [
                            Icon(
                              isPast
                                  ? Icons.history_edu_rounded
                                  : Icons.remove_red_eye_rounded,
                              size: 11,
                              color: impactColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isPast ? 'WHAT HAPPENED' : 'WHAT TO WATCH',
                              style: GoogleFonts.chakraPetch(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: impactColor,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'AI Summary',
                              style: GoogleFonts.chakraPetch(
                                fontSize: 8,
                                color: impactColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Summary content
                        if (_summaryLoading)
                          Row(children: [
                            SizedBox(
                              width: 11, height: 11,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: impactColor),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isPast
                                  ? 'Analyzing market reaction...'
                                  : 'Preparing trade insights...',
                              style: GoogleFonts.chakraPetch(
                                fontSize: 11,
                                color: zc.textDim,
                              ),
                            ),
                          ])
                        else if (_summary != null)
                          Text(
                            _summary!,
                            style: GoogleFonts.chakraPetch(
                              fontSize: 11,
                              color: zc.textPrimary,
                              height: 1.55,
                            ),
                          )
                        else
                          Text(
                            'No summary available',
                            style: GoogleFonts.chakraPetch(
                              fontSize: 11,
                              color: zc.textDim,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  static bool _isUpcomingToday(EconomicEvent e) {
    if (e.isPast) return false;
    final now = DateTime.now();
    return e.time.year == now.year &&
        e.time.month == now.month &&
        e.time.day == now.day;
  }

  static String _timeStr(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _sessionLabel(DateTime t) {
    final utcH = t.toUtc().hour;
    if (utcH >= 8 && utcH < 17) return '🇬🇧 London';
    if (utcH >= 13 && utcH < 22) return '🇺🇸 New York';
    if (utcH >= 0 && utcH < 9) return '🇯🇵 Tokyo';
    return '';
  }

  static (Color, String) _impactStyle(String impact, ZenithColors zc) {
    switch (impact.toLowerCase()) {
      case 'high':
        return (const Color(0xFFEF4444), '● HIGH');
      case 'medium':
        return (const Color(0xFFFBBF24), '● MED');
      default:
        return (const Color(0xFF3B82F6), '● LOW');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGETS

// ─────────────────────────────────────────────────────────────────────────────
class _DataChip extends StatelessWidget {
  final String label, value;
  final Color color;
  final ZenithColors zc;
  const _DataChip({
    required this.label,
    required this.value,
    required this.color,
    required this.zc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: GoogleFonts.chakraPetch(
                fontSize: 8,
                color: zc.textDim,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.chakraPetch(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final ZenithColors zc;
  const _Tag({required this.label, required this.color, required this.zc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: GoogleFonts.chakraPetch(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING / ERROR STATES
// ─────────────────────────────────────────────────────────────────────────────
class _CalendarSkeleton extends StatelessWidget {
  final ZenithColors zc;
  const _CalendarSkeleton({required this.zc});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Fake grid placeholder
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          height: 260,
          decoration: BoxDecoration(
            color: zc.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: zc.border),
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: zc.accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarError extends StatelessWidget {
  final ZenithColors zc;
  final VoidCallback onRetry;
  const _CalendarError({required this.zc, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: zc.red),
          const SizedBox(height: 12),
          Text(
            'Failed to load calendar',
            style: GoogleFonts.chakraPetch(fontSize: 14, color: zc.textMuted),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: zc.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: zc.accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.chakraPetch(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: zc.accentSoft,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
