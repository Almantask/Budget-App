import 'bank.dart';

class ConnectedAccount {
  const ConnectedAccount({
    required this.id,
    required this.bank,
    required this.personId,
    required this.displayName,
    this.iban,
    this.gocardlessRequisitionId,
    this.gocardlessAccountId,
    this.lastSyncedAt,
    this.status = AccountLinkStatus.disconnected,
  });

  final String id;
  final BankId bank;
  final String personId;
  final String displayName;
  final String? iban;
  final String? gocardlessRequisitionId;
  final String? gocardlessAccountId;
  final DateTime? lastSyncedAt;
  final AccountLinkStatus status;

  bool get isLinked =>
      status == AccountLinkStatus.connected ||
      status == AccountLinkStatus.demo;

  ConnectedAccount copyWith({
    String? personId,
    String? displayName,
    String? iban,
    String? gocardlessRequisitionId,
    String? gocardlessAccountId,
    DateTime? lastSyncedAt,
    AccountLinkStatus? status,
  }) {
    return ConnectedAccount(
      id: id,
      bank: bank,
      personId: personId ?? this.personId,
      displayName: displayName ?? this.displayName,
      iban: iban ?? this.iban,
      gocardlessRequisitionId:
          gocardlessRequisitionId ?? this.gocardlessRequisitionId,
      gocardlessAccountId: gocardlessAccountId ?? this.gocardlessAccountId,
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
        'gocardlessRequisitionId': gocardlessRequisitionId,
        'gocardlessAccountId': gocardlessAccountId,
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
        gocardlessRequisitionId: json['gocardlessRequisitionId'] as String?,
        gocardlessAccountId: json['gocardlessAccountId'] as String?,
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
