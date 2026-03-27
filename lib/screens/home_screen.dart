import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/rate_provider.dart';
import '../utils/parser.dart';

// ── COLOR CONSTANTS (Original Soft Dark) ──────────────────────────────────────
const Color kBg = Color(0xFF0A0B10);
const Color kSurface = Color(0xFF10121A);
const Color kAccent = Color(0xFF6C63FF);
const Color kTextPrimary = Color(0xFFE8EAF6);
final Color kTextMuted = const Color(0xFFE8EAF6).withValues(alpha: 0.45);
final Color kTextDim = const Color(0xFFE8EAF6).withValues(alpha: 0.25);
const Color kGreen = Color(0xFF4ADE80);

class ConverterScreen extends ConsumerStatefulWidget {
  const ConverterScreen({super.key});

  @override
  ConsumerState<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends ConsumerState<ConverterScreen>
    with WidgetsBindingObserver {
  final TextEditingController _inputController = TextEditingController(
    text: '',
  );
  Timer? _debounce;
  bool _wasKeyboardOpen = false;
  int _lastHapticValue = 0;

  double _parsedAmount = 1.0;
  String _fromCurrency = 'USD'; // USD or INR
  double _convertedValue = 0.0;

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
    final double keyboardHeight = View.of(context).viewInsets.bottom;
    if (keyboardHeight > 0) {
      _wasKeyboardOpen = true;
    } else if (keyboardHeight == 0 && _wasKeyboardOpen) {
      _wasKeyboardOpen = false;
      if (mounted && FocusScope.of(context).hasFocus) {
        FocusScope.of(context).unfocus();
      }
    }
  }

  void _onInputChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _evaluateInput(val),
    );
    setState(() {});
  }

  void _evaluateInput(String val) {
    // If empty, default to 1 for the 'result ui' requirement
    final actualVal = val.isEmpty ? '1' : val;
    final result = AmountParser.parseAmount(actualVal);
    final amount = result['amount'] as double;

    setState(() {
      _parsedAmount = amount;
    });

    final rateAsync = ref.read(rateProvider);
    if (rateAsync.hasValue) {
      setState(() {
        if (_fromCurrency == 'USD') {
          _convertedValue = _parsedAmount * rateAsync.value!.rate;
        } else {
          _convertedValue = _parsedAmount / rateAsync.value!.rate;
        }
      });
    }
  }

  void _swapCurrencies() {
    HapticFeedback.lightImpact();
    setState(() {
      _fromCurrency = _fromCurrency == 'USD' ? 'INR' : 'USD';
    });
    _evaluateInput(_inputController.text);
  }

  @override
  Widget build(BuildContext context) {
    final rateAsync = ref.watch(rateProvider);
    final double liveRate = rateAsync.value?.rate ?? 94.12;
    final String liveRateDisplay = liveRate.toStringAsFixed(2);

    ref.listen(rateProvider, (p, n) {
      if (n.hasValue) _evaluateInput(_inputController.text);
    });

    final String toCurrency = _fromCurrency == 'USD' ? 'INR' : 'USD';
    final String currencySymbol = _fromCurrency == 'USD' ? '₹' : '\$';
    
    // We determine the UNIT (Cr/L) based on the final value
    String unit = '';
    if (_convertedValue > 0 && _fromCurrency == 'USD') {
      final label = AmountParser.indianLabel(_convertedValue);
      if (label.contains(' ')) {
        unit = label.split(' ')[1];
        unit = unit[0].toUpperCase() + unit.substring(1);
      }
    }
    final String rateLabel = _fromCurrency == 'USD'
        ? '\$1 = ₹$liveRateDisplay'
        : '₹1 = \$${(1 / liveRate).toStringAsFixed(5)}';

    final double safeBottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (FocusScope.of(context).hasFocus) {
          FocusScope.of(context).unfocus();
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: kBg,
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

                      // ── TOP SECTION (ESTIMATED VALUE) ─────────────────────
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
                                  color: kTextDim,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    currencySymbol,
                                    style: GoogleFonts.chakraPetch(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w700,
                                      color: kTextPrimary.withValues(alpha: 0.9),
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TweenAnimationBuilder<double>(
                                    key: ValueKey(_convertedValue),
                                    tween: Tween<double>(
                                        begin: 0, end: _convertedValue),
                                    duration:
                                        const Duration(milliseconds: 500),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, child) {
                                      // Trigger haptic if the integer part changed
                                      final int currentVal = value.floor();
                                      if (currentVal != _lastHapticValue) {
                                        _lastHapticValue = currentVal;
                                        HapticFeedback.selectionClick();
                                      }

                                      String countMain = '0';
                                      if (value > 0) {
                                        if (_fromCurrency == 'USD') {
                                          final label =
                                              AmountParser.indianLabel(value);
                                          if (label.isNotEmpty) {
                                            countMain = label.split(' ')[0];
                                          } else {
                                            countMain =
                                                AmountParser.formatINR(value);
                                          }
                                        } else {
                                          countMain = value.toStringAsFixed(2);
                                        }
                                      }
                                      return Text(
                                        countMain,
                                        style: GoogleFonts.chakraPetch(
                                          fontSize: 76,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFC8C4FF),
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
                                        color: kTextPrimary.withValues(alpha: 0.6),
                                        letterSpacing: 0.0,
                                        height: 1.0,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                height: 44,
                                width: double.infinity,
                                child: CustomPaint(
                                  painter: _SparklinePainter(),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.06)),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      rateLabel,
                                      style: GoogleFonts.chakraPetch(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: kTextPrimary,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: kGreen.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: kGreen.withValues(alpha: 0.15)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.arrow_outward_rounded,
                                              color: kGreen, size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            '+0.31%',
                                            style: GoogleFonts.chakraPetch(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: kGreen,
                                            ),
                                          ),
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

                      // ── BOTTOM SECTION (CONVERTER) ───────────────────────
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
                                  color: kTextDim,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.fromLTRB(
                                  24, 0, 24, safeBottomPadding + 124),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F111A),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // ------------------ LEFT SIDE ------------------
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              _fromCurrency == 'USD' ? '\$' : '₹',
                                              style: GoogleFonts.chakraPetch(
                                                fontSize: 32,
                                                fontWeight: FontWeight.w700,
                                                color: kTextMuted,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: TextField(
                                                controller: _inputController,
                                                onChanged: _onInputChanged,
                                                cursorColor: kAccent,
                                                keyboardType: TextInputType.text,
                                                style: GoogleFonts.chakraPetch(
                                                  fontSize: 48,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                  letterSpacing: -1.5,
                                                  height: 1.1,
                                                ),
                                                decoration: const InputDecoration(
                                                  border: InputBorder.none,
                                                  enabledBorder: InputBorder.none,
                                                  focusedBorder: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.zero,
                                                  filled: false,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 16),

                                  // ------------------ RIGHT SIDE (Vertical Pill) ------------------
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF151824),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _fromCurrency,
                                          style: GoogleFonts.chakraPetch(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: kTextPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Swap Button
                                        GestureDetector(
                                          onTap: _swapCurrencies,
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.08),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.swap_vert_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 8),
                                        Text(
                                          toCurrency,
                                          style: GoogleFonts.chakraPetch(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: kTextMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Custom UI Components
// ─────────────────────────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
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

    final fillPath = Path.from(path);
    fillPath.lineTo(320 * sx, 40 * sy);
    fillPath.lineTo(0 * sx, 40 * sy);
    fillPath.close();

    final paintFill = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [kAccent.withValues(alpha: 0.35), kAccent.withValues(alpha: 0.0)],
        [0.0, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, paintFill);

    final paintLine = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(size.width, 0),
        [kAccent.withValues(alpha: 0.3), kAccent, const Color(0xFFA5B4FC)],
        [0.0, 0.7, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paintLine);

    final outerDot = Paint()..color = kAccent.withValues(alpha: 0.25);
    canvas.drawCircle(Offset(320 * sx, 5 * sy), 8, outerDot);
    final innerDot = Paint()..color = const Color(0xFFA5B4FC);
    canvas.drawCircle(Offset(320 * sx, 5 * sy), 3.5, innerDot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _offset = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
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