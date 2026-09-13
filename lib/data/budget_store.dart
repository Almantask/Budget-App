import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../banks/bank_connector.dart';
import '../models/budget_limit.dart';
import '../models/connected_account.dart';
import '../models/notice.dart';
import '../models/person.dart';
import '../models/transaction.dart';

class BudgetStore {
  BudgetStore({
    SharedPreferences? prefs,
    FlutterSecureStorage? secure,
  })  : _prefsOverride = prefs,
        _secure = secure ?? const FlutterSecureStorage();

  static const _stateKey = 'budget_state_v1';
  static const _applicationIdKey = 'eb_application_id';
  static const _privateKeyKey = 'eb_private_key';
  static const _redirectUriKey = 'eb_redirect_uri';
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
    final fromSecure = await _readSecureCredentials();
    final fromPrefs = await _readPrefsCredentials();
    return BankCredentials(
      enableBankingApplicationId: _prefer(
        fromSecure.enableBankingApplicationId,
        fromPrefs.enableBankingApplicationId,
      ),
      enableBankingPrivateKey: _prefer(
        fromSecure.enableBankingPrivateKey,
        fromPrefs.enableBankingPrivateKey,
      ),
      enableBankingRedirectUri: _prefer(
        fromSecure.enableBankingRedirectUri,
        fromPrefs.enableBankingRedirectUri,
      ),
      wiseApiToken: _prefer(fromSecure.wiseApiToken, fromPrefs.wiseApiToken),
    ).normalized();
  }

  Future<void> saveCredentials(BankCredentials credentials) async {
    final next = credentials.normalized();
    var stored = false;
    Object? lastError;
    try {
      await _writeOrDelete(
        _applicationIdKey,
        next.enableBankingApplicationId,
      );
      await _writeOrDelete(_privateKeyKey, next.enableBankingPrivateKey);
      await _writeOrDelete(_redirectUriKey, next.enableBankingRedirectUri);
      await _writeOrDelete(_wiseKey, next.wiseApiToken);
      stored = true;
    } catch (error) {
      lastError = error;
    }
    try {
      await _writePrefsCredentials(next);
      stored = true;
    } catch (error) {
      lastError = error;
    }
    if (!stored) {
      throw StateError(
        'Nepavyko išsaugoti Enable Banking raktų: $lastError',
      );
    }
  }

  Future<BankCredentials> _readSecureCredentials() async {
    try {
      return BankCredentials(
        enableBankingApplicationId: await _secure.read(key: _applicationIdKey),
        enableBankingPrivateKey: await _secure.read(key: _privateKeyKey),
        enableBankingRedirectUri: await _secure.read(key: _redirectUriKey),
        wiseApiToken: await _secure.read(key: _wiseKey),
      );
    } catch (_) {
      return const BankCredentials();
    }
  }

  Future<BankCredentials> _readPrefsCredentials() async {
    final prefs = await _ensurePrefs();
    return BankCredentials(
      enableBankingApplicationId: prefs.getString(_applicationIdKey),
      enableBankingPrivateKey: prefs.getString(_privateKeyKey),
      enableBankingRedirectUri: prefs.getString(_redirectUriKey),
      wiseApiToken: prefs.getString(_wiseKey),
    );
  }

  Future<void> _writePrefsCredentials(BankCredentials credentials) async {
    final prefs = await _ensurePrefs();
    await _writePrefsOrDelete(
      prefs,
      _applicationIdKey,
      credentials.enableBankingApplicationId,
    );
    await _writePrefsOrDelete(
      prefs,
      _privateKeyKey,
      credentials.enableBankingPrivateKey,
    );
    await _writePrefsOrDelete(
      prefs,
      _redirectUriKey,
      credentials.enableBankingRedirectUri,
    );
    await _writePrefsOrDelete(prefs, _wiseKey, credentials.wiseApiToken);
  }

  Future<void> _writeOrDelete(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _secure.delete(key: key);
    } else {
      await _secure.write(key: key, value: value);
    }
  }

  Future<void> _writePrefsOrDelete(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null || value.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  static String? _prefer(String? primary, String? fallback) {
    if (primary != null && primary.isNotEmpty) return primary;
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return null;
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
    this.budgets = BudgetLimit.defaults,
    this.notices = const [],
    this.alertSnapshot = const <String, String>{},
  });

  final Household household;
  final List<MoneyTx> transactions;
  final List<ConnectedAccount> accounts;
  final DateTime? lastDailySyncAt;
  final bool autoSyncEnabled;
  final bool demoLoaded;
  final List<BudgetLimit> budgets;
  final List<ThresholdNotice> notices;
  final Map<String, String> alertSnapshot;

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
    List<BudgetLimit>? budgets,
    List<ThresholdNotice>? notices,
    Map<String, String>? alertSnapshot,
  }) {
    return BudgetState(
      household: household ?? this.household,
      transactions: transactions ?? this.transactions,
      accounts: accounts ?? this.accounts,
      lastDailySyncAt: lastDailySyncAt ?? this.lastDailySyncAt,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      demoLoaded: demoLoaded ?? this.demoLoaded,
      budgets: budgets ?? this.budgets,
      notices: notices ?? this.notices,
      alertSnapshot: alertSnapshot ?? this.alertSnapshot,
    );
  }

  Map<String, dynamic> toJson() => {
        'household': household.toJson(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'lastDailySyncAt': lastDailySyncAt?.toIso8601String(),
        'autoSyncEnabled': autoSyncEnabled,
        'demoLoaded': demoLoaded,
        'budgets': budgets.map((b) => b.toJson()).toList(),
        'notices': notices.map((n) => n.toJson()).toList(),
        'alertSnapshot': alertSnapshot,
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
        budgets: json['budgets'] == null
            ? BudgetLimit.defaults
            : (json['budgets'] as List<dynamic>)
                .map((e) => BudgetLimit.fromJson(e as Map<String, dynamic>))
                .toList(),
        notices: (json['notices'] as List<dynamic>? ?? const [])
            .map((e) => ThresholdNotice.fromJson(e as Map<String, dynamic>))
            .toList(),
        alertSnapshot: (json['alertSnapshot'] as Map<String, dynamic>? ??
                const <String, dynamic>{})
            .map((key, value) => MapEntry(key, value.toString())),
      );
}
