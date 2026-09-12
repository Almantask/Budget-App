import '../models/budget_limit.dart';
import '../models/category.dart';
import '../models/notice.dart';
import '../models/transaction.dart';
import '../ui/theme.dart';
import 'dates.dart';

class BudgetEvaluation {
  const BudgetEvaluation({
    required this.spent,
    required this.limit,
    required this.warnAt,
    required this.ratio,
    required this.projected,
    required this.level,
  });

  final double spent;
  final double limit;
  final double warnAt;
  final double ratio;
  final double projected;
  final AlertLevel level;
}

class EvaluatedBudget {
  const EvaluatedBudget({
    required this.evaluation,
    required this.label,
  });

  final BudgetEvaluation evaluation;
  final String label;
}

class ExpenseActivity {
  const ExpenseActivity({required this.spent, required this.count});
  final double spent;
  final int count;
}

class ThresholdEngine {
  const ThresholdEngine();

  BudgetEvaluation evaluateBudget({
    required double spent,
    required double limit,
    required double warnAt,
    required int day,
    required int daysInMonth,
    int transactionCount = 3,
    double? recentSpent,
    int? recentDays,
  }) {
    final ratio = limit <= 0 ? 0.0 : spent / limit;
    final recentDayCount = (recentDays ?? day).clamp(1, 366);
    final recent = recentSpent ?? spent;
    final remainingDays = (daysInMonth - day).clamp(0, 31);
    final projected = spent + (recent / recentDayCount) * remainingDays;
    final count = transactionCount;

    var level = AlertLevel.ok;
    if (ratio >= 1) {
      level = AlertLevel.breach;
    } else if (ratio >= warnAt) {
      level = AlertLevel.warning;
    } else if (_shouldFlagPace(
      day: day,
      projected: projected,
      limit: limit,
      ratio: ratio,
      count: count,
      recentSpent: recent,
    )) {
      level = AlertLevel.pace;
    }

    return BudgetEvaluation(
      spent: spent,
      limit: limit,
      warnAt: warnAt,
      ratio: ratio,
      projected: projected,
      level: level,
    );
  }

  bool _shouldFlagPace({
    required int day,
    required double projected,
    required double limit,
    required double ratio,
    required int count,
    required double recentSpent,
  }) {
    if (day < 8 || count < 2 || recentSpent <= 0) return false;
    if (ratio < 0.4) return false;
    return projected > limit * 1.1;
  }

  String budgetLabel(BudgetLimit budget) {
    if (budget.isOverall) return 'Visos išlaidos';
    return Categories.byId(budget.categoryId).name;
  }

  double spentInMonth(
    List<MoneyTx> txs,
    String month, {
    String? categoryId,
  }) {
    var total = 0.0;
    for (final tx in txs) {
      if (!tx.isExpense) continue;
      if (monthKey(tx.bookedAt) != month) continue;
      if (categoryId != null && tx.categoryId != categoryId) continue;
      total += tx.absAmount;
    }
    return roundMoney(total);
  }

  ExpenseActivity expenseActivity({
    required List<MoneyTx> txs,
    required String month,
    String? categoryId,
    required String startDate,
    required String endDate,
  }) {
    var recent = 0.0;
    var count = 0;
    for (final tx in txs) {
      if (!tx.isExpense) continue;
      if (monthKey(tx.bookedAt) != month) continue;
      if (categoryId != null && tx.categoryId != categoryId) continue;
      count += 1;
      final key = dateKey(tx.bookedAt);
      if (key.compareTo(startDate) >= 0 && key.compareTo(endDate) <= 0) {
        recent += tx.absAmount;
      }
    }
    return ExpenseActivity(spent: roundMoney(recent), count: count);
  }

  EvaluatedBudget evaluateBudgetRecord({
    required List<MoneyTx> txs,
    required BudgetLimit budget,
    required String month,
    required DateTime today,
  }) {
    final todayKey = dateKey(today);
    final inCurrentMonth = monthKey(today) == month;
    final day = inCurrentMonth ? today.day : daysInMonth(month);
    final inThisMonth = daysInMonth(month);
    final endDate = inCurrentMonth
        ? todayKey
        : '$month-${inThisMonth.toString().padLeft(2, '0')}';
    final recentStart = addDays(endDate, -6);
    final monthStart = startOfMonth(month);
    final windowStart =
        recentStart.compareTo(monthStart) < 0 ? monthStart : recentStart;
    final categoryId = budget.isOverall ? null : budget.categoryId;
    final spent = spentInMonth(txs, month, categoryId: categoryId);
    final activity = expenseActivity(
      txs: txs,
      month: month,
      categoryId: categoryId,
      startDate: windowStart,
      endDate: endDate,
    );
    return EvaluatedBudget(
      label: budgetLabel(budget),
      evaluation: evaluateBudget(
        spent: spent,
        limit: budget.monthlyLimit,
        warnAt: budget.warnAt,
        day: day,
        daysInMonth: inThisMonth,
        transactionCount: activity.count,
        recentSpent: activity.spent,
        recentDays: day < 7 ? day : 7,
      ),
    );
  }

  List<ThresholdAlert> collectAlerts({
    required List<MoneyTx> txs,
    required List<BudgetLimit> budgets,
    required String month,
    required DateTime today,
  }) {
    final alerts = <ThresholdAlert>[];
    for (final budget in budgets) {
      if (budget.monthlyLimit <= 0) continue;
      final record = evaluateBudgetRecord(
        txs: txs,
        budget: budget,
        month: month,
        today: today,
      );
      if (record.evaluation.level == AlertLevel.ok) continue;
      alerts.add(
        ThresholdAlert(
          budgetId: budget.id,
          categoryId: budget.categoryId,
          label: record.label,
          spent: record.evaluation.spent,
          limit: record.evaluation.limit,
          warnAt: record.evaluation.warnAt,
          ratio: record.evaluation.ratio,
          projected: record.evaluation.projected,
          level: record.evaluation.level,
          message: alertMessage(record.label, record.evaluation),
        ),
      );
    }
    alerts.sort((a, b) {
      final rank = _rank(b.level) - _rank(a.level);
      if (rank != 0) return rank;
      return b.ratio.compareTo(a.ratio);
    });
    return alerts;
  }

  String alertMessage(String label, BudgetEvaluation evaluation) {
    final warnPct = '${(evaluation.warnAt * 100).round()}%';
    if (evaluation.level == AlertLevel.breach) {
      final over = evaluation.spent - evaluation.limit;
      return '$label viršijo biudžetą ${formatEur(over)} (${_pct(evaluation.ratio)} iš ${formatEur(evaluation.limit)}).';
    }
    if (evaluation.level == AlertLevel.warning) {
      return '$label pasiekė $warnPct įspėjimo ribą — išleista ${formatEur(evaluation.spent)} iš ${formatEur(evaluation.limit)}.';
    }
    final overshoot = evaluation.projected - evaluation.limit;
    return 'Tokiu tempu $label viršys biudžetą ${formatEur(overshoot)} šį mėnesį.';
  }

  String _pct(double ratio) => '${(ratio * 100).round()}%';

  int _rank(AlertLevel level) {
    return switch (level) {
      AlertLevel.breach => 3,
      AlertLevel.warning => 2,
      AlertLevel.pace => 1,
      AlertLevel.ok => 0,
    };
  }
}
