import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/spend_tag.dart';
import '../models/transaction.dart';
import '../state/budget_controller.dart';
import 'layout.dart';
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
    final unusual = controller.unusualTransactionIds;
    final household = controller.state.household;
    final dateFmt = DateFormat('EEE, MMM d', 'lt');
    final padding = AppLayout.pagePadding(context);
    final phone = AppLayout.isPhone(context);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            padding.left,
            padding.top,
            padding.right,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PeriodSelector(
                  value: controller.period,
                  onChanged: controller.setPeriod,
                ),
                SizedBox(height: phone ? 8 : 10),
                PersonFilterBar(
                  household: household,
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
                SizedBox(height: phone ? 8 : 10),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Paieška pagal pardavėją ar aprašymą',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: controller.setQuery,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (txs.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('Nėra operacijų pagal filtrus.')),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              4,
              padding.right,
              padding.bottom,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final tx = txs[index];
                  final showHeader = index == 0 ||
                      !_sameDay(tx.bookedAt, txs[index - 1].bookedAt);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeader)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                          child: Text(
                            dateFmt.format(tx.bookedAt),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      _TxTile(
                        tx: tx,
                        personName: household.byId(tx.personId).name,
                        unusual: unusual.contains(tx.id),
                        onTap: () => _edit(context, controller, tx),
                      ),
                    ],
                  );
                },
                childCount: txs.length,
                addAutomaticKeepAlives: false,
              ),
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
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.merchant.isEmpty ? tx.description : tx.merchant,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(formatEur(tx.amount)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Kategorija'),
                      items: [
                        for (final c in Categories.all)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) =>
                          setModal(() => categoryId = v ?? categoryId),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: personId,
                      isExpanded: true,
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
                      onChanged: (v) =>
                          setModal(() => personId = v ?? personId),
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
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
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
                    ),
                  ],
                ),
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outline, width: 1.2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.merchant.isEmpty ? tx.description : tx.merchant,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${cat.name} · ${tx.tag.label} · $personName · ${tx.bank.shortLabel}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (unusual) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Neįprasta',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.expense,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Text(
                    formatSignedEur(tx.amount),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: tx.isIncome
                          ? AppColors.income
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
