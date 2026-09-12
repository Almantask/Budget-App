import 'bank.dart';
import 'person.dart';
import 'spend_tag.dart';

class BudgetFilters {
  const BudgetFilters({
    this.personId = Person.bothId,
    this.categoryId,
    this.tag,
    this.bank,
    this.query = '',
  });

  /// `both` by default — household combined view.
  final String personId;
  final String? categoryId;
  final SpendTag? tag;
  final BankId? bank;
  final String query;

  bool get isBoth => personId == Person.bothId || personId.isEmpty;

  BudgetFilters copyWith({
    String? personId,
    String? categoryId,
    SpendTag? tag,
    BankId? bank,
    String? query,
    bool clearCategory = false,
    bool clearTag = false,
    bool clearBank = false,
  }) {
    return BudgetFilters(
      personId: personId ?? this.personId,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      tag: clearTag ? null : (tag ?? this.tag),
      bank: clearBank ? null : (bank ?? this.bank),
      query: query ?? this.query,
    );
  }
}
