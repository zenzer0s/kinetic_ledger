import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/rate_provider.dart';

class LiveTicker extends ConsumerStatefulWidget {
  const LiveTicker({super.key});

  @override
  ConsumerState<LiveTicker> createState() => _LiveTickerState();
}

class _LiveTickerState extends ConsumerState<LiveTicker> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rateAsync = ref.watch(rateProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10131B), // surface-container-low
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFF454850).withValues(alpha: 0.2)),
      ),
      child: rateAsync.when(
        data: (rate) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _pulseAnimation,
              child: const Icon(Icons.circle, color: Color(0xFF00D4B4), size: 10),
            ),
            const SizedBox(width: 8),
            Text(
              '1 USD = ₹${rate.rate.toStringAsFixed(2)}',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00D4B4), // Teal
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '·  ECB  ·  ${rate.updatedLabel}',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFA9ABB4), // on-surface-variant
              ),
            ),
          ],
        ),
        loading: () => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4865FB)),
            ),
            const SizedBox(width: 8),
            Text('Fetching Live Rate...', style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFFA9ABB4))),
          ],
        ),
        error: (err, stack) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6E84), size: 14),
            const SizedBox(width: 8),
            Text('Offline Mode', style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFFFF6E84))),
          ],
        ),
      ),
    );
  }
}
