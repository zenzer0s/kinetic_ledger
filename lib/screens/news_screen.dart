import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/news_provider.dart';
import '../services/news_service.dart';
import '../services/cerebras_service.dart';
import '../services/sentiment.dart';
import '../theme/app_theme.dart';
import 'calendar_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MARKET PULSE SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});
  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen>
    with TickerProviderStateMixin {
  int _selectedTab = 0; // 0 = News, 1 = Calendar
  late AnimationController _headerFade;

  @override
  void initState() {
    super.initState();
    _headerFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _headerFade.forward();
    });
  }

  @override
  void dispose() {
    _headerFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;

    return Scaffold(
      backgroundColor: zc.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),

            // ── HEADER ───────────────────────────────────────────────────
            FadeTransition(
              opacity: _headerFade,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MARKET PULSE',
                          style: GoogleFonts.chakraPetch(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: zc.textDim,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Live News & Events',
                          style: GoogleFonts.chakraPetch(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: zc.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Refresh button
                    _PulsingRefreshButton(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        ref.invalidate(newsProvider);
                        ref.invalidate(calendarProvider);
                      },
                      zc: zc,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── SEGMENTED CONTROL ────────────────────────────────────────
            FadeTransition(
              opacity: _headerFade,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _SegmentedControl(
                  selected: _selectedTab,
                  labels: const ['📰  NEWS', '📅  CALENDAR'],
                  onChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTab = i);
                  },
                  zc: zc,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── CONTENT ──────────────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) {
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 0.03),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    ),
                  );
                },
                child: _selectedTab == 0
                    ? _NewsTab(key: const ValueKey('news'), zc: zc)
                    : EconomicCalendarWidget(
                        key: const ValueKey('cal'),
                        zc: zc,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEWS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _NewsTab extends ConsumerWidget {
  final ZenithColors zc;
  const _NewsTab({super.key, required this.zc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(newsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(newsProvider),
      color: zc.accent,
      backgroundColor: zc.surface,
      child: async.when(
        loading: () => _ShimmerList(zc: zc, isNews: true),
        error: (e, _) =>
            _ErrorState(zc: zc, onRetry: () => ref.invalidate(newsProvider)),
        data: (articles) {
          if (articles.isEmpty) {
            return _EmptyState(zc: zc, label: 'No news available');
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              24,
              0,
              24,
              MediaQuery.of(context).viewPadding.bottom + 120,
            ),
            physics: const BouncingScrollPhysics(),
            itemCount: articles.length,
            itemBuilder: (ctx, i) => _StaggeredItem(
              index: i,
              child: _NewsCard(enriched: articles[i], articleIndex: i, zc: zc),
            ),
          );
        },
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// NEWS CARD

// ─────────────────────────────────────────────────────────────────────────────
class _NewsCard extends StatefulWidget {
  final EnrichedArticle enriched;
  final int articleIndex;
  final ZenithColors zc;
  const _NewsCard({
    required this.enriched,
    required this.articleIndex,
    required this.zc,
  });

  @override
  State<_NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<_NewsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scale;

  // On-demand AI state (for older articles index >= 10)
  LlmSentiment? _onDemandSentiment;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _open() async {
    final uri = Uri.tryParse(widget.enriched.article.url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _analyzeOnDemand() async {
    if (_aiLoading || _onDemandSentiment != null) return;
    HapticFeedback.mediumImpact();
    setState(() => _aiLoading = true);
    final result = await CerebrasSentimentService().classifySingle(
      widget.enriched.article.headline,
    );
    if (mounted)
      setState(() {
        _onDemandSentiment = result;
        _aiLoading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.enriched.article;
    final zc = widget.zc;
    final isOld = widget.articleIndex >= 10;

    // Top-10: always have batch AI result. Old: use on-demand if fetched.
    final activeSentiment = (!isOld || _onDemandSentiment != null)
        ? (isOld ? _onDemandSentiment!.sentiment : widget.enriched.sentiment)
        : null; // null = not yet classified (old article)

    final activeReason = (!isOld)
        ? widget.enriched.reason
        : (_onDemandSentiment?.reason ?? '');

    final hasAiResult = activeSentiment != null;
    final (sentColor, sentLabel, sentIcon) = hasAiResult
        ? _sentimentStyle(activeSentiment, zc)
        : (zc.textDim, '', Icons.trending_flat_rounded);
    final sourceColor = _sourceColor(a.source, zc);

    return ScaleTransition(
      scale: _scale,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: zc.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: zc.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tappable upper area (opens URL) ─────────────────────────
            GestureDetector(
              onTapDown: (_) => _pressCtrl.forward(),
              onTapUp: (_) {
                _pressCtrl.reverse();
                HapticFeedback.lightImpact();
                _open();
              },
              onTapCancel: () => _pressCtrl.reverse(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top Row ─────────────────────────────────────────
                    Row(
                      children: [
                        // Source pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: sourceColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: sourceColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            a.source.length > 14
                                ? a.source.substring(0, 14)
                                : a.source,
                            style: GoogleFonts.chakraPetch(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: sourceColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Sentiment badge — empty for old articles not yet analyzed
                        if (hasAiResult)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: sentColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: sentColor.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(sentIcon, size: 9, color: sentColor),
                                const SizedBox(width: 4),
                                Text(
                                  sentLabel,
                                  style: GoogleFonts.chakraPetch(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: sentColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          a.timeAgo,
                          style: GoogleFonts.chakraPetch(
                            fontSize: 10,
                            color: zc.textDim,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ── Headline ──────────────────────────────────────────
                    Text(
                      a.headline,
                      style: GoogleFonts.chakraPetch(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: zc.textPrimary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (a.summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        a.summary,
                        style: GoogleFonts.chakraPetch(
                          fontSize: 12,
                          color: zc.textMuted,
                          height: 1.45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // ── AI Reason box (shown when we have a result) ──────
                    if (hasAiResult && activeReason.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: sentColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sentColor.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 10,
                              color: sentColor,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                activeReason,
                                style: GoogleFonts.chakraPetch(
                                  fontSize: 10,
                                  color: sentColor.withValues(alpha: 0.85),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Footer row ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _open,
                    child: Row(
                      children: [
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 11,
                          color: zc.textDim,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Read full article',
                          style: GoogleFonts.chakraPetch(
                            fontSize: 10,
                            color: zc.textDim,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // ⚡ AI Analyze button — ONLY for old articles not yet done
                  if (isOld && _onDemandSentiment == null)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _analyzeOnDemand,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: zc.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: zc.accent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_aiLoading)
                              SizedBox(
                                width: 9,
                                height: 9,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: zc.accent,
                                ),
                              )
                            else
                              Icon(
                                Icons.bolt_rounded,
                                size: 11,
                                color: zc.accent,
                              ),
                            const SizedBox(width: 4),
                            Text(
                              _aiLoading ? 'Analyzing...' : '',
                              style: GoogleFonts.chakraPetch(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: zc.accent,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static (Color, String, IconData) _sentimentStyle(
    Sentiment s,
    ZenithColors zc,
  ) {
    switch (s) {
      case Sentiment.bullish:
        return (zc.green, 'BULLISH', Icons.trending_up_rounded);
      case Sentiment.bearish:
        return (zc.red, 'BEARISH', Icons.trending_down_rounded);
      case Sentiment.neutral:
        return (zc.textMuted, 'NEUTRAL', Icons.trending_flat_rounded);
    }
  }

  static Color _sourceColor(String source, ZenithColors zc) {
    final s = source.toLowerCase();
    if (s.contains('reuters')) return const Color(0xFFFF8000);
    if (s.contains('bloomberg')) return const Color(0xFF2563EB);
    if (s.contains('cnbc')) return const Color(0xFF7C3AED);
    if (s.contains('wsj') || s.contains('wall street')) {
      return const Color(0xFF64748B);
    }
    if (s.contains('ft') || s.contains('financial times')) {
      return const Color(0xFFEA580C);
    }
    if (s.contains('yahoo')) return const Color(0xFF7C00FF);
    if (s.contains('seeking')) return const Color(0xFF059669);
    return zc.accent;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CALENDAR CARD
// ─────────────────────────────────────────────────────────────────────────────
class _CalendarCard extends StatefulWidget {
  final EconomicEvent event;
  final ZenithColors zc;
  const _CalendarCard({required this.event, required this.zc});

  @override
  State<_CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<_CalendarCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final zc = widget.zc;
    final (impactColor, impactLabel) = _impactStyle(e.impact, zc);
    final isPast = e.isPast;

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) {
          _pressCtrl.reverse();
          HapticFeedback.selectionClick();
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: Opacity(
          opacity: isPast ? 0.45 : 1.0,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: zc.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isPast ? zc.border : impactColor.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                // Left: impact indicator bar
                Container(
                  width: 3,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isPast
                        ? zc.border
                        : impactColor.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),

                // Middle: event info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${e.flag}  ',
                            style: const TextStyle(fontSize: 14),
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
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (e.estimate != null)
                            _DataPill(
                              label: 'Est',
                              value:
                                  '${e.estimate}${e.unit.isNotEmpty ? e.unit : ''}',
                              color: zc.accent,
                              zc: zc,
                            ),
                          if (e.previous != null) ...[
                            const SizedBox(width: 6),
                            _DataPill(
                              label: 'Prev',
                              value:
                                  '${e.previous}${e.unit.isNotEmpty ? e.unit : ''}',
                              color: zc.textMuted,
                              zc: zc,
                            ),
                          ],
                          if (e.actual != null) ...[
                            const SizedBox(width: 6),
                            _DataPill(
                              label: 'Act',
                              value:
                                  '${e.actual}${e.unit.isNotEmpty ? e.unit : ''}',
                              color: zc.green,
                              zc: zc,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Right: impact + time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: impactColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
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
                    const SizedBox(height: 6),
                    Text(
                      e.timeLabel,
                      style: GoogleFonts.chakraPetch(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isPast ? zc.textDim : zc.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static (Color, String) _impactStyle(String impact, ZenithColors zc) {
    switch (impact.toLowerCase()) {
      case 'high':
        return (zc.red, 'HIGH');
      case 'medium':
        return (const Color(0xFFFBBF24), 'MED');
      default:
        return (zc.textMuted, 'LOW');
    }
  }
}

class _DataPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final ZenithColors zc;
  const _DataPill({
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
                fontSize: 9,
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

// ─────────────────────────────────────────────────────────────────────────────
// SEGMENTED CONTROL (iOS-style sliding pill)
// ─────────────────────────────────────────────────────────────────────────────
class _SegmentedControl extends StatelessWidget {
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  final ZenithColors zc;

  const _SegmentedControl({
    required this.selected,
    required this.labels,
    required this.onChanged,
    required this.zc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: zc.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: zc.border),
      ),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final pillW = (constraints.maxWidth - 6) / labels.length;
          return Stack(
            children: [
              // Sliding pill
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: selected * pillW,
                top: 0,
                bottom: 0,
                width: pillW,
                child: Container(
                  decoration: BoxDecoration(
                    color: zc.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: zc.accent.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              // Labels
              Row(
                children: List.generate(labels.length, (i) {
                  final active = selected == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(i),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: GoogleFonts.chakraPetch(
                            fontSize: 11,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: active ? zc.accentSoft : zc.textMuted,
                            letterSpacing: 0.3,
                          ),
                          child: Text(labels[i]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PULSING REFRESH BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _PulsingRefreshButton extends StatefulWidget {
  final VoidCallback onTap;
  final ZenithColors zc;
  const _PulsingRefreshButton({required this.onTap, required this.zc});

  @override
  State<_PulsingRefreshButton> createState() => _PulsingRefreshButtonState();
}

class _PulsingRefreshButtonState extends State<_PulsingRefreshButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rot;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _rot = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _tap() {
    _ctrl.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final zc = widget.zc;
    return GestureDetector(
      onTap: _tap,
      child: AnimatedBuilder(
        animation: _rot,
        builder: (_, child) =>
            Transform.rotate(angle: _rot.value * 2 * math.pi, child: child),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: zc.surfaceAlt,
            shape: BoxShape.circle,
            border: Border.all(color: zc.border),
          ),
          child: Icon(Icons.refresh_rounded, color: zc.textMuted, size: 18),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGGERED ITEM WRAPPER
// ─────────────────────────────────────────────────────────────────────────────
class _StaggeredItem extends StatefulWidget {
  final Widget child;
  final int index;
  const _StaggeredItem({required this.child, required this.index});

  @override
  State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    // Stagger: max 500ms total delay, 40ms per item
    final delay = math.min(widget.index * 40, 500);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER LOADING
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerList extends StatelessWidget {
  final ZenithColors zc;
  final bool isNews;
  const _ShimmerList({required this.zc, required this.isNews});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder: (_, i) =>
          _ShimmerCard(zc: zc, height: isNews ? 118.0 : 88.0, delay: i * 80),
    );
  }
}

class _ShimmerCard extends StatefulWidget {
  final ZenithColors zc;
  final double height;
  final int delay;
  const _ShimmerCard({
    required this.zc,
    required this.height,
    required this.delay,
  });

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _anim = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zc = widget.zc;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) {
        return Container(
          height: widget.height,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value, 0),
              colors: [zc.surface, zc.surfaceAlt, zc.surface],
            ),
            border: Border.all(color: zc.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ShimmerBox(w: 60, h: 18, r: 6, zc: zc),
                    const Spacer(),
                    _ShimmerBox(w: 55, h: 18, r: 6, zc: zc),
                  ],
                ),
                const SizedBox(height: 12),
                _ShimmerBox(w: double.infinity, h: 13, r: 4, zc: zc),
                const SizedBox(height: 6),
                _ShimmerBox(w: 200, h: 13, r: 4, zc: zc),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double w, h, r;
  final ZenithColors zc;
  const _ShimmerBox({
    required this.w,
    required this.h,
    required this.r,
    required this.zc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: zc.surfaceAlt,
        borderRadius: BorderRadius.circular(r),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY / ERROR STATES
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final ZenithColors zc;
  final String label;
  const _EmptyState({required this.zc, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.newspaper_outlined, size: 48, color: zc.textDim),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.chakraPetch(fontSize: 14, color: zc.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final ZenithColors zc;
  final VoidCallback onRetry;
  const _ErrorState({required this.zc, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: zc.red),
          const SizedBox(height: 12),
          Text(
            'Failed to load',
            style: GoogleFonts.chakraPetch(fontSize: 14, color: zc.textMuted),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
