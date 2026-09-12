import 'package:flutter/material.dart';

import '../theme.dart';

class DeltaBadge extends StatelessWidget {
  const DeltaBadge({
    super.key,
    required this.delta,
    required this.deltaPct,
    required this.previousLabel,
    this.lowerIsBetter = true,
  });

  final double delta;
  final double? deltaPct;
  final String previousLabel;
  final bool lowerIsBetter;

  @override
  Widget build(BuildContext context) {
    final improved = lowerIsBetter ? delta < 0 : delta > 0;
    final color = delta == 0
        ? Colors.grey
        : (improved ? const Color(0xFF1B7F5A) : const Color(0xFFB42318));
    final arrow = delta == 0
        ? '→'
        : (delta < 0 ? '↓' : '↑');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$arrow ${formatSignedEur(delta)} (${formatPct(deltaPct)}) vs $previousLabel',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
