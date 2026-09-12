import '../models/bank.dart';
import '../models/connected_account.dart';
import '../models/transaction.dart';
import 'bank_connector.dart';
import 'demo_connector.dart';
import 'enable_banking_client.dart';
import 'wise_client.dart';

class BankSyncService {
  BankSyncService({
    EnableBankingClient? enableBanking,
    WiseApiClient? wise,
  })  : _enableBanking = enableBanking ?? EnableBankingClient(),
        _wise = wise ?? WiseApiClient();

  final EnableBankingClient _enableBanking;
  final WiseApiClient _wise;

  BankConnector demoConnector(BankId bank) => DemoBankConnector(bank: bank);

  Future<BankAuthSession> startOpenBankingLink({
    required BankCredentials credentials,
    required BankId bank,
    required String redirectUri,
    required String personId,
  }) async {
    if (!credentials.hasEnableBanking) {
      return demoConnector(bank).startLink(
        redirectUri: redirectUri,
        personId: personId,
      );
    }
    return _enableBanking.startAuthorization(
      credentials: credentials,
      bank: bank,
      redirectUri: redirectUri,
    );
  }

  Future<EnableBankingLinkedSession> completeOpenBankingLink({
    required BankCredentials credentials,
    required String callbackOrCode,
  }) async {
    if (!credentials.hasEnableBanking) {
      throw BankSyncException(
        'Įveskite Enable Banking application ID ir RSA raktą Nustatymuose.',
      );
    }
    final code = EnableBankingClient.extractAuthorizationCode(callbackOrCode);
    return _enableBanking.authorizeSession(
      credentials: credentials,
      code: code,
    );
  }

  Future<List<MoneyTx>> pullAccount({
    required BankCredentials credentials,
    required ConnectedAccount account,
    DateTime? from,
  }) async {
    if (account.status == AccountLinkStatus.demo ||
        !credentials.hasEnableBanking) {
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

    final accountIds = await _accountIdsFor(credentials, account);
    if (accountIds.isEmpty) return const [];
    final txs = <MoneyTx>[];
    for (final accountId in accountIds) {
      final result = await _enableBanking.fetchTransactions(
        credentials: credentials,
        accountId: accountId,
        bank: account.bank,
        personId: account.personId,
        from: from,
      );
      txs.addAll(result.transactions);
    }
    return txs;
  }

  Future<List<String>> _accountIdsFor(
    BankCredentials credentials,
    ConnectedAccount account,
  ) async {
    final sessionId = account.enableBankingSessionId;
    if (sessionId != null && sessionId.isNotEmpty) {
      final ids = await _enableBanking.listAccountIds(
        credentials: credentials,
        sessionId: sessionId,
      );
      if (ids.isNotEmpty) return ids;
    }
    final stored = account.enableBankingAccountId;
    if (stored != null && stored.isNotEmpty) return [stored];
    return const [];
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
