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

  /// True only when both an application id and a private PEM key are present.
  /// A pasted `.crt` certificate is not enough — JWT signing needs the key.
  bool get hasEnableBanking {
    final normalized = this.normalized();
    return (normalized.enableBankingApplicationId?.isNotEmpty ?? false) &&
        looksLikePrivateKey(normalized.enableBankingPrivateKey);
  }

  bool get hasWise => wiseApiToken?.isNotEmpty ?? false;

  String get redirectUri {
    final configured = enableBankingRedirectUri?.trim();
    if (configured != null && configured.isNotEmpty) return configured;
    return defaultRedirectUri;
  }

  BankCredentials normalized() {
    return BankCredentials(
      enableBankingApplicationId:
          normalizeApplicationId(enableBankingApplicationId),
      enableBankingPrivateKey: normalizePrivateKey(enableBankingPrivateKey),
      enableBankingRedirectUri: _blankToNull(enableBankingRedirectUri?.trim()),
      wiseApiToken: _blankToNull(wiseApiToken?.trim()),
    );
  }

  /// Strips quotes and a trailing `.pem` if the user pasted the key filename.
  static String? normalizeApplicationId(String? raw) {
    var value = _unwrapQuotes(raw);
    if (value == null) return null;
    if (value.toLowerCase().endsWith('.pem')) {
      value = value.substring(0, value.length - 4).trim();
    }
    return _blankToNull(value);
  }

  /// Keeps PEM newlines; turns literal `\n` from env/JSON pastes into real ones.
  static String? normalizePrivateKey(String? raw) {
    var value = _unwrapQuotes(raw);
    if (value == null) return null;
    if (value.contains(r'\n') && !value.contains('\n')) {
      value = value.replaceAll(r'\n', '\n');
    }
    return _blankToNull(value.trim());
  }

  static bool looksLikePrivateKey(String? pem) {
    if (pem == null || pem.isEmpty) return false;
    final upper = pem.toUpperCase();
    return upper.contains('BEGIN PRIVATE KEY') ||
        upper.contains('BEGIN RSA PRIVATE KEY') ||
        upper.contains('BEGIN EC PRIVATE KEY');
  }

  static bool looksLikeCertificateOnly(String? pem) {
    if (pem == null || pem.isEmpty) return false;
    final upper = pem.toUpperCase();
    return upper.contains('BEGIN CERTIFICATE') && !looksLikePrivateKey(pem);
  }

  static String? _unwrapQuotes(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.length >= 2) {
      final first = value.codeUnitAt(0);
      final last = value.codeUnitAt(value.length - 1);
      final quoted = (first == 34 && last == 34) || (first == 39 && last == 39);
      if (quoted) {
        value = value.substring(1, value.length - 1).trim();
      }
    }
    return _blankToNull(value);
  }

  static String? _blankToNull(String? value) {
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
