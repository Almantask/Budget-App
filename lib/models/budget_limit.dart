class BudgetLimit {
  const BudgetLimit({
    required this.id,
    required this.categoryId,
    required this.monthlyLimit,
    required this.warnAt,
  });

  final String id;
  final String categoryId;
  final double monthlyLimit;
  final double warnAt;

  bool get isOverall => categoryId == 'overall';

  BudgetLimit copyWith({
    double? monthlyLimit,
    double? warnAt,
  }) {
    return BudgetLimit(
      id: id,
      categoryId: categoryId,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      warnAt: warnAt ?? this.warnAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'monthlyLimit': monthlyLimit,
        'warnAt': warnAt,
      };

  factory BudgetLimit.fromJson(Map<String, dynamic> json) => BudgetLimit(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String,
        monthlyLimit: (json['monthlyLimit'] as num).toDouble(),
        warnAt: (json['warnAt'] as num).toDouble(),
      );

  /// Grove defaults, mapped onto this app's Lithuanian categories.
  static const defaults = <BudgetLimit>[
    BudgetLimit(
      id: 'b-overall',
      categoryId: 'overall',
      monthlyLimit: 1600,
      warnAt: 0.8,
    ),
    BudgetLimit(
      id: 'b-housing',
      categoryId: 'housing',
      monthlyLimit: 750,
      warnAt: 1,
    ),
    BudgetLimit(
      id: 'b-groceries',
      categoryId: 'groceries',
      monthlyLimit: 340,
      warnAt: 0.8,
    ),
    BudgetLimit(
      id: 'b-dining',
      categoryId: 'dining',
      monthlyLimit: 160,
      warnAt: 0.75,
    ),
    BudgetLimit(
      id: 'b-transport',
      categoryId: 'transport',
      monthlyLimit: 120,
      warnAt: 0.8,
    ),
    BudgetLimit(
      id: 'b-utilities',
      categoryId: 'utilities',
      monthlyLimit: 140,
      warnAt: 1,
    ),
    BudgetLimit(
      id: 'b-health',
      categoryId: 'health',
      monthlyLimit: 80,
      warnAt: 0.8,
    ),
    BudgetLimit(
      id: 'b-leisure',
      categoryId: 'leisure',
      monthlyLimit: 140,
      warnAt: 0.7,
    ),
    BudgetLimit(
      id: 'b-clothes',
      categoryId: 'clothes',
      monthlyLimit: 120,
      warnAt: 0.7,
    ),
  ];
}
