enum AlertLevel { ok, pace, warning, breach }

enum AnomalyKind { monthSpike, categorySpike, largeCharge }

enum AnomalySeverity { watch, unusual }

class ThresholdAlert {
  const ThresholdAlert({
    required this.budgetId,
    required this.categoryId,
    required this.label,
    required this.spent,
    required this.limit,
    required this.warnAt,
    required this.ratio,
    required this.projected,
    required this.level,
    required this.message,
  });

  final String budgetId;
  final String categoryId;
  final String label;
  final double spent;
  final double limit;
  final double warnAt;
  final double ratio;
  final double projected;
  final AlertLevel level;
  final String message;
}

class ThresholdNotice {
  const ThresholdNotice({
    required this.id,
    required this.at,
    required this.month,
    required this.budgetId,
    required this.categoryId,
    required this.label,
    required this.level,
    required this.message,
    this.read = false,
  });

  final String id;
  final DateTime at;
  final String month;
  final String budgetId;
  final String categoryId;
  final String label;
  final AlertLevel level;
  final String message;
  final bool read;

  ThresholdNotice copyWith({bool? read}) => ThresholdNotice(
        id: id,
        at: at,
        month: month,
        budgetId: budgetId,
        categoryId: categoryId,
        label: label,
        level: level,
        message: message,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'month': month,
        'budgetId': budgetId,
        'categoryId': categoryId,
        'label': label,
        'level': level.name,
        'message': message,
        'read': read,
      };

  factory ThresholdNotice.fromJson(Map<String, dynamic> json) =>
      ThresholdNotice(
        id: json['id'] as String,
        at: DateTime.parse(json['at'] as String),
        month: json['month'] as String,
        budgetId: json['budgetId'] as String,
        categoryId: json['categoryId'] as String,
        label: json['label'] as String,
        level: AlertLevel.values.byName(json['level'] as String),
        message: json['message'] as String,
        read: json['read'] as bool? ?? false,
      );
}

class SpendingAnomaly {
  const SpendingAnomaly({
    required this.id,
    required this.kind,
    required this.severity,
    required this.categoryId,
    required this.label,
    required this.month,
    required this.amount,
    required this.baseline,
    required this.multiple,
    required this.message,
    this.transactionId,
  });

  final String id;
  final AnomalyKind kind;
  final AnomalySeverity severity;
  final String categoryId;
  final String label;
  final String month;
  final double amount;
  final double baseline;
  final double multiple;
  final String message;
  final String? transactionId;
}

class MonthPoint {
  const MonthPoint({
    required this.month,
    required this.label,
    required this.expenses,
    required this.gains,
    required this.net,
  });

  final String month;
  final String label;
  final double expenses;
  final double gains;
  final double net;
}

class WeekPoint {
  const WeekPoint({
    required this.key,
    required this.label,
    required this.expenses,
    required this.gains,
    required this.net,
  });

  final String key;
  final String label;
  final double expenses;
  final double gains;
  final double net;
}
