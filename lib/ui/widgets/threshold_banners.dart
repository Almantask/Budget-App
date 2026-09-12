import 'package:flutter/material.dart';

import '../../models/notice.dart';
import '../theme.dart';

class ThresholdBanners extends StatelessWidget {
  const ThresholdBanners({super.key, required this.alerts});

  final List<ThresholdAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Biudžeto ribos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final alert in alerts.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              color: _color(alert.level).withValues(alpha: 0.16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_icon(alert.level), color: _color(alert.level)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${alert.label} · ${_label(alert.level)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            alert.message,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(alert.ratio * 100).round()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _color(alert.level),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _label(AlertLevel level) => switch (level) {
        AlertLevel.breach => 'Viršyta',
        AlertLevel.warning => 'Įspėjimas',
        AlertLevel.pace => 'Tempas',
        AlertLevel.ok => 'Gerai',
      };

  static IconData _icon(AlertLevel level) => switch (level) {
        AlertLevel.breach => Icons.error_outline,
        AlertLevel.warning => Icons.warning_amber_outlined,
        AlertLevel.pace => Icons.speed,
        AlertLevel.ok => Icons.check,
      };

  static Color _color(AlertLevel level) => switch (level) {
        AlertLevel.breach => const Color(0xFF9B1C14),
        AlertLevel.warning => const Color(0xFFB54708),
        AlertLevel.pace => const Color(0xFF175CD3),
        AlertLevel.ok => AppTheme.seed,
      };
}

class AnomalyList extends StatelessWidget {
  const AnomalyList({super.key, required this.items});

  final List<SpendingAnomaly> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Neįprastos išlaidos',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final item in items.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      item.severity == AnomalySeverity.unusual
                          ? Icons.priority_high
                          : Icons.visibility_outlined,
                      color: item.severity == AnomalySeverity.unusual
                          ? const Color(0xFF9B1C14)
                          : const Color(0xFFB54708),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            item.message,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: Text(
                        formatEur(item.amount),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
