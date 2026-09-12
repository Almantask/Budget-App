import 'package:flutter_test/flutter_test.dart';

import 'package:budget_app/models/bank.dart';
import 'package:budget_app/models/insight.dart';
import 'package:budget_app/models/period.dart';
import 'package:budget_app/models/person.dart';
import 'package:budget_app/models/spend_tag.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/services/csv_export.dart';
import 'package:budget_app/services/csv_import.dart';
import 'package:budget_app/services/insights_engine.dart';

void main() {
  test('exports UTF-8 BOM CSV with Lithuanian headers', () {
    const household = Household.defaults;
    final csv = const CsvExporter().export(
      household: household,
      txs: [
        MoneyTx(
          id: '1',
          bookedAt: DateTime(2026, 9, 1, 12),
          amount: -12.5,
          currency: 'EUR',
          description: 'Pirkimas, Maxima',
          merchant: 'Maxima',
          bank: BankId.swed,
          personId: Person.meId,
          categoryId: 'groceries',
          tag: SpendTag.essential,
        ),
      ],
    );
    expect(csv.startsWith(CsvExporter.bom), isTrue);
    expect(csv, contains('Data,Bankas,Žmogus,Kategorija,Žyma'));
    expect(csv, contains('Swedbank'));
    expect(csv, contains('"Pirkimas, Maxima"'));
  });

  test('detects Revolut and Swedbank CSV layouts', () {
    final importer = BankCsvImporter();
    const revolut = '''
Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance
Card,Current,2026-09-01 10:00:00,2026-09-01 10:01:00,Netflix,-13.99,0,EUR,COMPLETED,100
''';
    final revolutResult = importer.parse(
      csv: revolut,
      fallbackBank: BankId.swed,
      defaultPersonId: Person.meId,
    );
    expect(revolutResult.bank, BankId.revolut);
    expect(revolutResult.transactions, hasLength(1));
    expect(revolutResult.transactions.first.categoryId, 'subscriptions');
    expect(revolutResult.transactions.first.tag, SpendTag.optional);

    const swed = '''
Data;Gavėjas;Paaiškinimas;Suma;Valiuta
2026-09-02;Maxima;Pirkimas;-21,40;EUR
''';
    final swedResult = importer.parse(
      csv: swed,
      fallbackBank: BankId.artea,
      defaultPersonId: Person.partnerId,
    );
    expect(swedResult.bank, BankId.swed);
    expect(swedResult.transactions.first.amount, closeTo(-21.40, 0.001));
    expect(swedResult.transactions.first.personId, Person.partnerId);
  });

  test('saving tips and biggest value highlight optional spend', () {
    final engine = const InsightsEngine();
    final txs = [
      MoneyTx(
        id: 'n1',
        bookedAt: DateTime(2026, 9, 3),
        amount: -13.99,
        currency: 'EUR',
        description: 'Netflix',
        merchant: 'Netflix',
        bank: BankId.revolut,
        personId: Person.meId,
        categoryId: 'subscriptions',
        tag: SpendTag.optional,
      ),
      MoneyTx(
        id: 'n2',
        bookedAt: DateTime(2026, 8, 3),
        amount: -13.99,
        currency: 'EUR',
        description: 'Netflix',
        merchant: 'Netflix',
        bank: BankId.revolut,
        personId: Person.meId,
        categoryId: 'subscriptions',
        tag: SpendTag.optional,
      ),
      MoneyTx(
        id: 'd1',
        bookedAt: DateTime(2026, 9, 4),
        amount: -80,
        currency: 'EUR',
        description: 'Wolt',
        merchant: 'Wolt',
        bank: BankId.revolut,
        personId: Person.partnerId,
        categoryId: 'dining',
        tag: SpendTag.optional,
      ),
      MoneyTx(
        id: 'g1',
        bookedAt: DateTime(2026, 9, 5),
        amount: -40,
        currency: 'EUR',
        description: 'Maxima',
        merchant: 'Maxima',
        bank: BankId.swed,
        personId: Person.meId,
        categoryId: 'groceries',
        tag: SpendTag.essential,
      ),
    ];
    final current = DateRange(DateTime(2026, 9, 1), DateTime(2026, 10, 1));
    final previous = current.previous;
    final snap = engine.analytics.snapshot(
      txs: txs,
      current: current,
      previous: previous,
    );
    final tips = engine.savingTips(
      txs: txs,
      snapshot: snap,
      period: PeriodKind.month,
    );
    expect(tips, isNotEmpty);
    expect(tips.any((t) => t.title.toLowerCase().contains('netflix')), isTrue);

    final value = engine.biggestValue(txs: txs, current: current);
    expect(value.any((v) => v.kind == ValueKind.opportunity), isTrue);
    expect(value.first.amount, 80);
  });
}
