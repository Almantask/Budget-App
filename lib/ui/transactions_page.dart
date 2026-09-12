import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/spend_tag.dart';
import '../models/transaction.dart';
import '../state/budget_controller.dart';
import 'theme.dart';
import 'widgets/category_filter.dart';
import 'widgets/period_selector.dart';
import 'widgets/person_filter.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BudgetController>();
    final txs = controller.visibleTransactions;
    final dateFmt = DateFormat('EEE, MMM d', 'lt');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 10),
              CategoryFilterBar(
                categoryId: controller.filters.categoryId,
                tag: controller.filters.tag,
                onCategory: controller.setCategoryFilter,
                onTag: controller.setTagFilter,
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Paieška pagal pardavėją ar aprašymą',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: controller.setQuery,
              ),
            ],
          ),
        ),
        Expanded(
          child: txs.isEmpty
              ? const Center(child: Text('Nėra operacijų pagal filtrus.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                  itemCount: txs.length,
                  itemBuilder: (context, index) {
                    final tx = txs[index];
                    final showHeader = index == 0 ||
                        !_sameDay(tx.bookedAt, txs[index - 1].bookedAt);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                            child: Text(
                              dateFmt.format(tx.bookedAt),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        _TxTile(
                          tx: tx,
                          personName: controller.state.household
                              .byId(tx.personId)
                              .name,
                          unusual: controller.unusualTransactionIds.contains(tx.id),
                          onTap: () => _edit(context, controller, tx),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _edit(
    BuildContext context,
    BudgetController controller,
    MoneyTx tx,
  ) async {
    var categoryId = tx.categoryId;
    var tag = tx.tag;
    var personId = tx.personId;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.merchant.isEmpty ? tx.description : tx.merchant,
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(formatEur(tx.amount)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: categoryId,
                    decoration: const InputDecoration(labelText: 'Kategorija'),
                    items: [
                      for (final c in Categories.all)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setModal(() => categoryId = v ?? categoryId),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: personId,
                    decoration: const InputDecoration(labelText: 'Žmogus'),
                    items: [
                      DropdownMenuItem(
                        value: controller.state.household.me.id,
                        child: Text(controller.state.household.me.name),
                      ),
                      DropdownMenuItem(
                        value: controller.state.household.partner.id,
                        child: Text(controller.state.household.partner.name),
                      ),
                    ],
                    onChanged: (v) => setModal(() => personId = v ?? personId),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(SpendTag.essential.label),
                        selected: tag == SpendTag.essential,
                        onSelected: (_) =>
                            setModal(() => tag = SpendTag.essential),
                      ),
                      ChoiceChip(
                        label: Text(SpendTag.optional.label),
                        selected: tag == SpendTag.optional,
                        onSelected: (_) =>
                            setModal(() => tag = SpendTag.optional),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      await controller.updateTransaction(
                        tx.copyWith(
                          categoryId: categoryId,
                          tag: tag,
                          personId: personId,
                        ),
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Išsaugoti'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({
    required this.tx,
    required this.personName,
    required this.unusual,
    required this.onTap,
  });

  final MoneyTx tx;
  final String personName;
  final bool unusual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cat = Categories.byId(tx.categoryId);
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(tx.merchant.isEmpty ? tx.description : tx.merchant),
        subtitle: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${cat.name} · ${tx.tag.label} · $personName · ${tx.bank.shortLabel}'),
            if (unusual)
              const Chip(
                visualDensity: VisualDensity.compact,
                label: Text('Neįprasta'),
                padding: EdgeInsets.zero,
              ),
          ],
        ),
        trailing: Text(
          formatSignedEur(tx.amount),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: tx.isIncome
                ? const Color(0xFF1B7F5A)
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
