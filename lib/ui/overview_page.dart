import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/budget_controller.dart';
import 'layout.dart';
import 'motion.dart';
import 'theme.dart';
import 'widgets/animated_number.dart';
import 'widgets/category_bars.dart';
import 'widgets/category_filter.dart';
import 'widgets/delta_badge.dart';
import 'widgets/period_selector.dart';
import 'widgets/person_filter.dart';
import 'widgets/threshold_banners.dart';
import 'widgets/trend_chart.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BudgetController>();
    final snap = controller.snapshot;
    final range = controller.currentRange;
    final fmt = DateFormat('MMM d', 'lt');
    final twoPane = AppLayout.useTwoPane(context);
    final padding = AppLayout.pagePadding(context);

    final filters = [
      PeriodSelector(
        value: controller.period,
        onChanged: controller.setPeriod,
      ),
      const SizedBox(height: 10),
      PersonFilterBar(
        household: controller.state.household,
        value: controller.filters.personId,
        onChanged: controller.setPersonFilter,
      ),
      const SizedBox(height: 10),
      CategoryFilterBar(
        categoryId: controller.filters.categoryId,
        tag: controller.filters.tag,
        onCategory: controller.setCategoryFilter,
        onTag: controller.setTagFilter,
      ),
    ];

    final hero = _HeroSpendCard(
      expenses: snap.expenses,
      income: snap.income,
      net: snap.net,
      delta: snap.expenseDelta,
      deltaPct: snap.expenseDeltaPct,
      previousLabel: controller.period.previousLabel,
    );

    final split = Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Būtina vs nebūtina',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _SplitBar(essential: snap.essential, optional: snap.optional),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _LegendDot(
                  color: AppColors.seed,
                  label: 'Būtina',
                  amount: snap.essential,
                ),
                _LegendDot(
                  color: AppColors.optional,
                  label: 'Nebūtina',
                  amount: snap.optional,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final chart = TrendChart(
      months: controller.trendMonths,
      weeks: controller.trendWeeks,
      weekly: controller.trendWeekly,
      onWeeklyChanged: controller.setTrendWeekly,
    );

    final categories = Card(
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
    );

    final compact = AppLayout.isShort(context);
    final names =
        '${controller.state.household.me.name} ir ${controller.state.household.partner.name}';
    final dateLabel =
        '${fmt.format(range.start)} – ${fmt.format(range.end.subtract(const Duration(days: 1)))}';

    final header = [
      if (!compact)
        Text(names, style: Theme.of(context).textTheme.headlineSmall)
      else
        Text(
          names,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      SizedBox(height: compact ? 2 : 4),
      Text(
        dateLabel,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    ];

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...header,
          if (!compact) ...[
            const SizedBox(height: 16),
            ...filters,
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 12),
          if (twoPane)
            _TwoPane(
              left: [hero, const SizedBox(height: 12), split],
              right: [chart, const SizedBox(height: 12), categories],
            )
          else ...[
            hero,
            const SizedBox(height: 12),
            chart,
          ],
          if (compact) ...[
            const SizedBox(height: 12),
            ...filters,
          ],
          const SizedBox(height: 12),
          ThresholdBanners(alerts: controller.thresholdAlerts),
          const SizedBox(height: 12),
          AnomalyList(items: controller.spendingAnomalies),
          if (!twoPane) ...[
            const SizedBox(height: 12),
            split,
            const SizedBox(height: 12),
            categories,
          ],
        ],
      ),
    );
  }
}

class _TwoPane extends StatelessWidget {
  const _TwoPane({required this.left, required this.right});
  final List<Widget> left;
  final List<Widget> right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: left,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: right,
          ),
        ),
      ],
    );
  }
}

class _HeroSpendCard extends StatelessWidget {
  const _HeroSpendCard({
    required this.expenses,
    required this.income,
    required this.net,
    required this.delta,
    required this.deltaPct,
    required this.previousLabel,
  });

  final double expenses;
  final double income;
  final double net;
  final double delta;
  final double? deltaPct;
  final String previousLabel;

  @override
  Widget build(BuildContext context) {
    final compact = AppLayout.isShort(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.seed.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0C5649), Color(0xFF1A8F78)],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              compact ? 16 : 22,
              22,
              compact ? 14 : 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Išlaidos',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedEur(
                    value: expenses,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                DeltaBadge(
                  delta: delta,
                  deltaPct: deltaPct,
                  previousLabel: previousLabel,
                  onDark: true,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _GlassStat(label: 'Pajamos', value: income),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _GlassStat(label: 'Likutis', value: net),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassStat extends StatelessWidget {
  const _GlassStat({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedEur(
                value: value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
              ),
            ),
          ],
        ),
      ),
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
    final essentialShare = total == 0 ? 0.5 : essential / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.of(context, AppMotion.bars),
      curve: AppMotion.easeOut,
      builder: (context, t, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 14,
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: t.clamp(0.0, 1.0),
              child: Row(
                children: [
                  Expanded(
                    flex: math.max(1, (essentialShare * 1000).round()),
                    child: const ColoredBox(color: AppColors.seed),
                  ),
                  Expanded(
                    flex: math.max(1, ((1 - essentialShare) * 1000).round()),
                    child: const ColoredBox(color: AppColors.optional),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    required this.amount,
  });
  final Color color;
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label ', style: Theme.of(context).textTheme.bodySmall),
        AnimatedEur(
          value: amount,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ],
    );
  }
}
