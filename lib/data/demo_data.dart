import '../models/bank.dart';
import '../models/connected_account.dart';
import '../models/person.dart';
import '../models/transaction.dart';
import '../services/categorizer.dart';

class DemoHouseholdFactory {
  const DemoHouseholdFactory({
    this.categorizer = const TransactionCategorizer(),
  });

  final TransactionCategorizer categorizer;

  DemoHousehold build(DateTime now) {
    final txs = <MoneyTx>[];
    var seq = 0;
    String nextId() => 'demo-${seq++}';

    void add({
      required DateTime date,
      required double amount,
      required String merchant,
      required BankId bank,
      required String personId,
      String? description,
    }) {
      final cat = categorizer.categorize(
        description: description ?? merchant,
        merchant: merchant,
        amount: amount,
      );
      txs.add(
        MoneyTx(
          id: nextId(),
          bookedAt: date,
          amount: amount,
          currency: 'EUR',
          description: description ?? merchant,
          merchant: merchant,
          bank: bank,
          personId: personId,
          categoryId: cat.categoryId,
          tag: cat.tag,
          isTransfer: cat.isTransfer,
          externalId: 'seed-$seq',
        ),
      );
    }

    final start = DateTime(now.year, now.month - 13, 1);
    for (var cursor = DateTime(start.year, start.month, 1);
        !cursor.isAfter(DateTime(now.year, now.month, 1));
        cursor = DateTime(cursor.year, cursor.month + 1, 1)) {
      final inCurrentMonth =
          cursor.year == now.year && cursor.month == now.month;
      final lastDay = inCurrentMonth
          ? now.day.clamp(8, 28)
          : DateTime(cursor.year, cursor.month + 1, 0).day;

      add(
        date: DateTime(cursor.year, cursor.month, 4, 9),
        amount: 2480,
        merchant: 'UAB Darbdavys',
        bank: BankId.swed,
        personId: Person.meId,
        description: 'Darbo užmokestis',
      );
      add(
        date: DateTime(cursor.year, cursor.month, 5, 9),
        amount: 2120,
        merchant: 'UAB Studio',
        bank: BankId.artea,
        personId: Person.partnerId,
        description: 'Algalapis',
      );
      add(
        date: DateTime(cursor.year, cursor.month, 2, 8),
        amount: -720,
        merchant: 'Nuoma Vilnius',
        bank: BankId.swed,
        personId: Person.meId,
      );
      add(
        date: DateTime(cursor.year, cursor.month, 12, 10),
        amount: -78 + (cursor.month % 3) * -4,
        merchant: 'Ignitis',
        bank: BankId.swed,
        personId: Person.meId,
      );
      add(
        date: DateTime(cursor.year, cursor.month, 14, 10),
        amount: -21.5,
        merchant: 'Vilniaus vandenys',
        bank: BankId.swed,
        personId: Person.partnerId,
      );
      add(
        date: DateTime(cursor.year, cursor.month, 7, 11),
        amount: -28.5,
        merchant: 'Telia',
        bank: BankId.artea,
        personId: Person.partnerId,
      );
      add(
        date: DateTime(cursor.year, cursor.month, 8, 12),
        amount: -13.99,
        merchant: 'Netflix',
        bank: BankId.revolut,
        personId: Person.meId,
      );
      add(
        date: DateTime(cursor.year, cursor.month, 8, 12, 5),
        amount: -10.99,
        merchant: 'Spotify',
        bank: BankId.revolut,
        personId: Person.partnerId,
      );
      add(
        date: DateTime(cursor.year, cursor.month, 9, 12),
        amount: -9.99,
        merchant: 'Disney+',
        bank: BankId.revolut,
        personId: Person.meId,
      );

      final groceryDays = [3, 6, 11, 17, 22, 26];
      for (final d in groceryDays) {
        if (d > lastDay) continue;
        add(
          date: DateTime(cursor.year, cursor.month, d, 18),
          amount: -(32 + (d + cursor.month) % 18).toDouble(),
          merchant: d.isEven ? 'Maxima' : 'Lidl',
          bank: d.isEven ? BankId.swed : BankId.artea,
          personId: d % 3 == 0 ? Person.partnerId : Person.meId,
        );
      }

      add(
        date: DateTime(cursor.year, cursor.month, lastDay >= 15 ? 15 : lastDay, 19),
        amount: -(18 + cursor.month % 10).toDouble(),
        merchant: 'IKI',
        bank: BankId.artea,
        personId: Person.partnerId,
      );
      if (lastDay >= 10) {
        add(
          date: DateTime(cursor.year, cursor.month, 10, 20),
          amount: -42.5,
          merchant: 'Can Can Pizza',
          bank: BankId.revolut,
          personId: Person.meId,
        );
      }
      if (lastDay >= 19) {
        add(
          date: DateTime(cursor.year, cursor.month, 19, 21),
          amount: -36.8,
          merchant: 'Wolt',
          bank: BankId.revolut,
          personId: Person.partnerId,
        );
      }
      if (lastDay >= 13) {
        add(
          date: DateTime(cursor.year, cursor.month, 13, 8),
          amount: -68,
          merchant: 'Circle K',
          bank: BankId.swed,
          personId: Person.meId,
        );
      }
      if (lastDay >= 16) {
        add(
          date: DateTime(cursor.year, cursor.month, 16, 8),
          amount: -14.2,
          merchant: 'Bolt',
          bank: BankId.revolut,
          personId: Person.partnerId,
        );
      }
      if (lastDay >= 21) {
        add(
          date: DateTime(cursor.year, cursor.month, 21, 17),
          amount: -18.6,
          merchant: 'Eurovaistinė',
          bank: BankId.artea,
          personId: Person.partnerId,
        );
      }
      if (cursor.month % 3 == 0 && lastDay >= 18) {
        add(
          date: DateTime(cursor.year, cursor.month, 18, 15),
          amount: -79,
          merchant: 'Zara',
          bank: BankId.revolut,
          personId: Person.partnerId,
        );
      }
      if (cursor.month % 4 == 0 && lastDay >= 23) {
        add(
          date: DateTime(cursor.year, cursor.month, 23, 16),
          amount: -54,
          merchant: 'Forum Cinemas',
          bank: BankId.swed,
          personId: Person.meId,
        );
      }
      if (cursor.month == 7 || cursor.month == 8) {
        if (lastDay >= 20) {
          add(
            date: DateTime(cursor.year, cursor.month, 20, 12),
            amount: -186,
            merchant: 'Ryanair',
            bank: BankId.wise,
            personId: Person.meId,
          );
        }
      }
      add(
        date: DateTime(cursor.year, cursor.month, 6, 11),
        amount: -250,
        merchant: 'Perkėlimas į Revolut',
        bank: BankId.swed,
        personId: Person.meId,
        description: 'Internal transfer to Revolut',
      );
      add(
        date: DateTime(cursor.year, cursor.month, 6, 11, 2),
        amount: 250,
        merchant: 'Iš Swedbank',
        bank: BankId.revolut,
        personId: Person.meId,
        description: 'From Swedbank own account',
      );
    }

    final accounts = [
      ConnectedAccount(
        id: 'acc-swed',
        bank: BankId.swed,
        personId: Person.meId,
        displayName: 'Swedbank LT · šeimos',
        iban: 'LT12 7300 0100 0000 0001',
        status: AccountLinkStatus.demo,
        lastSyncedAt: now,
      ),
      ConnectedAccount(
        id: 'acc-artea',
        bank: BankId.artea,
        personId: Person.partnerId,
        displayName: 'Artea · žmonos',
        iban: 'LT24 7180 0000 0000 0002',
        status: AccountLinkStatus.demo,
        lastSyncedAt: now,
      ),
      ConnectedAccount(
        id: 'acc-revolut',
        bank: BankId.revolut,
        personId: Person.meId,
        displayName: 'Revolut EUR',
        status: AccountLinkStatus.demo,
        lastSyncedAt: now,
      ),
      ConnectedAccount(
        id: 'acc-wise',
        bank: BankId.wise,
        personId: Person.meId,
        displayName: 'Wise · kelionėms',
        status: AccountLinkStatus.demo,
        lastSyncedAt: now,
      ),
    ];

    return DemoHousehold(transactions: txs, accounts: accounts);
  }
}

class DemoHousehold {
  const DemoHousehold({required this.transactions, required this.accounts});

  final List<MoneyTx> transactions;
  final List<ConnectedAccount> accounts;
}
