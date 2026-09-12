import 'package:flutter_test/flutter_test.dart';

import 'package:budget_app/models/period.dart';
import 'package:budget_app/models/person.dart';
import 'package:budget_app/models/spend_tag.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/models/bank.dart';
import 'package:budget_app/models/filters.dart';
import 'package:budget_app/services/analytics.dart';
import 'package:budget_app/services/categorizer.dart';

void main() {
  const analytics = BudgetAnalytics();
  const categorizer = TransactionCategorizer();

  test('week starts on Monday and previous week is the delta window', () {
    final now = DateTime(2026, 9, 12); // Saturday
    final range = const PeriodResolver().resolve(kind: PeriodKind.week, now: now);
    expect(range.start, DateTime(2026, 9, 7));
    expect(range.end, DateTime(2026, 9, 14));
    expect(range.previous.start, DateTime(2026, 8, 31));
    expect(range.previous.end, DateTime(2026, 9, 7));
  });

  test('month and year ranges', () {
    final now = DateTime(2026, 9, 12);
    final month =
        const PeriodResolver().resolve(kind: PeriodKind.month, now: now);
    expect(month.start, DateTime(2026, 9, 1));
    expect(month.end, DateTime(2026, 10, 1));
    final year =
        const PeriodResolver().resolve(kind: PeriodKind.year, now: now);
    expect(year.start, DateTime(2026, 1, 1));
    expect(year.end, DateTime(2027, 1, 1));
  });

  test('filters default to both people', () {
    const filters = BudgetFilters();
    expect(filters.isBoth, isTrue);
    expect(filters.personId, Person.bothId);
  });

  test('person filter hides the other partner', () {
    final txs = [
      _tx(person: Person.meId, amount: -10, merchant: 'Maxima'),
      _tx(person: Person.partnerId, amount: -40, merchant: 'Lidl'),
    ];
    final mine = analytics.applyFilters(
      txs,
      const BudgetFilters(personId: Person.meId),
    );
    expect(mine, hasLength(1));
    expect(mine.first.merchant, 'Maxima');
  });

  test('category and essential/optional tags filter together', () {
    final txs = [
      _tx(
        amount: -10,
        merchant: 'Maxima',
        categoryId: 'groceries',
        tag: SpendTag.essential,
      ),
      _tx(
        amount: -20,
        merchant: 'Wolt',
        categoryId: 'dining',
        tag: SpendTag.optional,
      ),
    ];
    final optionalDining = analytics.applyFilters(
      txs,
      const BudgetFilters(categoryId: 'dining', tag: SpendTag.optional),
    );
    expect(optionalDining, hasLength(1));
    expect(optionalDining.first.merchant, 'Wolt');
  });

  test('snapshot compares expenses with the previous period', () {
    final currentStart = DateTime(2026, 9, 1);
    final txs = [
      _tx(
        amount: -100,
        merchant: 'Maxima',
        bookedAt: DateTime(2026, 9, 5),
        categoryId: 'groceries',
      ),
      _tx(
        amount: 2000,
        merchant: 'Algalapis',
        bookedAt: DateTime(2026, 9, 4),
        categoryId: 'income',
      ),
      _tx(
        amount: -40,
        merchant: 'Lidl',
        bookedAt: DateTime(2026, 8, 10),
        categoryId: 'groceries',
      ),
    ];
    final snap = analytics.snapshot(
      txs: txs,
      current: DateRange(currentStart, DateTime(2026, 10, 1)),
      previous: DateRange(DateTime(2026, 8, 1), currentStart),
    );
    expect(snap.expenses, 100);
    expect(snap.previousExpenses, 40);
    expect(snap.expenseDelta, 60);
    expect(snap.income, 2000);
    expect(snap.essential, 100);
  });

  test('categorizer maps Lithuanian merchants and subscriptions', () {
    expect(
      categorizer
          .categorize(description: '', merchant: 'Maxima XXX', amount: -12)
          .categoryId,
      'groceries',
    );
    expect(
      categorizer
          .categorize(description: 'Netflix', merchant: 'Netflix', amount: -13.99)
          .tag,
      SpendTag.optional,
    );
    expect(
      categorizer
          .categorize(
            description: 'Internal transfer to Revolut',
            merchant: '',
            amount: -250,
          )
          .isTransfer,
      isTrue,
    );
    expect(
      categorizer
          .categorize(
            description: 'Darbo užmokestis',
            merchant: 'UAB',
            amount: 2000,
          )
          .categoryId,
      'income',
    );
  });
}

MoneyTx _tx({
  required double amount,
  required String merchant,
  String person = Person.meId,
  String categoryId = 'groceries',
  SpendTag tag = SpendTag.essential,
  DateTime? bookedAt,
}) {
  return MoneyTx(
    id: '$merchant-$amount',
    bookedAt: bookedAt ?? DateTime(2026, 9, 10),
    amount: amount,
    currency: 'EUR',
    description: merchant,
    merchant: merchant,
    bank: BankId.swed,
    personId: person,
    categoryId: categoryId,
    tag: tag,
    isTransfer: categoryId == 'transfers',
  );
}
