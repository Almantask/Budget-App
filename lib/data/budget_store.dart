import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../banks/bank_connector.dart';
import '../models/connected_account.dart';
import '../models/person.dart';
import '../models/transaction.dart';

class BudgetStore {
  BudgetStore({
    SharedPreferences? prefs,
    FlutterSecureStorage? secure,
  })  : _prefsOverride = prefs,
        _secure = secure ?? const FlutterSecureStorage();

  static const _stateKey = 'budget_state_v1';
  static const _secretIdKey = 'gc_secret_id';
  static const _secretKeyKey = 'gc_secret_key';
  static const _wiseKey = 'wise_api_token';
  static const dailySyncTask = 'lt.almantask.budget.dailySync';

  final SharedPreferences? _prefsOverride;
  final FlutterSecureStorage _secure;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= _prefsOverride ?? await SharedPreferences.getInstance();
  }

  Future<BudgetState> load() async {
    final prefs = await _ensurePrefs();
    final raw = prefs.getString(_stateKey);
    if (raw == null || raw.isEmpty) {
      return BudgetState.empty();
    }
    return BudgetState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(BudgetState state) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_stateKey, jsonEncode(state.toJson()));
  }

  Future<BankCredentials> loadCredentials() async {
    try {
      return BankCredentials(
        gocardlessSecretId: await _secure.read(key: _secretIdKey),
        gocardlessSecretKey: await _secure.read(key: _secretKeyKey),
        wiseApiToken: await _secure.read(key: _wiseKey),
      );
    } catch (_) {
      return const BankCredentials();
    }
  }

  Future<void> saveCredentials(BankCredentials credentials) async {
    try {
      await _writeOrDelete(_secretIdKey, credentials.gocardlessSecretId);
      await _writeOrDelete(_secretKeyKey, credentials.gocardlessSecretKey);
      await _writeOrDelete(_wiseKey, credentials.wiseApiToken);
    } catch (_) {}
  }

  Future<void> _writeOrDelete(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _secure.delete(key: key);
    } else {
      await _secure.write(key: key, value: value);
    }
  }
}

class BudgetState {
  const BudgetState({
    required this.household,
    required this.transactions,
    required this.accounts,
    this.lastDailySyncAt,
    this.autoSyncEnabled = true,
    this.demoLoaded = false,
  });

  final Household household;
  final List<MoneyTx> transactions;
  final List<ConnectedAccount> accounts;
  final DateTime? lastDailySyncAt;
  final bool autoSyncEnabled;
  final bool demoLoaded;

  factory BudgetState.empty() => const BudgetState(
        household: Household.defaults,
        transactions: [],
        accounts: [],
      );

  BudgetState copyWith({
    Household? household,
    List<MoneyTx>? transactions,
    List<ConnectedAccount>? accounts,
    DateTime? lastDailySyncAt,
    bool? autoSyncEnabled,
    bool? demoLoaded,
  }) {
    return BudgetState(
      household: household ?? this.household,
      transactions: transactions ?? this.transactions,
      accounts: accounts ?? this.accounts,
      lastDailySyncAt: lastDailySyncAt ?? this.lastDailySyncAt,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      demoLoaded: demoLoaded ?? this.demoLoaded,
    );
  }

  Map<String, dynamic> toJson() => {
        'household': household.toJson(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'lastDailySyncAt': lastDailySyncAt?.toIso8601String(),
        'autoSyncEnabled': autoSyncEnabled,
        'demoLoaded': demoLoaded,
      };

  factory BudgetState.fromJson(Map<String, dynamic> json) => BudgetState(
        household: Household.fromJson(
          json['household'] as Map<String, dynamic>,
        ),
        transactions: (json['transactions'] as List<dynamic>? ?? const [])
            .map((e) => MoneyTx.fromJson(e as Map<String, dynamic>))
            .toList(),
        accounts: (json['accounts'] as List<dynamic>? ?? const [])
            .map((e) => ConnectedAccount.fromJson(e as Map<String, dynamic>))
            .toList(),
        lastDailySyncAt: json['lastDailySyncAt'] == null
            ? null
            : DateTime.parse(json['lastDailySyncAt'] as String),
        autoSyncEnabled: json['autoSyncEnabled'] as bool? ?? true,
        demoLoaded: json['demoLoaded'] as bool? ?? false,
      );
}
