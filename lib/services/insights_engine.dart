import 'package:collection/collection.dart';

import '../models/category.dart';
import '../models/insight.dart';
import '../models/period.dart';
import '../models/spend_tag.dart';
import '../models/transaction.dart';
import 'analytics.dart';

class InsightsEngine {
  const InsightsEngine({this.analytics = const BudgetAnalytics()});

  final BudgetAnalytics analytics;

  List<SavingTip> savingTips({
    required List<MoneyTx> txs,
    required PeriodSnapshot snapshot,
    required PeriodKind period,
  }) {
    final tips = <SavingTip>[];
    final months = _monthsIn(period, snapshot);

    if (snapshot.optional > 0) {
      final cut = snapshot.optional * 0.3;
      tips.add(
        SavingTip(
          title: 'Sumažinkite nebūtinus pirkinius 30%',
          detail:
              'Nebūtinos išlaidos sudaro ${_pct(snapshot.optionalShare)} visų išlaidų. Jei šį krepšelį apkarpytumėte trečdaliu, sutaupytumėte apie ${_eur(cut)} per laikotarpį.',
          monthlySaving: cut / months,
          priority: snapshot.optionalShare > 0.28 ? 10 : 6,
        ),
      );
    }

    final dining = snapshot.byCategory
        .firstWhereOrNull((c) => c.categoryId == Categories.dining.id);
    final groceries = snapshot.byCategory
        .firstWhereOrNull((c) => c.categoryId == Categories.groceries.id);
    if (dining != null &&
        groceries != null &&
        groceries.amount > 0 &&
        dining.amount > groceries.amount * 0.45) {
      final extra = dining.amount - groceries.amount * 0.35;
      tips.add(
        SavingTip(
          title: 'Restoranai veja maisto krepšelį',
          detail:
              'Restoranams išleidote ${_eur(dining.amount)}, maistui namie ${_eur(groceries.amount)}. Daugiau gaminant namie, realu susigrąžinti apie ${_eur(extra)}.',
          monthlySaving: extra / months,
          priority: 8,
        ),
      );
    }

    final recurring = _recurringMerchants(txs);
    for (final item in recurring.take(4)) {
      if (item.optional) {
        tips.add(
          SavingTip(
            title: 'Peržiūrėkite „${item.merchant}“ prenumeratą',
            detail:
                'Kartojasi ${item.count} kartus, vidutiniškai ${_eur(item.average)} už kartą. Jei šiuo metu nenaudojate — atsisakius sutaupytumėte ~${_eur(item.average)} per ciklą.',
            monthlySaving: item.average,
            priority: 7,
          ),
        );
      }
    }

    final grown = snapshot.byCategory
        .where((c) => c.previousAmount > 0 && c.deltaPct != null && c.deltaPct! > 0.18)
        .toList()
      ..sort((a, b) => (b.deltaPct ?? 0).compareTo(a.deltaPct ?? 0));
    if (grown.isNotEmpty) {
      final c = grown.first;
      final cat = Categories.byId(c.categoryId);
      tips.add(
        SavingTip(
          title: '${cat.name} pašoko palyginti su ${period.previousLabel}',
          detail:
              'Ši kategorija išaugo ${_pct(c.deltaPct ?? 0)} (${_eur(c.delta)}). Vertėtų nustatyti lubas ir sekti savaitės eigą.',
          monthlySaving: c.delta / months,
          priority: 9,
        ),
      );
    }

    final transport = snapshot.byCategory
        .firstWhereOrNull((c) => c.categoryId == Categories.transport.id);
    if (transport != null && transport.optional > 40) {
      tips.add(
        SavingTip(
          title: 'Dalį kelionių perkelkite į viešąjį transportą',
          detail:
              'Nebūtinas transportas: ${_eur(transport.optional)}. Bolt / CityBee vietoj kelių kelionių per savaitę greitai susideda.',
          monthlySaving: transport.optional * 0.25 / months,
          priority: 5,
        ),
      );
    }

    tips.sort((a, b) => b.priority.compareTo(a.priority));
    return tips.take(6).toList();
  }

  List<BiggestValueItem> biggestValue({
    required List<MoneyTx> txs,
    required DateRange current,
  }) {
    final inPeriod = txs.where((t) => current.contains(t.bookedAt)).toList();
    final items = <BiggestValueItem>[];

    final expenses = inPeriod.where((t) => t.isExpense).toList()
      ..sort((a, b) => b.absAmount.compareTo(a.absAmount));
    for (final tx in expenses.take(5)) {
      items.add(
        BiggestValueItem(
          title: tx.merchant.isNotEmpty ? tx.merchant : tx.description,
          detail:
              '${Categories.byId(tx.categoryId).name} · ${tx.tag.label} · ${tx.bank.shortLabel}',
          amount: tx.absAmount,
          kind: ValueKind.expense,
        ),
      );
    }

    final optionalByCategory = <String, double>{};
    for (final tx in inPeriod.where((t) => t.isExpense && t.tag == SpendTag.optional)) {
      optionalByCategory[tx.categoryId] =
          (optionalByCategory[tx.categoryId] ?? 0) + tx.absAmount;
    }
    final fattest = optionalByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (fattest.isNotEmpty) {
      final top = fattest.first;
      items.add(
        BiggestValueItem(
          title: 'Didžiausia taupymo svirtis: ${Categories.byId(top.key).name}',
          detail:
              'Čia susikaupė daugiausia nebūtinų išlaidų. Apkarpius pusę, laikotarpiu liktų +${_eur(top.value / 2)}.',
          amount: top.value,
          kind: ValueKind.opportunity,
        ),
      );
    }

    for (final rec in _recurringMerchants(inPeriod).take(3)) {
      items.add(
        BiggestValueItem(
          title: rec.merchant,
          detail:
              '${rec.count} kartojimai · ${rec.optional ? 'nebūtina' : 'būtina'}',
          amount: rec.total,
          kind: ValueKind.recurring,
        ),
      );
    }

    return items;
  }

  List<_Recurring> _recurringMerchants(List<MoneyTx> txs) {
    final groups = groupBy(
      txs.where((t) => t.isExpense),
      (MoneyTx t) => (t.merchant.isNotEmpty ? t.merchant : t.description)
          .trim()
          .toLowerCase(),
    );
    final result = <_Recurring>[];
    groups.forEach((key, list) {
      if (list.length < 2) return;
      final total = list.fold<double>(0, (s, t) => s + t.absAmount);
      result.add(
        _Recurring(
          merchant: list.first.merchant.isNotEmpty
              ? list.first.merchant
              : list.first.description,
          count: list.length,
          total: total,
          average: total / list.length,
          optional: list.every((t) => t.tag == SpendTag.optional),
        ),
      );
    });
    result.sort((a, b) => b.total.compareTo(a.total));
    return result;
  }

  double _monthsIn(PeriodKind period, PeriodSnapshot snapshot) {
    switch (period) {
      case PeriodKind.week:
        return 7 / 30.4;
      case PeriodKind.month:
        return 1;
      case PeriodKind.year:
        return 12;
      case PeriodKind.allTime:
        return snapshot.expenses == 0 ? 1 : 12;
    }
  }

  String _eur(double v) => '${v.toStringAsFixed(2)} €';
  String _pct(double v) => '${(v * 100).toStringAsFixed(0)}%';
}

class _Recurring {
  const _Recurring({
    required this.merchant,
    required this.count,
    required this.total,
    required this.average,
    required this.optional,
  });

  final String merchant;
  final int count;
  final double total;
  final double average;
  final bool optional;
}
