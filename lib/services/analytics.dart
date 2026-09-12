import '../models/category.dart';
import '../models/filters.dart';
import '../models/insight.dart';
import '../models/period.dart';
import '../models/spend_tag.dart';
import '../models/transaction.dart';

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
}
