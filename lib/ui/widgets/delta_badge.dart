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
      color = onDark ? Colors.white : AppColors.muted;
    } else if (onDark) {
      color = Colors.white;
    } else {
      color = improved ? AppColors.income : const Color(0xFF9B1C14);
    }
    final arrow = delta == 0 ? '→' : (delta < 0 ? '↓' : '↑');
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: onDark ? const Color(0x33FFFFFF) : color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: onDark ? const Color(0x99FFFFFF) : color,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            '$arrow ${formatSignedEur(delta)} (${formatPct(deltaPct)}) vs $previousLabel',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }
}
