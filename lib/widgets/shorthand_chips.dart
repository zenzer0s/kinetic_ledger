
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ShorthandChips extends StatefulWidget {
  final List<String> labels;
  final String? activeLabel;
  final ValueChanged<String> onChipSelected;

  const ShorthandChips({
    super.key,
    required this.labels,
    this.activeLabel,
    required this.onChipSelected,
  });

  @override
  State<ShorthandChips> createState() => _ShorthandChipsState();
}

class _ShorthandChipsState extends State<ShorthandChips> with TickerProviderStateMixin {
  late Map<String, AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (var label in widget.labels)
        label: AnimationController(
          duration: const Duration(milliseconds: 150),
          vsync: this,
          lowerBound: 0.93,
          upperBound: 1.0,
          value: 1.0,
        )
    };
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleTapDown(String label) {
    _controllers[label]?.reverse();
  }

  void _handleTapUp(String label) {
    _controllers[label]?.forward();
    widget.onChipSelected(label);
  }

  void _handleTapCancel(String label) {
    _controllers[label]?.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      children: widget.labels.map((label) {
        final isActive = widget.activeLabel == label;
        final controller = _controllers[label]!;

        return GestureDetector(
          onTapDown: (_) => _handleTapDown(label),
          onTapUp: (_) => _handleTapUp(label),
          onTapCancel: () => _handleTapCancel(label),
          child: ScaleTransition(
            scale: controller,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: isActive ? const Color(0xFF9AA8FF) : const Color(0xFF212630), // primary vs surfaceContainerHighest
                border: Border.all(
                  color: isActive ? Colors.transparent : const Color(0xFF454850).withValues(alpha: 0.1),
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xFF9AA8FF).withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: isActive ? const Color(0xFF001D8B) : const Color(0xFFF2F3FD), // on-primary vs on-surface
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
