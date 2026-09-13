import '../models/bank.dart';
import '../models/transaction.dart';
import 'enable_banking_callback.dart';

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

class BankSyncException implements Exception {
  BankSyncException(this.message);
  final String message;
  @override
  String toString() => message;
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
    this.state,
  });

  /// Enable Banking authorization_id until the PSU callback is exchanged.
  final String sessionId;
  final String authorizationUrl;

  /// OAuth `state` sent to Enable Banking and returned on the HTTPS callback.
  final String? state;
}

class EnableBankingLinkedSession {
  const EnableBankingLinkedSession({
    required this.sessionId,
    this.accountId,
    this.iban,
    this.displayName,
  });

  final String sessionId;
  final String? accountId;
  final String? iban;
  final String? displayName;
}

class EnableBankingAspsp {
  const EnableBankingAspsp({
    required this.name,
    required this.country,
    this.bic,
    this.maximumConsentValidity,
  });

  final String name;
  final String country;
  final String? bic;
  final int? maximumConsentValidity;
}

class BankCredentials {
  const BankCredentials({
    this.enableBankingApplicationId,
    this.enableBankingPrivateKey,
    this.enableBankingRedirectUri,
    this.wiseApiToken,
  });

  /// Enable Banking application id (`kid` in the JWT header).
  final String? enableBankingApplicationId;

  /// RSA private key PEM used to sign Enable Banking JWTs.
  final String? enableBankingPrivateKey;

  /// Redirect URL registered in the Enable Banking control panel.
  final String? enableBankingRedirectUri;

  final String? wiseApiToken;

  static const defaultRedirectUri = EnableBankingCallback.hostedRedirectUri;

  bool get hasEnableBanking =>
      (enableBankingApplicationId?.isNotEmpty ?? false) &&
      (enableBankingPrivateKey?.isNotEmpty ?? false);

  bool get hasWise => wiseApiToken?.isNotEmpty ?? false;

  String get redirectUri {
    final configured = enableBankingRedirectUri?.trim();
    if (configured != null && configured.isNotEmpty) return configured;
    return defaultRedirectUri;
  }
}
