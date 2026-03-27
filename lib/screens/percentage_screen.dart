import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/rate_provider.dart';
import '../utils/parser.dart';

// ── COLOR CONSTANTS (Matching Home Screen) ──────────────────────────────────────
const Color kBg = Color(0xFF0A0B10);
const Color kSurface = Color(0xFF10121A);
const Color kAccent = Color(0xFF6C63FF);
const Color kTextPrimary = Color(0xFFE8EAF6);
final Color kTextMuted = const Color(0xFFE8EAF6).withValues(alpha: 0.45);
final Color kTextDim = const Color(0xFFE8EAF6).withValues(alpha: 0.25);
const Color kGreen = Color(0xFF4ADE80);

class PercentageScreen extends ConsumerStatefulWidget {
  const PercentageScreen({super.key});

  @override
  ConsumerState<PercentageScreen> createState() => _PercentageScreenState();
}

class _PercentageScreenState extends ConsumerState<PercentageScreen>
    with WidgetsBindingObserver {
  final TextEditingController _amountController = TextEditingController(
    text: '',
  );
  final TextEditingController _percentController = TextEditingController(
    text: '',
  );

  Timer? _debounce;
  bool _wasKeyboardOpen = false;
  int _lastHapticValue = 0;

  double _parsedAmount = 0.0;
  double _parsedPercent = 0.0;
  double _calculatedAmount = 0.0;
  double _convertedValue = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => _recalculate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _amountController.dispose();
    _percentController.dispose();
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
      () => _recalculate(),
    );
    setState(() {});
  }

  void _recalculate() {
    final amountResult = AmountParser.parseAmount(_amountController.text);
    final amount = amountResult['amount'] as double;
    final percent = double.tryParse(_percentController.text) ?? 0.0;

    final calcValue = (amount * percent) / 100.0;

    final rateAsync = ref.read(rateProvider);
    double converted = 0.0;
    if (rateAsync.hasValue) {
      converted = calcValue * rateAsync.value!.rate;
    }

    setState(() {
      _parsedAmount = amount;
      _parsedPercent = percent;
      _calculatedAmount = calcValue;
      _convertedValue = converted;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(rateProvider);

    ref.listen(rateProvider, (p, n) {
      if (n.hasValue) _recalculate();
    });

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

                      // ── TOP SECTION (CALCULATED VALUE) ─────────────────────
                      _FadeInUp(
                        delay: 150,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CALCULATED VALUE',
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
                                    '\$',
                                    style: GoogleFonts.chakraPetch(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w700,
                                      color: kTextPrimary.withValues(alpha: 0.9),
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TweenAnimationBuilder<double>(
                                    key: ValueKey(_calculatedAmount),
                                    tween: Tween<double>(
                                        begin: 0, end: _calculatedAmount),
                                    duration:
                                        const Duration(milliseconds: 500),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, child) {
                                      // Sync Haptics
                                      final int currentVal = value.floor();
                                      if (currentVal != _lastHapticValue) {
                                        _lastHapticValue = currentVal;
                                        HapticFeedback.selectionClick();
                                      }

                                      return Text(
                                        AmountParser.formatUSD(value),
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
                                ],
                              ),
                              const SizedBox(height: 20),
                              
                              // Equivalent in INR (Smaller display)
                              Text(
                                'ESTIMATED ₹${AmountParser.formatINR(_convertedValue)}',
                                style: GoogleFonts.chakraPetch(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: kAccent,
                                  letterSpacing: 0.0,
                                ),
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
                              
                              // Summary Pill
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
                                  children: [
                                    Text(
                                      '${_parsedPercent.toStringAsFixed(1)}%',
                                      style: GoogleFonts.chakraPetch(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: kAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'OF \$${AmountParser.formatUSD(_parsedAmount)}',
                                      style: GoogleFonts.chakraPetch(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: kTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 48),

                      // ── BOTTOM INPUT SECTION ────────────────────────────
                      _FadeInUp(
                        delay: 250,
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.center,
                              child: Text(
                                'PERCENTAGE CALCULATION',
                                style: GoogleFonts.chakraPetch(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                  color: kTextDim,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Amount Card
                            _InputCard(
                              label: 'PRINCIPAL AMOUNT',
                              controller: _amountController,
                              prefix: '\$',
                              suffix: 'USD',
                              onChanged: _onInputChanged,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Percent Card
                            _InputCard(
                              label: 'PERCENTAGE RATE',
                              controller: _percentController,
                              prefix: '',
                              suffix: '%',
                              onChanged: _onInputChanged,
                            ),
                            
                            SizedBox(height: safeBottomPadding + 140),
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
// Components
// ─────────────────────────────────────────────────────────────────────────────

class _InputCard extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String prefix;
  final String suffix;
  final Function(String) onChanged;

  const _InputCard({
    required this.label,
    required this.controller,
    required this.prefix,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.chakraPetch(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: const Color(0xFFE8EAF6).withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (prefix.isNotEmpty)
                Text(
                  prefix,
                  style: GoogleFonts.chakraPetch(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE8EAF6).withValues(alpha: 0.45),
                  ),
                ),
              if (prefix.isNotEmpty) const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  cursorColor: const Color(0xFF6C63FF),
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
              const SizedBox(width: 12),
              Text(
                suffix,
                style: GoogleFonts.chakraPetch(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6C63FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
        [const Color(0xFF6C63FF).withValues(alpha: 0.35), const Color(0xFF6C63FF).withValues(alpha: 0.0)],
        [0.0, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, paintFill);

    final paintLine = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(size.width, 0),
        [const Color(0xFF6C63FF).withValues(alpha: 0.3), const Color(0xFF6C63FF), const Color(0xFFA5B4FC)],
        [0.0, 0.7, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paintLine);

    final outerDot = Paint()..color = const Color(0xFF6C63FF).withValues(alpha: 0.25);
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
