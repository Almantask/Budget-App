import '../models/bank.dart';
import '../models/connected_account.dart';
import '../models/transaction.dart';
import 'bank_connector.dart';
import 'demo_connector.dart';
import 'gocardless_client.dart';

class BankSyncService {
  BankSyncService({
    GoCardlessClient? gocardless,
    WiseApiClient? wise,
  })  : _gocardless = gocardless ?? GoCardlessClient(),
        _wise = wise ?? WiseApiClient();

  final GoCardlessClient _gocardless;
  final WiseApiClient _wise;

  BankConnector demoConnector(BankId bank) => DemoBankConnector(bank: bank);

  Future<BankAuthSession> startOpenBankingLink({
    required BankCredentials credentials,
    required BankId bank,
    required String redirectUri,
    required String personId,
  }) async {
    if (!credentials.hasGoCardless) {
      return demoConnector(bank).startLink(
        redirectUri: redirectUri,
        personId: personId,
      );
    }
    final token = await _gocardless.createAccessToken(
      secretId: credentials.gocardlessSecretId!,
      secretKey: credentials.gocardlessSecretKey!,
    );
    final institution = await _gocardless.lookupInstitutionId(
      accessToken: token,
      bank: bank,
    );
    return _gocardless.createRequisition(
      accessToken: token,
      bank: bank,
      redirectUri: redirectUri,
      institutionId: institution,
    );
  }

  Future<List<MoneyTx>> pullAccount({
    required BankCredentials credentials,
    required ConnectedAccount account,
    DateTime? from,
  }) async {
    if (account.status == AccountLinkStatus.demo ||
        !credentials.hasGoCardless) {
      final result = await demoConnector(account.bank).pullTransactions(
        accountRef: account.id,
        personId: account.personId,
        from: from,
      );
      return result.transactions;
    }

    if (account.bank == BankId.wise && credentials.hasWise) {
      final result = await _wise.pull(
        token: credentials.wiseApiToken!,
        personId: account.personId,
        from: from,
      );
      return result.transactions;
    }

    final token = await _gocardless.createAccessToken(
      secretId: credentials.gocardlessSecretId!,
      secretKey: credentials.gocardlessSecretKey!,
    );
    final accountId = account.gocardlessAccountId;
    if (accountId == null || accountId.isEmpty) {
      final requisition = account.gocardlessRequisitionId;
      if (requisition == null) return const [];
      final ids = await _gocardless.listAccountIds(
        accessToken: token,
        requisitionId: requisition,
      );
      if (ids.isEmpty) return const [];
      return _gocardless
          .fetchTransactions(
            accessToken: token,
            accountId: ids.first,
            bank: account.bank,
            personId: account.personId,
            from: from,
          )
          .then((r) => r.transactions);
    }
    final result = await _gocardless.fetchTransactions(
      accessToken: token,
      accountId: accountId,
      bank: account.bank,
      personId: account.personId,
      from: from,
    );
    return result.transactions;
  }
}

class Deduper {
  const Deduper();

  List<MoneyTx> merge(List<MoneyTx> existing, List<MoneyTx> incoming) {
    final keys = existing.map(_key).toSet();
    final merged = [...existing];
    for (final tx in incoming) {
      final key = _key(tx);
      if (keys.add(key)) {
        merged.add(tx);
      }
    }
    return merged;
  }

  String _key(MoneyTx tx) {
    if (tx.externalId != null && tx.externalId!.isNotEmpty) {
      return '${tx.bank.name}:${tx.externalId}';
    }
    return '${tx.bank.name}|${tx.bookedAt.toIso8601String()}|${tx.amount}|${tx.description}|${tx.merchant}';
  }
}
