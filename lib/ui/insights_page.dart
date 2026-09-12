import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/gamification.dart';
import '../models/insight.dart';
import '../models/notice.dart';
import '../state/budget_controller.dart';
import '../services/dates.dart';
import 'layout.dart';
import 'theme.dart';
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
    final phone = AppLayout.isPhone(context);
    final gap = phone ? 10.0 : 12.0;

    return ListView(
      padding: AppLayout.pagePadding(context),
      children: [
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
        const SizedBox(height: 14),
        _StretchCard(
          stretch: stretch,
          net: controller.currentMonthPoint.net,
          level: level,
          streak: controller.loggingStreak,
        ),
        SizedBox(height: gap),
        Text('Mėnesio iššūkis', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final quest in quests) _QuestTile(quest: quest),
        const SizedBox(height: 16),
        Text('Taupymo istorija', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final hit in hits.reversed.take(6))
          _InfoRow(
            title: hit.month,
            detail: hit.month == currentMonth
                ? 'Vyksta · tikslas ${formatEur(hit.goal.target)}'
                : hit.hit
                    ? 'Pasiekta · ${formatEur(hit.net)}'
                    : 'Praleista · ${formatEur(hit.net)}',
            trailing: Icon(
              hit.month == currentMonth
                  ? Icons.hourglass_top
                  : hit.hit
                      ? Icons.check_circle_outline
                      : Icons.remove_circle_outline,
              color: hit.hit ? AppColors.income : AppColors.muted,
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
                  color: badge.unlocked ? Colors.white : AppColors.muted,
                ),
                label: Text(badge.title),
                backgroundColor:
                    badge.unlocked ? AppColors.seed : Colors.white,
                labelStyle: TextStyle(
                  color: badge.unlocked ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
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
                  child: const Text('Skaityta'),
                ),
            ],
          ),
          for (final notice in controller.state.notices.take(8))
            _InfoRow(
              title: notice.label,
              detail: notice.message,
              trailing: Text(
                dateKey(notice.at),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              leading: Icon(
                notice.level == AlertLevel.breach
                    ? Icons.error_outline
                    : Icons.warning_amber_outlined,
                color: notice.level == AlertLevel.breach
                    ? const Color(0xFF9B1C14)
                    : const Color(0xFFB54708),
              ),
            ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
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
        ),
        const SizedBox(height: 20),
        Text('Kur sutaupyti', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final tip in controller.savingTips)
          _ValueCard(
            icon: Icons.tips_and_updates_outlined,
            title: tip.title,
            detail: tip.detail,
            amountLabel: '${formatEur(tip.monthlySaving)}/mėn',
          ),
        const SizedBox(height: 20),
        Text('Didžiausia vertė', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final item in controller.biggestValue)
          _ValueCard(
            icon: switch (item.kind) {
              ValueKind.expense => Icons.payments_outlined,
              ValueKind.opportunity => Icons.savings_outlined,
              ValueKind.recurring => Icons.repeat,
            },
            title: item.title,
            detail: item.detail,
            amountLabel: formatEur(item.amount),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.title,
    required this.detail,
    required this.trailing,
    this.leading,
  });

  final String title;
  final String detail;
  final Widget trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.amountLabel,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(detail, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Text(
                      amountLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
        padding: AppLayout.cardPadding(context),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: progress, minHeight: 10),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  formatEur(net),
                  style: const TextStyle(fontWeight: FontWeight.w800),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: level.progress,
                minHeight: 6,
              ),
            ),
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
    final ratio =
        quest.target == 0 ? 0.0 : (quest.current / quest.target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                quest.complete ? Icons.check_circle : Icons.flag_outlined,
                color: quest.complete ? AppColors.income : AppColors.ink,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      quest.detail,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+${quest.xp}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
