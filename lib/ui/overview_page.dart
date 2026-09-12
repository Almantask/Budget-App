import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/budget_controller.dart';
import 'theme.dart';
import 'widgets/category_bars.dart';
import 'widgets/category_filter.dart';
import 'widgets/delta_badge.dart';
import 'widgets/period_selector.dart';
import 'widgets/person_filter.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BudgetController>();
    final snap = controller.snapshot;
    final range = controller.currentRange;
    final fmt = DateFormat('MMM d', 'lt');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          '${controller.state.household.me.name} ir ${controller.state.household.partner.name}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '${fmt.format(range.start)} – ${fmt.format(range.end.subtract(const Duration(days: 1)))}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        PeriodSelector(
          value: controller.period,
          onChanged: controller.setPeriod,
        ),
        const SizedBox(height: 12),
        PersonFilterBar(
          household: controller.state.household,
          value: controller.filters.personId,
          onChanged: controller.setPersonFilter,
        ),
        const SizedBox(height: 12),
        CategoryFilterBar(
          categoryId: controller.filters.categoryId,
          tag: controller.filters.tag,
          onCategory: controller.setCategoryFilter,
          onTag: controller.setTagFilter,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Išlaidos'),
                const SizedBox(height: 4),
                Text(
                  formatEur(snap.expenses),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                DeltaBadge(
                  delta: snap.expenseDelta,
                  deltaPct: snap.expenseDeltaPct,
                  previousLabel: controller.period.previousLabel,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(label: 'Pajamos', value: formatEur(snap.income)),
                    ),
                    Expanded(
                      child: _MiniStat(label: 'Likutis', value: formatEur(snap.net)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Būtina vs nebūtina'),
                const SizedBox(height: 12),
                _SplitBar(essential: snap.essential, optional: snap.optional),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _LegendDot(color: const Color(0xFF0F6B5C), label: 'Būtina ${formatEur(snap.essential)}'),
                    const SizedBox(width: 16),
                    _LegendDot(color: const Color(0xFFC9783A), label: 'Nebūtina ${formatEur(snap.optional)}'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kategorijos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                CategoryBars(rows: snap.byCategory),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.essential, required this.optional});
  final double essential;
  final double optional;

  @override
  Widget build(BuildContext context) {
    final total = essential + optional;
    final essentialFlex = total == 0 ? 1 : (essential / total * 100).round().clamp(1, 99);
    final optionalFlex = 100 - essentialFlex;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 16,
        child: Row(
          children: [
            Expanded(flex: essentialFlex, child: Container(color: const Color(0xFF0F6B5C))),
            Expanded(flex: optionalFlex, child: Container(color: const Color(0xFFC9783A))),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
