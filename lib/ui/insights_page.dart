import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/insight.dart';
import '../state/budget_controller.dart';
import 'theme.dart';
import 'widgets/period_selector.dart';
import 'widgets/person_filter.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BudgetController>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
        Row(
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
              trailing: Text(
                '${formatEur(tip.monthlySaving)}/mėn',
                style: const TextStyle(fontWeight: FontWeight.w700),
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
              trailing: Text(
                formatEur(item.amount),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}
