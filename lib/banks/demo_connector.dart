import '../models/bank.dart';
import '../models/person.dart';
import '../models/transaction.dart';
import '../services/categorizer.dart';
import 'bank_connector.dart';

/// Local/demo connector so the household can use the app before Open Banking
/// credentials are entered. Simulates a once-per-day pull.
class DemoBankConnector implements BankConnector {
  DemoBankConnector({
    required this.bank,
    this._categorizer = const TransactionCategorizer(),
  });

  @override
  final BankId bank;
  final TransactionCategorizer _categorizer;

  @override
  Future<BankAuthSession> startLink({
    required String redirectUri,
    required String personId,
  }) async {
    return BankAuthSession(
      sessionId: 'demo-${bank.name}',
      authorizationUrl: 'demo://linked',
    );
  }

  @override
  Future<BankSyncResult> completeLink({
    required String sessionId,
    required String personId,
  }) async {
    return BankSyncResult(
      bank: bank,
      transactions: const [],
      message: 'Demo režimas: ${bank.label} pažymėtas kaip susietas.',
    );
  }

  @override
  Future<BankSyncResult> pullTransactions({
    required String accountRef,
    required String personId,
    DateTime? from,
  }) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    if (from != null && !from.isBefore(day)) {
      return BankSyncResult(
        bank: bank,
        transactions: const [],
        message: '${bank.label}: naujų operacijų nėra.',
      );
    }
    final sample = _todaySample(day, personId);
    return BankSyncResult(
      bank: bank,
      transactions: sample,
      message: '${bank.label}: gautos ${sample.length} naujos operacijos.',
    );
  }

  List<MoneyTx> _todaySample(DateTime day, String personId) {
    final specs = switch (bank) {
      BankId.artea => [
          ('IKI Savanorių', -18.4, Person.partnerId),
          ('Camelia vaistinė', -9.2, Person.partnerId),
        ],
      BankId.revolut => [
          ('Bolt', -6.5, Person.meId),
          ('Starbucks', -4.8, Person.meId),
        ],
      BankId.swed => [
          ('Maxima X', -27.9, Person.meId),
          ('Circle K', -48.0, Person.meId),
        ],
      BankId.wise => [
          ('Wise fee', -1.2, Person.bothId == personId ? Person.meId : personId),
        ],
    };

    return [
      for (var i = 0; i < specs.length; i++)
        _tx(
          bookedAt: day.add(Duration(hours: 10 + i)),
          merchant: specs[i].$1,
          amount: specs[i].$2,
          personId: specs[i].$3,
        ),
    ];
  }

  MoneyTx _tx({
    required DateTime bookedAt,
    required String merchant,
    required double amount,
    required String personId,
  }) {
    final cat = _categorizer.categorize(
      description: merchant,
      merchant: merchant,
      amount: amount,
    );
    return MoneyTx(
      id: 'demo-${bank.name}-${bookedAt.toIso8601String()}-$merchant',
      bookedAt: bookedAt,
      amount: amount,
      currency: 'EUR',
      description: merchant,
      merchant: merchant,
      bank: bank,
      personId: personId,
      categoryId: cat.categoryId,
      tag: cat.tag,
      isTransfer: cat.isTransfer,
      externalId:
          'demo-${bank.name}-${bookedAt.millisecondsSinceEpoch}-$merchant',
    );
  }
}
