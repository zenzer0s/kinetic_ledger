import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/rate_provider.dart';
import '../services/rate_service.dart';
import '../theme/app_theme.dart';
import '../utils/parser.dart';

// ── CONVERTER SCREEN ──────────────────────────────────────────────────────────
class ConverterScreen extends ConsumerStatefulWidget {
  const ConverterScreen({super.key});
  @override
  ConsumerState<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends ConsumerState<ConverterScreen>
    with WidgetsBindingObserver {
  final TextEditingController _inputController =
      TextEditingController(text: '');
  Timer? _debounce;
  bool _wasKeyboardOpen = false;
  int _lastHapticValue = 0;

  double _parsedAmount = 1.0;
  String _fromCurrency = 'USD';
  String _toCurrency = 'INR';
  double _convertedValue = 0.0;

  String get _sparklineKey => '${_fromCurrency}_$_toCurrency';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => _evaluateInput(_inputController.text));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final double kbHeight = View.of(context).viewInsets.bottom;
    if (kbHeight > 0) {
      _wasKeyboardOpen = true;
    } else if (kbHeight == 0 && _wasKeyboardOpen) {
      _wasKeyboardOpen = false;
      if (mounted && FocusScope.of(context).hasFocus) {
        FocusScope.of(context).unfocus();
      }
    }
  }

  void _onInputChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(
        const Duration(milliseconds: 300), () => _evaluateInput(val));
    setState(() {});
  }

  void _evaluateInput(String val) {
    final actualVal = val.isEmpty ? '1' : val;
    final result = AmountParser.parseAmount(actualVal);
    final amount = result['amount'] as double;
    setState(() => _parsedAmount = amount);

    final rateAsync = ref.read(rateProvider);
    if (rateAsync.hasValue) {
      setState(() {
        _convertedValue =
            _parsedAmount * rateAsync.value!.crossRate(_fromCurrency, _toCurrency);
      });
    }
  }

  void _swapCurrencies() {
    HapticFeedback.lightImpact();
    setState(() {
      final tmp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = tmp;
    });
    _evaluateInput(_inputController.text);
  }

  void _selectFromCurrency(String code) {
    if (code == _toCurrency) { _swapCurrencies(); return; }
    HapticFeedback.selectionClick();
    setState(() => _fromCurrency = code);
    _evaluateInput(_inputController.text);
  }

  void _selectToCurrency(String code) {
    if (code == _fromCurrency) { _swapCurrencies(); return; }
    HapticFeedback.selectionClick();
    setState(() => _toCurrency = code);
    _evaluateInput(_inputController.text);
  }

  String _formatResult(double value, String toCurrency) {
    if (toCurrency == 'INR') {
      final label = AmountParser.indianLabel(value);
      if (label.isNotEmpty) return label.split(' ')[0];
      return AmountParser.formatINR(value);
    } else if (toCurrency == 'JPY') {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _unitLabel(double value, String toCurrency) {
    if (toCurrency == 'INR') {
      final label = AmountParser.indianLabel(value);
      if (label.contains(' ')) {
        final u = label.split(' ')[1];
        return u[0].toUpperCase() + u.substring(1);
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final rateAsync = ref.watch(rateProvider);
    final sparkAsync = ref.watch(sparklineProvider(_sparklineKey));

    ref.listen(rateProvider, (p, n) {
      if (n.hasValue) _evaluateInput(_inputController.text);
    });

    final fromMeta = metaFor(_fromCurrency);
    final toMeta = metaFor(_toCurrency);
    final String unit = _unitLabel(_convertedValue, _toCurrency);

    double liveRate = 1.0;
    String rateLabelStr = '...';
    double changePercent = 0.0;
    bool changePositive = true;

    if (rateAsync.hasValue) {
      final r = rateAsync.value!;
      liveRate = r.crossRate(_fromCurrency, _toCurrency);
      rateLabelStr =
          '1 ${fromMeta.symbol} = ${toMeta.symbol}${liveRate.toStringAsFixed(liveRate >= 100 ? 2 : liveRate >= 1 ? 4 : 6)}';
      changePercent = r.changePercent;
      if (sparkAsync.hasValue) {
        final pts = sparkAsync.value!.points;
        if (pts.length >= 2) {
          final first = pts.first;
          final last = pts.last;
          if (first != 0) changePercent = ((last - first) / first) * 100;
        }
      }
      changePositive = changePercent >= 0;
    }

    final double safeBottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (FocusScope.of(context).hasFocus) FocusScope.of(context).unfocus();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: zc.bg,
          body: SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 48),

                      // ── TOP RESULT ──────────────────────────────────────
                      _FadeInUp(
                        delay: 150,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ESTIMATED VALUE',
                                style: GoogleFonts.chakraPetch(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                  color: zc.textDim,
                                ),
                              ),
                              const SizedBox(height: 14),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    toMeta.symbol,
                                    style: GoogleFonts.chakraPetch(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w700,
                                      color: zc.textPrimary.withValues(alpha: 0.9),
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TweenAnimationBuilder<double>(
                                    key: ValueKey(_convertedValue),
                                    tween: Tween<double>(
                                        begin: 0, end: _convertedValue),
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, child) {
                                      final int cur = value.floor();
                                      if (cur != _lastHapticValue) {
                                        _lastHapticValue = cur;
                                        HapticFeedback.selectionClick();
                                      }
                                      return Text(
                                        _formatResult(value, _toCurrency),
                                        style: GoogleFonts.chakraPetch(
                                          fontSize: 76,
                                          fontWeight: FontWeight.w800,
                                          color: zc.accentSoft,
                                          letterSpacing: -1.0,
                                          height: 1.0,
                                        ),
                                      );
                                    },
                                  ),
                                  if (unit.isNotEmpty) ...[
                                    const SizedBox(width: 10),
                                    Text(
                                      unit,
                                      style: GoogleFonts.chakraPetch(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w600,
                                        color: zc.textPrimary.withValues(alpha: 0.6),
                                        height: 1.0,
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              const SizedBox(height: 32),

                              // ── SPARKLINE ─────────────────────────────────
                              SizedBox(
                                height: 44,
                                width: double.infinity,
                                child: sparkAsync.when(
                                  data: (spark) => CustomPaint(
                                    painter: _LiveSparklinePainter(spark, zc.accent),
                                  ),
                                  loading: () => CustomPaint(
                                    painter: _SparklinePlaceholder(zc.accent),
                                  ),
                                  error: (_, _) => CustomPaint(
                                    painter: _SparklinePlaceholder(zc.accent),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // ── RATE CARD ────────────────────────────────
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 16),
                                decoration: BoxDecoration(
                                  color: zc.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: zc.border),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      rateLabelStr,
                                      style: GoogleFonts.chakraPetch(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: zc.textPrimary,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    rateAsync.isLoading
                                        ? _LoadingBadge(zc: zc)
                                        : _ChangeBadge(
                                            percent: changePercent,
                                            positive: changePositive,
                                            zc: zc,
                                          ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── CONVERTER CARD ────────────────────────────────────
                      _FadeInUp(
                        delay: 250,
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            Align(
                              alignment: Alignment.center,
                              child: Text(
                                'AMOUNT TO CONVERT',
                                style: GoogleFonts.chakraPetch(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                  color: zc.textDim,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: zc.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: zc.border, width: 1),
                              ),
                              child: Column(
                                children: [
                                  // Input row
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              fromMeta.symbol,
                                              style: GoogleFonts.chakraPetch(
                                                fontSize: 32,
                                                fontWeight: FontWeight.w700,
                                                color: zc.textMuted,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: TextField(
                                                controller: _inputController,
                                                onChanged: _onInputChanged,
                                                cursorColor: zc.accent,
                                                keyboardType: TextInputType.text,
                                                style: GoogleFonts.chakraPetch(
                                                  fontSize: 48,
                                                  fontWeight: FontWeight.w800,
                                                  color: zc.textPrimary,
                                                  letterSpacing: -1.5,
                                                  height: 1.1,
                                                ),
                                                decoration:
                                                    const InputDecoration(
                                                  border: InputBorder.none,
                                                  enabledBorder:
                                                      InputBorder.none,
                                                  focusedBorder:
                                                      InputBorder.none,
                                                  isDense: true,
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  filled: false,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Vertical currency pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: zc.surfaceAlt,
                                          borderRadius:
                                              BorderRadius.circular(100),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _fromCurrency,
                                              style: GoogleFonts.chakraPetch(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: zc.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            GestureDetector(
                                              onTap: _swapCurrencies,
                                              child: Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: zc.border,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    Icons.swap_vert_rounded,
                                                    color: zc.textPrimary,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              _toCurrency,
                                              style: GoogleFonts.chakraPetch(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: zc.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 20),
                                  Container(height: 1, color: zc.border),
                                  const SizedBox(height: 16),

                                  // ── CURRENCY SELECTORS ──────────────────
                                  _CurrencySelectorRow(
                                    label: 'FROM',
                                    selected: _fromCurrency,
                                    onSelect: _selectFromCurrency,
                                    disabledCode: _toCurrency,
                                    zc: zc,
                                  ),
                                  const SizedBox(height: 10),
                                  _CurrencySelectorRow(
                                    label: 'TO',
                                    selected: _toCurrency,
                                    onSelect: _selectToCurrency,
                                    disabledCode: _fromCurrency,
                                    zc: zc,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: safeBottomPadding + 124),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Currency Selector Row ─────────────────────────────────────────────────────
class _CurrencySelectorRow extends StatelessWidget {
  final String label;
  final String selected;
  final String disabledCode;
  final ValueChanged<String> onSelect;
  final ZenithColors zc;

  const _CurrencySelectorRow({
    required this.label,
    required this.selected,
    required this.onSelect,
    required this.disabledCode,
    required this.zc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.chakraPetch(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: zc.textDim,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: kTopCurrencies.map((meta) {
                final isSelected = meta.code == selected;
                final isDisabled = meta.code == disabledCode;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: isDisabled ? null : () => onSelect(meta.code),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? zc.accent.withValues(alpha: 0.15)
                            : isDisabled
                                ? Colors.transparent
                                : zc.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? zc.accent.withValues(alpha: 0.6)
                              : isDisabled
                                  ? zc.border
                                  : zc.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(meta.flag,
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 5),
                          Text(
                            meta.code,
                            style: GoogleFonts.chakraPetch(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? zc.accentSoft
                                  : isDisabled
                                      ? zc.textDim
                                      : zc.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Change Badge ──────────────────────────────────────────────────────────────
class _ChangeBadge extends StatelessWidget {
  final double percent;
  final bool positive;
  final ZenithColors zc;
  const _ChangeBadge(
      {required this.percent, required this.positive, required this.zc});

  @override
  Widget build(BuildContext context) {
    final color = positive ? zc.green : zc.red;
    final icon = positive
        ? Icons.arrow_outward_rounded
        : Icons.arrow_downward_rounded;
    final sign = positive ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            '$sign${percent.toStringAsFixed(2)}%',
            style: GoogleFonts.chakraPetch(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBadge extends StatelessWidget {
  final ZenithColors zc;
  const _LoadingBadge({required this.zc});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: zc.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: zc.border),
      ),
      child: SizedBox(
        width: 40,
        height: 10,
        child: LinearProgressIndicator(
          backgroundColor: zc.border,
          valueColor: AlwaysStoppedAnimation<Color>(
              zc.accent.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}

// ── Live Sparkline ────────────────────────────────────────────────────────────
class _LiveSparklinePainter extends CustomPainter {
  final SparklineResult spark;
  final Color accent;
  _LiveSparklinePainter(this.spark, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final pts = spark.points;
    if (pts.isEmpty) return;
    final range = spark.maxVal - spark.minVal;
    final safeRange = range == 0 ? 1.0 : range;
    double normY(double val) =>
        size.height -
        ((val - spark.minVal) / safeRange) * size.height * 0.85 -
        size.height * 0.075;

    final path = Path();
    final step = size.width / (pts.length - 1).clamp(1, 999);
    path.moveTo(0, normY(pts[0]));
    for (int i = 1; i < pts.length; i++) {
      final x = i * step;
      final y = normY(pts[i]);
      final px = (i - 1) * step;
      final py = normY(pts[i - 1]);
      path.cubicTo(px + step * 0.5, py, x - step * 0.5, y, x, y);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [accent.withValues(alpha: 0.35), accent.withValues(alpha: 0.0)],
        )
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, 0),
          [
            accent.withValues(alpha: 0.3),
            accent,
            const Color(0xFFA5B4FC),
          ],
          [0.0, 0.7, 1.0],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
    final endX = (pts.length - 1) * step;
    final endY = normY(pts.last);
    canvas.drawCircle(
        Offset(endX, endY), 8, Paint()..color = accent.withValues(alpha: 0.25));
    canvas.drawCircle(
        Offset(endX, endY), 3.5, Paint()..color = const Color(0xFFA5B4FC));
  }

  @override
  bool shouldRepaint(covariant _LiveSparklinePainter old) =>
      old.spark != spark || old.accent != accent;
}

class _SparklinePlaceholder extends CustomPainter {
  final Color accent;
  const _SparklinePlaceholder(this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    double sx = size.width / 320.0;
    double sy = size.height / 40.0;
    path.moveTo(0 * sx, 30 * sy);
    path.cubicTo(20 * sx, 28 * sy, 35 * sx, 32 * sy, 55 * sx, 25 * sy);
    path.cubicTo(75 * sx, 18 * sy, 90 * sx, 22 * sy, 110 * sx, 18 * sy);
    path.cubicTo(130 * sx, 14 * sy, 145 * sx, 20 * sy, 165 * sx, 16 * sy);
    path.cubicTo(185 * sx, 12 * sy, 200 * sx, 18 * sy, 220 * sx, 14 * sy);
    path.cubicTo(240 * sx, 10 * sy, 255 * sx, 15 * sy, 275 * sx, 10 * sy);
    path.cubicTo(290 * sx, 6 * sy, 305 * sx, 8 * sy, 320 * sx, 5 * sy);
    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Fade In Up ────────────────────────────────────────────────────────────────
class _FadeInUp extends StatefulWidget {
  final Widget child;
  final int delay;
  const _FadeInUp({required this.child, required this.delay});
  @override
  State<_FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<_FadeInUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _opacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _offset = Tween<Offset>(
            begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.delay), () {
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
        child: SlideTransition(position: _offset, child: widget.child));
  }
}