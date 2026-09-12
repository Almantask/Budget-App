import 'bank.dart';
import 'spend_tag.dart';

class MoneyTx {
  const MoneyTx({
    required this.id,
    required this.bookedAt,
    required this.amount,
    required this.currency,
    required this.description,
    required this.merchant,
    required this.bank,
    required this.personId,
    required this.categoryId,
    required this.tag,
    this.isTransfer = false,
    this.accountIban,
    this.externalId,
  });

  final String id;
  final DateTime bookedAt;
  final double amount;
  final String currency;
  final String description;
  final String merchant;
  final BankId bank;
  final String personId;
  final String categoryId;
  final SpendTag tag;
  final bool isTransfer;
  final String? accountIban;
  final String? externalId;

  bool get isIncome => amount > 0 && !isTransfer;
  bool get isExpense => amount < 0 && !isTransfer;
  double get absAmount => amount.abs();

  MoneyTx copyWith({
    DateTime? bookedAt,
    double? amount,
    String? currency,
    String? description,
    String? merchant,
    BankId? bank,
    String? personId,
    String? categoryId,
    SpendTag? tag,
    bool? isTransfer,
    String? accountIban,
    String? externalId,
  }) {
    return MoneyTx(
      id: id,
      bookedAt: bookedAt ?? this.bookedAt,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      merchant: merchant ?? this.merchant,
      bank: bank ?? this.bank,
      personId: personId ?? this.personId,
      categoryId: categoryId ?? this.categoryId,
      tag: tag ?? this.tag,
      isTransfer: isTransfer ?? this.isTransfer,
      accountIban: accountIban ?? this.accountIban,
      externalId: externalId ?? this.externalId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookedAt': bookedAt.toIso8601String(),
        'amount': amount,
        'currency': currency,
        'description': description,
        'merchant': merchant,
        'bank': bank.name,
        'personId': personId,
        'categoryId': categoryId,
        'tag': tag.name,
        'isTransfer': isTransfer,
        'accountIban': accountIban,
        'externalId': externalId,
      };

  factory MoneyTx.fromJson(Map<String, dynamic> json) => MoneyTx(
        id: json['id'] as String,
        bookedAt: DateTime.parse(json['bookedAt'] as String),
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'EUR',
        description: json['description'] as String? ?? '',
        merchant: json['merchant'] as String? ?? '',
        bank: BankId.tryParse(json['bank'] as String? ?? '') ?? BankId.swed,
        personId: json['personId'] as String,
        categoryId: json['categoryId'] as String,
        tag: SpendTag.parse(json['tag'] as String? ?? 'essential'),
        isTransfer: json['isTransfer'] as bool? ?? false,
        accountIban: json['accountIban'] as String?,
        externalId: json['externalId'] as String?,
      );
}
