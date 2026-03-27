import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ResultCard extends StatefulWidget {
  final double amountValue;
  final String formattedPrefix; // e.g. "₹"
  final String formattedSuffix; // e.g. "Lakh"
  final String subtext; // e.g. "Eight Lakh Thirty-Four Thousand Two Hundred Rupees"
  
  // Custom styling
  final Color accentColor;
  final AnimationController animationController;

  const ResultCard({
    super.key,
    required this.amountValue,
    required this.formattedPrefix,
    required this.formattedSuffix,
    required this.subtext,
    required this.accentColor,
    required this.animationController,
  });

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard> {
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  double _oldAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: widget.animationController, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: widget.animationController, curve: Curves.easeOut),
    );

    // Default internal controller for count up, in case parent doesn't provide
  }

  @override
  void didUpdateWidget(ResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amountValue != widget.amountValue) {
      _oldAmount = oldWidget.amountValue;
      // Restart count up internally, or rely on parent calling forward on the main animationController?
      // Since prompt says ResultCard takes onReveal trigger, I'll assume the primary counter updates the text externally
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161A22), // surface-container
            borderRadius: BorderRadius.circular(44), // xl radius
            border: Border.all(color: const Color(0xFF454850).withValues(alpha: 0.1)),
            boxShadow: [
              // Ambient glow
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.05),
                blurRadius: 40,
                offset: const Offset(0, 20),
              )
            ]
          ),
          child: Stack(
            children: [
              // Radial glow in top right
              Positioned(
                top: -80,
                right: -80,
                child: Container(
                  width: 256,
                  height: 256,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.accentColor.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                      radius: 0.8,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'CONVERTED VALUE (INR)',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                            color: const Color(0xFFA9ABB4), // on-surface-variant
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.trending_up, color: widget.accentColor, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: widget.accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: widget.animationController,
                      builder: (context, child) {
                        // Count up interpolator using the main animation controller
                        final currentVal = Tween<double>(begin: _oldAmount, end: widget.amountValue).evaluate(
                          CurvedAnimation(parent: widget.animationController, curve: Curves.easeOut)
                        );
                        
                        return RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${widget.formattedPrefix}${currentVal.toStringAsFixed(2)} ',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1.5,
                                  color: const Color(0xFFF2F3FD),
                                ),
                              ),
                              TextSpan(
                                text: widget.formattedSuffix,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1.5,
                                  color: const Color(0xFF4865FB), // primary-dim
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.subtext,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: const Color(0xFF73757E), // outline
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Ticker Graph Placeholder (Stitch HTML style)
                    Container(
                      height: 64,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10131B).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildBar(0.4),
                          _buildBar(0.6),
                          _buildBar(0.45),
                          _buildBar(0.7),
                          _buildBar(0.85, isAccent: true),
                          _buildBar(1.0, isAccent: true, opacity: 1.0),
                          _buildBar(0.75, isAccent: true),
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
    );
  }

  Widget _buildBar(double heightFactor, {bool isAccent = false, double opacity = 0.4}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: FractionallySizedBox(
          alignment: Alignment.bottomCenter,
          heightFactor: heightFactor,
          child: Container(
            decoration: BoxDecoration(
              color: isAccent 
                  ? widget.accentColor.withValues(alpha: opacity) 
                  : const Color(0xFF454850).withValues(alpha: 0.2), // outline-variant
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ),
        ),
      ),
    );
  }
}
