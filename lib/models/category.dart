import 'spend_tag.dart';

class BudgetCategory {
  const BudgetCategory({
    required this.id,
    required this.name,
    required this.defaultTag,
    required this.iconName,
    this.excludeFromSpend = false,
  });

  final String id;
  final String name;
  final SpendTag defaultTag;
  final String iconName;
  final bool excludeFromSpend;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'defaultTag': defaultTag.name,
        'iconName': iconName,
        'excludeFromSpend': excludeFromSpend,
      };

  factory BudgetCategory.fromJson(Map<String, dynamic> json) => BudgetCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        defaultTag: SpendTag.parse(json['defaultTag'] as String? ?? 'essential'),
        iconName: json['iconName'] as String? ?? 'category',
        excludeFromSpend: json['excludeFromSpend'] as bool? ?? false,
      );
}

class Categories {
  static const housing = BudgetCategory(
    id: 'housing',
    name: 'Būstas',
    defaultTag: SpendTag.essential,
    iconName: 'home',
  );
  static const utilities = BudgetCategory(
    id: 'utilities',
    name: 'Komunalinės',
    defaultTag: SpendTag.essential,
    iconName: 'bolt',
  );
  static const groceries = BudgetCategory(
    id: 'groceries',
    name: 'Maistas',
    defaultTag: SpendTag.essential,
    iconName: 'shopping_cart',
  );
  static const dining = BudgetCategory(
    id: 'dining',
    name: 'Restoranai',
    defaultTag: SpendTag.optional,
    iconName: 'restaurant',
  );
  static const transport = BudgetCategory(
    id: 'transport',
    name: 'Transportas',
    defaultTag: SpendTag.essential,
    iconName: 'directions_car',
  );
  static const health = BudgetCategory(
    id: 'health',
    name: 'Sveikata',
    defaultTag: SpendTag.essential,
    iconName: 'favorite',
  );
  static const family = BudgetCategory(
    id: 'family',
    name: 'Šeima',
    defaultTag: SpendTag.essential,
    iconName: 'family_restroom',
  );
  static const clothes = BudgetCategory(
    id: 'clothes',
    name: 'Drabužiai',
    defaultTag: SpendTag.optional,
    iconName: 'checkroom',
  );
  static const leisure = BudgetCategory(
    id: 'leisure',
    name: 'Pramogos',
    defaultTag: SpendTag.optional,
    iconName: 'sports_esports',
  );
  static const subscriptions = BudgetCategory(
    id: 'subscriptions',
    name: 'Prenumeratos',
    defaultTag: SpendTag.optional,
    iconName: 'subscriptions',
  );
  static const travel = BudgetCategory(
    id: 'travel',
    name: 'Kelionės',
    defaultTag: SpendTag.optional,
    iconName: 'flight',
  );
  static const income = BudgetCategory(
    id: 'income',
    name: 'Pajamos',
    defaultTag: SpendTag.essential,
    iconName: 'payments',
    excludeFromSpend: true,
  );
  static const transfers = BudgetCategory(
    id: 'transfers',
    name: 'Perkėlimai',
    defaultTag: SpendTag.essential,
    iconName: 'swap_horiz',
    excludeFromSpend: true,
  );
  static const other = BudgetCategory(
    id: 'other',
    name: 'Kita',
    defaultTag: SpendTag.optional,
    iconName: 'more_horiz',
  );

  static const all = <BudgetCategory>[
    housing,
    utilities,
    groceries,
    dining,
    transport,
    health,
    family,
    clothes,
    leisure,
    subscriptions,
    travel,
    income,
    transfers,
    other,
  ];

  static const spendable = <BudgetCategory>[
    housing,
    utilities,
    groceries,
    dining,
    transport,
    health,
    family,
    clothes,
    leisure,
    subscriptions,
    travel,
    other,
  ];

  static BudgetCategory byId(String id) {
    return all.firstWhere((c) => c.id == id, orElse: () => other);
  }
}
