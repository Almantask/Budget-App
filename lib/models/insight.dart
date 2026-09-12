class SavingTip {
  const SavingTip({
    required this.title,
    required this.detail,
    required this.monthlySaving,
    required this.priority,
  });

  final String title;
  final String detail;
  final double monthlySaving;
  final int priority;
}

class BiggestValueItem {
  const BiggestValueItem({
    required this.title,
    required this.detail,
    required this.amount,
    required this.kind,
  });

  final String title;
  final String detail;
  final double amount;
  final ValueKind kind;
}

enum ValueKind { expense, opportunity, recurring }

class CategorySpend {
  const CategorySpend({
    required this.categoryId,
    required this.amount,
    required this.previousAmount,
    required this.essential,
    required this.optional,
  });

  final String categoryId;
  final double amount;
  final double previousAmount;
  final double essential;
  final double optional;

  double get delta => amount - previousAmount;
  double? get deltaPct =>
      previousAmount == 0 ? null : delta / previousAmount;
}

class PeriodSnapshot {
  const PeriodSnapshot({
    required this.income,
    required this.expenses,
    required this.essential,
    required this.optional,
    required this.previousIncome,
    required this.previousExpenses,
    required this.byCategory,
    required this.transactionCount,
  });

  final double income;
  final double expenses;
  final double essential;
  final double optional;
  final double previousIncome;
  final double previousExpenses;
  final List<CategorySpend> byCategory;
  final int transactionCount;

  double get net => income - expenses;
  double get expenseDelta => expenses - previousExpenses;
  double? get expenseDeltaPct =>
      previousExpenses == 0 ? null : expenseDelta / previousExpenses;
  double get incomeDelta => income - previousIncome;
  double get optionalShare => expenses == 0 ? 0 : optional / expenses;
}
