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
    final phone = AppLayout.isPhone(context);
    final compact = AppLayout.isCompact(context);
    final cardPad = AppLayout.cardPadding(context);
    final gap = phone ? 10.0 : 12.0;

    final filters = [
      PeriodSelector(
        value: controller.period,
        onChanged: controller.setPeriod,
      ),
      SizedBox(height: phone ? 8 : 10),
      PersonFilterBar(
        household: controller.state.household,
        value: controller.filters.personId,
        onChanged: controller.setPersonFilter,
      ),
      SizedBox(height: phone ? 8 : 10),
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
        padding: cardPad,
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
        padding: cardPad,
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

    final names =
        '${controller.state.household.me.name} ir ${controller.state.household.partner.name}';
    final dateLabel =
        '${fmt.format(range.start)} – ${fmt.format(range.end.subtract(const Duration(days: 1)))}';

    final header = [
      Text(
        names,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: compact || phone
            ? Theme.of(context).textTheme.titleMedium
            : Theme.of(context).textTheme.headlineSmall,
      ),
      SizedBox(height: compact ? 2 : 4),
      Text(
        dateLabel,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    ];

    final heroFirst = phone || compact;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverList.list(
            children: [
              ...header,
              SizedBox(height: heroFirst ? 10 : 16),
              if (!heroFirst) ...[
                ...filters,
                const SizedBox(height: 16),
              ],
              if (twoPane)
                _TwoPane(
                  left: [hero, SizedBox(height: gap), split],
                  right: [chart, SizedBox(height: gap), categories],
                )
              else ...[
                hero,
                SizedBox(height: gap),
                if (heroFirst && !compact) ...[
                  ...filters,
                  SizedBox(height: gap),
                ],
                chart,
              ],
              if (heroFirst && compact) ...[
                SizedBox(height: gap),
                ...filters,
              ],
              SizedBox(height: gap),
              ThresholdBanners(alerts: controller.thresholdAlerts),
              SizedBox(height: gap),
              AnomalyList(items: controller.spendingAnomalies),
              if (!twoPane) ...[
                SizedBox(height: gap),
                split,
                SizedBox(height: gap),
                categories,
              ],
            ],
          ),
        ),
      ],
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
    final compact = AppLayout.isCompact(context);
    final phone = AppLayout.isPhone(context);
    final radius = AppLayout.cardRadius(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFF07362F), width: 1.2),
        boxShadow: phone
            ? const [
                BoxShadow(
                  color: Color(0x3307362F),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x5907362F),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: ColoredBox(
          color: const Color(0xFF0A4A40),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              phone ? 16 : 22,
              compact ? 14 : 18,
              phone ? 16 : 22,
              compact ? 12 : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Išlaidos',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
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
                          fontSize: phone ? 30 : 34,
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
                SizedBox(height: phone ? 12 : 16),
                Row(
                  children: [
                    Expanded(
                      child: _GlassStat(label: 'Pajamos', value: income),
                    ),
                    const SizedBox(width: 8),
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
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x66FFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
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
                  const ColoredBox(
                    color: Colors.white,
                    child: SizedBox(width: 2),
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
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ink.withValues(alpha: 0.35)),
          ),
        ),
        const SizedBox(width: 6),
        Text('$label ', style: Theme.of(context).textTheme.bodySmall),
        AnimatedEur(
          value: amount,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ],
    );
  }
}
