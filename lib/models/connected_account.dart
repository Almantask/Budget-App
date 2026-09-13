import 'bank.dart';

class ConnectedAccount {
  const ConnectedAccount({
    required this.id,
    required this.bank,
    required this.personId,
    required this.displayName,
    this.iban,
    this.enableBankingAuthorizationId,
    this.enableBankingSessionId,
    this.enableBankingAccountId,
    this.enableBankingState,
    this.authorizationUrl,
    this.lastSyncedAt,
    this.status = AccountLinkStatus.disconnected,
  });

  final String id;
  final BankId bank;
  final String personId;
  final String displayName;
  final String? iban;
  final String? enableBankingAuthorizationId;
  final String? enableBankingSessionId;
  final String? enableBankingAccountId;
  final String? enableBankingState;
  final String? authorizationUrl;
  final DateTime? lastSyncedAt;
  final AccountLinkStatus status;

  bool get isLinked =>
      status == AccountLinkStatus.connected ||
      status == AccountLinkStatus.demo;

  ConnectedAccount copyWith({
    String? personId,
    String? displayName,
    String? iban,
    String? enableBankingAuthorizationId,
    String? enableBankingSessionId,
    String? enableBankingAccountId,
    String? enableBankingState,
    String? authorizationUrl,
    DateTime? lastSyncedAt,
    AccountLinkStatus? status,
  }) {
    return ConnectedAccount(
      id: id,
      bank: bank,
      personId: personId ?? this.personId,
      displayName: displayName ?? this.displayName,
      iban: iban ?? this.iban,
      enableBankingAuthorizationId:
          enableBankingAuthorizationId ?? this.enableBankingAuthorizationId,
      enableBankingSessionId:
          enableBankingSessionId ?? this.enableBankingSessionId,
      enableBankingAccountId:
          enableBankingAccountId ?? this.enableBankingAccountId,
      enableBankingState: enableBankingState ?? this.enableBankingState,
      authorizationUrl: authorizationUrl ?? this.authorizationUrl,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bank': bank.name,
        'personId': personId,
        'displayName': displayName,
        'iban': iban,
        'enableBankingAuthorizationId': enableBankingAuthorizationId,
        'enableBankingSessionId': enableBankingSessionId,
        'enableBankingAccountId': enableBankingAccountId,
        'enableBankingState': enableBankingState,
        'authorizationUrl': authorizationUrl,
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
        'status': status.name,
      };

  factory ConnectedAccount.fromJson(Map<String, dynamic> json) =>
      ConnectedAccount(
        id: json['id'] as String,
        bank: BankId.tryParse(json['bank'] as String? ?? '') ?? BankId.swed,
        personId: json['personId'] as String,
        displayName: json['displayName'] as String,
        iban: json['iban'] as String?,
        enableBankingAuthorizationId:
            json['enableBankingAuthorizationId'] as String?,
        enableBankingSessionId: json['enableBankingSessionId'] as String? ??
            json['gocardlessRequisitionId'] as String?,
        enableBankingAccountId: json['enableBankingAccountId'] as String? ??
            json['gocardlessAccountId'] as String?,
        enableBankingState: json['enableBankingState'] as String?,
        authorizationUrl: json['authorizationUrl'] as String?,
        lastSyncedAt: json['lastSyncedAt'] == null
            ? null
            : DateTime.parse(json['lastSyncedAt'] as String),
        status: AccountLinkStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => AccountLinkStatus.disconnected,
        ),
      );
}

enum AccountLinkStatus { disconnected, pending, connected, demo }
