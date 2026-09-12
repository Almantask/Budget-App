import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/gamification.dart';
import '../models/insight.dart';
import '../models/notice.dart';
import '../state/budget_controller.dart';
import '../services/dates.dart';
import 'layout.dart';
import 'motion.dart';
import 'theme.dart';
import 'widgets/animated_number.dart';
import 'widgets/period_selector.dart';
import 'widgets/person_filter.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BudgetController>();
    final stretch = controller.stretchGoal;
    final level = controller.levelProgress;
    final quests = controller.monthQuestList;
    final hits = controller.stretchHistory;
    final currentMonth = controller.viewMonth;

    return ListView(
      padding: AppLayout.pagePadding(context),
      children: [
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
        const SizedBox(height: 16),
        _StretchCard(
          stretch: stretch,
          net: controller.currentMonthPoint.net,
          level: level,
          streak: controller.loggingStreak,
        ),
        const SizedBox(height: 12),
        Text('Mėnesio iššūkis', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final quest in quests) _QuestTile(quest: quest),
        const SizedBox(height: 16),
        Text('Taupymo istorija', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final hit in hits.reversed.take(6))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(hit.month),
            subtitle: Text(
              hit.month == currentMonth
                  ? 'Vyksta · tikslas ${formatEur(hit.goal.target)}'
                  : hit.hit
                      ? 'Pasiekta · ${formatEur(hit.net)}'
                      : 'Praleista · ${formatEur(hit.net)}',
            ),
            trailing: Icon(
              hit.month == currentMonth
                  ? Icons.hourglass_top
                  : hit.hit
                      ? Icons.check_circle_outline
                      : Icons.remove_circle_outline,
            ),
          ),
        const SizedBox(height: 8),
        Text('Ženkleliai', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final badge in controller.achievements)
              Chip(
                avatar: Icon(
                  badge.unlocked ? Icons.emoji_events : Icons.lock_outline,
                  size: 16,
                ),
                label: Text(badge.title),
                backgroundColor: badge.unlocked
                    ? const Color(0xFF0F6B5C).withValues(alpha: 0.12)
                    : null,
              ),
          ],
        ),
        if (controller.state.notices.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Įspėjimai po sinchronizacijos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (controller.unreadNotices.isNotEmpty)
                TextButton(
                  onPressed: controller.markNoticesRead,
                  child: const Text('Pažymėti skaitytais'),
                ),
            ],
          ),
          for (final notice in controller.state.notices.take(8))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                notice.level == AlertLevel.breach
                    ? Icons.error_outline
                    : Icons.warning_amber_outlined,
              ),
              title: Text(notice.label),
              subtitle: Text(notice.message),
              trailing: Text(
                dateKey(notice.at),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () async {
                final csv = controller.csvForVisible();
                await Clipboard.setData(ClipboardData(text: csv));
                await controller.exportCsv();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('CSV nukopijuotas ir paruoštas dalintis.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('Eksportuoti CSV'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Kur sutaupyti', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final tip in controller.savingTips)
          Card(
            child: ListTile(
              leading: const Icon(Icons.tips_and_updates_outlined),
              title: Text(tip.title),
              subtitle: Text(tip.detail),
              trailing: FittedBox(
                child: Text(
                  '${formatEur(tip.monthlySaving)}/mėn',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text('Didžiausia vertė', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final item in controller.biggestValue)
          Card(
            child: ListTile(
              leading: Icon(switch (item.kind) {
                ValueKind.expense => Icons.payments_outlined,
                ValueKind.opportunity => Icons.savings_outlined,
                ValueKind.recurring => Icons.repeat,
              }),
              title: Text(item.title),
              subtitle: Text(item.detail),
              trailing: AnimatedEur(
                value: item.amount,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

class _StretchCard extends StatelessWidget {
  const _StretchCard({
    required this.stretch,
    required this.net,
    required this.level,
    required this.streak,
  });

  final StretchGoal stretch;
  final double net;
  final LevelProgress level;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final progress = stretch.target <= 0
        ? 0.0
        : (net / stretch.target).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Taupymo tikslas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(stretch.reason),
            const SizedBox(height: 12),
            _AnimatedBar(value: progress, minHeight: 10),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AnimatedEur(
                  value: net,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'iš ${formatEur(stretch.target)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lygis ${level.level} · ${level.totalXp} XP',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('Serija: $streak d.'),
              ],
            ),
            const SizedBox(height: 6),
            _AnimatedBar(value: level.progress, minHeight: 6),
          ],
        ),
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.quest});
  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final ratio = quest.target == 0 ? 0.0 : (quest.current / quest.target).clamp(0.0, 1.0);
    return Card(
      child: ListTile(
        leading: Icon(
          quest.complete ? Icons.check_circle : Icons.flag_outlined,
          color: quest.complete ? const Color(0xFF1B7F5A) : null,
        ),
        title: Text(quest.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(quest.detail),
            const SizedBox(height: 6),
            _AnimatedBar(value: ratio, minHeight: 6),
          ],
        ),
        isThreeLine: true,
        trailing: Text('+${quest.xp}'),
      ),
    );
  }
}

class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({required this.value, required this.minHeight});

  final double value;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: AppMotion.of(context, AppMotion.progress),
      curve: AppMotion.easeOut,
      builder: (context, v, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: v, minHeight: minHeight),
        );
      },
    );
  }
}

