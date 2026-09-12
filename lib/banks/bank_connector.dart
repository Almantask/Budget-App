import '../models/bank.dart';
import '../models/transaction.dart';

class BankSyncResult {
  const BankSyncResult({
    required this.bank,
    required this.transactions,
    this.accountIban,
    this.message,
  });

  final BankId bank;
  final List<MoneyTx> transactions;
  final String? accountIban;
  final String? message;
}

abstract class BankConnector {
  BankId get bank;

  Future<BankAuthSession> startLink({
    required String redirectUri,
    required String personId,
  });

  Future<BankSyncResult> completeLink({
    required String sessionId,
    required String personId,
  });

  Future<BankSyncResult> pullTransactions({
    required String accountRef,
    required String personId,
    DateTime? from,
  });
}

class BankAuthSession {
  const BankAuthSession({
    required this.sessionId,
    required this.authorizationUrl,
  });

  final String sessionId;
  final String authorizationUrl;
}

class BankCredentials {
  const BankCredentials({
    this.gocardlessSecretId,
    this.gocardlessSecretKey,
    this.wiseApiToken,
  });

  final String? gocardlessSecretId;
  final String? gocardlessSecretKey;
  final String? wiseApiToken;

  bool get hasGoCardless =>
      (gocardlessSecretId?.isNotEmpty ?? false) &&
      (gocardlessSecretKey?.isNotEmpty ?? false);

  bool get hasWise => wiseApiToken?.isNotEmpty ?? false;
}
