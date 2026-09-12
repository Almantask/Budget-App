import 'package:flutter/material.dart';

import '../theme.dart';

class DeltaBadge extends StatelessWidget {
  const DeltaBadge({
    super.key,
    required this.delta,
    required this.deltaPct,
    required this.previousLabel,
    this.lowerIsBetter = true,
    this.onDark = false,
  });

  final double delta;
  final double? deltaPct;
  final String previousLabel;
  final bool lowerIsBetter;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final improved = lowerIsBetter ? delta < 0 : delta > 0;
    final Color color;
    if (delta == 0) {
      color = onDark ? Colors.white70 : const Color(0xFF6B7280);
    } else if (onDark) {
      color = Colors.white;
    } else {
      color = improved ? AppColors.income : const Color(0xFFB42318);
    }
    final arrow = delta == 0 ? '→' : (delta < 0 ? '↓' : '↑');
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: onDark
                ? Colors.white.withValues(alpha: 0.14)
                : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              '$arrow ${formatSignedEur(delta)} (${formatPct(deltaPct)}) vs $previousLabel',
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
