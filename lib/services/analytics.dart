import '../models/category.dart';
import '../models/filters.dart';
import '../models/insight.dart';
import '../models/notice.dart';
import '../models/period.dart';
import '../models/spend_tag.dart';
import '../models/transaction.dart';
import 'dates.dart';

class BudgetAnalytics {
  const BudgetAnalytics();

  List<MoneyTx> applyFilters(List<MoneyTx> txs, BudgetFilters filters) {
    final q = filters.query.trim().toLowerCase();
    return txs.where((tx) {
      if (!filters.isBoth && tx.personId != filters.personId) return false;
      if (filters.categoryId != null && tx.categoryId != filters.categoryId) {
        return false;
      }
      if (filters.tag != null && tx.tag != filters.tag) return false;
      if (filters.bank != null && tx.bank != filters.bank) return false;
      if (q.isNotEmpty) {
        final hay =
            '${tx.description} ${tx.merchant} ${tx.bank.label}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  PeriodSnapshot snapshot({
    required List<MoneyTx> txs,
    required DateRange current,
    required DateRange previous,
  }) {
    final currentTxs = txs.where((t) => current.contains(t.bookedAt)).toList();
    final previousTxs =
        txs.where((t) => previous.contains(t.bookedAt)).toList();

    final byCategory = <CategorySpend>[];
    for (final category in Categories.spendable) {
      final nowAmt = _expenses(currentTxs, categoryId: category.id);
      final prevAmt = _expenses(previousTxs, categoryId: category.id);
      byCategory.add(
        CategorySpend(
          categoryId: category.id,
          amount: nowAmt,
          previousAmount: prevAmt,
          essential: _expenses(
            currentTxs,
            categoryId: category.id,
            tag: SpendTag.essential,
          ),
          optional: _expenses(
            currentTxs,
            categoryId: category.id,
            tag: SpendTag.optional,
          ),
        ),
      );
    }
    byCategory.sort((a, b) => b.amount.compareTo(a.amount));

    return PeriodSnapshot(
      income: _income(currentTxs),
      expenses: _expenses(currentTxs),
      essential: _expenses(currentTxs, tag: SpendTag.essential),
      optional: _expenses(currentTxs, tag: SpendTag.optional),
      previousIncome: _income(previousTxs),
      previousExpenses: _expenses(previousTxs),
      byCategory: byCategory,
      transactionCount: currentTxs.where((t) => !t.isTransfer).length,
    );
  }

  double _income(List<MoneyTx> txs) {
    var total = 0.0;
    for (final tx in txs) {
      if (tx.isIncome) total += tx.amount;
    }
    return total;
  }

  double _expenses(
    List<MoneyTx> txs, {
    String? categoryId,
    SpendTag? tag,
  }) {
    var total = 0.0;
    for (final tx in txs) {
      if (!tx.isExpense) continue;
      if (categoryId != null && tx.categoryId != categoryId) continue;
      if (tag != null && tx.tag != tag) continue;
      total += tx.absAmount;
    }
    return total;
  }

  DateTime? earliest(List<MoneyTx> txs) {
    if (txs.isEmpty) return null;
    return txs
        .map((t) => t.bookedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  MonthPoint monthTotals(List<MoneyTx> txs, String month) {
    var expenses = 0.0;
    var gains = 0.0;
    for (final tx in txs) {
      if (monthKey(tx.bookedAt) != month) continue;
      if (tx.isExpense) expenses += tx.absAmount;
      if (tx.isIncome) gains += tx.amount;
    }
    expenses = roundMoney(expenses);
    gains = roundMoney(gains);
    return MonthPoint(
      month: month,
      label: _monthLabel(month),
      expenses: expenses,
      gains: gains,
      net: roundMoney(gains - expenses),
    );
  }

  List<MonthPoint> monthlySeries(
    List<MoneyTx> txs,
    String throughMonth, {
    int count = 12,
  }) {
    return [
      for (final month in monthsUntil(throughMonth, count))
        monthTotals(txs, month),
    ];
  }

  List<MonthPoint> fullHistory(List<MoneyTx> txs, String throughMonth) {
    if (txs.isEmpty) return monthlySeries(txs, throughMonth, count: 1);
    final start = monthKey(
      txs.map((t) => t.bookedAt).reduce((a, b) => a.isBefore(b) ? a : b),
    );
    var count = 1;
    var cursor = start;
    while (cursor.compareTo(throughMonth) < 0) {
      cursor = addMonths(cursor, 1);
      count += 1;
    }
    return monthlySeries(txs, throughMonth, count: count);
  }

  List<MonthPoint> trimSeries(List<MonthPoint> series) {
    final first = series.indexWhere(
      (point) => point.gains > 0 || point.expenses > 0,
    );
    return first <= 0 ? series : series.sublist(first);
  }

  List<WeekPoint> weeklySeries(List<MoneyTx> txs, String month) {
    final lastDay = daysInMonth(month);
    final buckets = <WeekPoint>[];
    for (var start = 1; start <= lastDay; start += 7) {
      final end = start + 6 > lastDay ? lastDay : start + 6;
      final startIso = '$month-${start.toString().padLeft(2, '0')}';
      final endIso = '$month-${end.toString().padLeft(2, '0')}';
      var expenses = 0.0;
      var gains = 0.0;
      for (final tx in txs) {
        final key = dateKey(tx.bookedAt);
        if (key.compareTo(startIso) < 0 || key.compareTo(endIso) > 0) continue;
        if (tx.isExpense) expenses += tx.absAmount;
        if (tx.isIncome) gains += tx.amount;
      }
      buckets.add(
        WeekPoint(
          key: '$start-$end',
          label: '$start–$end',
          expenses: roundMoney(expenses),
          gains: roundMoney(gains),
          net: roundMoney(gains - expenses),
        ),
      );
    }
    return buckets;
  }

  String _monthLabel(String month) {
    const names = [
      'saus.',
      'vas.',
      'kov.',
      'bal.',
      'geg.',
      'birž.',
      'liep.',
      'rugp.',
      'rugs.',
      'spal.',
      'lapkr.',
      'gruod.',
    ];
    final parts = month.split('-');
    final index = int.parse(parts[1]) - 1;
    return '${names[index]} ${parts[0]}';
  }
}
