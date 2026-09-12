import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../banks/bank_connector.dart';
import '../banks/sync_scheduler.dart';
import '../banks/sync_service.dart';
import '../data/budget_store.dart';
import '../data/demo_data.dart';
import '../models/bank.dart';
import '../models/connected_account.dart';
import '../models/filters.dart';
import '../models/insight.dart';
import '../models/period.dart';
import '../models/person.dart';
import '../models/spend_tag.dart';
import '../models/transaction.dart';
import '../services/analytics.dart';
import '../services/csv_export.dart';
import '../services/csv_import.dart';
import '../services/insights_engine.dart';

class BudgetController extends ChangeNotifier {
  BudgetController({
    BudgetStore? store,
    BankSyncService? syncService,
    SyncScheduler? scheduler,
    this.now = DateTime.now,
  })  : _store = store ?? BudgetStore(),
        _sync = syncService ?? BankSyncService(),
        _scheduler = scheduler ?? const SyncScheduler();

  final BudgetStore _store;
  final BankSyncService _sync;
  final SyncScheduler _scheduler;
  final DateTime Function() now;

  final analytics = const BudgetAnalytics();
  final insights = const InsightsEngine();
  final csvExporter = const CsvExporter();
  final csvImporter = BankCsvImporter();
  final deduper = const Deduper();

  BudgetState state = BudgetState.empty();
  BudgetFilters filters = const BudgetFilters();
  PeriodKind period = PeriodKind.month;
  BankCredentials credentials = const BankCredentials();
  bool loading = true;
  bool syncing = false;
  String? statusMessage;

  List<MoneyTx> get visibleTransactions {
    final range = currentRange;
    return analytics.applyFilters(
      state.transactions.where((t) => range.contains(t.bookedAt)).toList(),
      filters,
    )..sort((a, b) => b.bookedAt.compareTo(a.bookedAt));
  }

  DateRange get currentRange {
    return const PeriodResolver().resolve(
      kind: period,
      now: now(),
      dataStart: analytics.earliest(state.transactions),
    );
  }

  DateRange get previousRange => currentRange.previous;

  PeriodSnapshot get snapshot {
    final filtered = analytics.applyFilters(state.transactions, filters);
    return analytics.snapshot(
      txs: filtered,
      current: currentRange,
      previous: previousRange,
    );
  }

  List<SavingTip> get savingTips => insights.savingTips(
        txs: analytics.applyFilters(state.transactions, filters),
        snapshot: snapshot,
        period: period,
      );

  List<BiggestValueItem> get biggestValue => insights.biggestValue(
        txs: analytics.applyFilters(state.transactions, filters),
        current: currentRange,
      );

  Future<void> load() async {
    loading = true;
    notifyListeners();
    state = await _store.load();
    credentials = await _store.loadCredentials();
    if (state.autoSyncEnabled) {
      await _scheduler.registerDailySync();
    }
    if (state.transactions.isEmpty && !state.demoLoaded) {
      await loadDemoData();
    } else {
      await maybeDailySync();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadDemoData() async {
    final demo = const DemoHouseholdFactory().build(now());
    state = state.copyWith(
      transactions: demo.transactions,
      accounts: demo.accounts,
      demoLoaded: true,
      lastDailySyncAt: now(),
    );
    await _store.save(state);
    statusMessage = 'Įkelti demo šeimos duomenys. Galite jungti tikrus bankus.';
    notifyListeners();
  }

  Future<void> maybeDailySync({bool force = false}) async {
    if (!state.autoSyncEnabled && !force) return;
    final last = state.lastDailySyncAt;
    final today = DateTime(now().year, now().month, now().day);
    if (!force && last != null) {
      final lastDay = DateTime(last.year, last.month, last.day);
      if (!lastDay.isBefore(today)) return;
    }
    await syncAll(triggeredBy: 'Kasdienė sinchronizacija');
  }

  Future<void> syncAll({String triggeredBy = 'Sinchronizacija'}) async {
    if (syncing) return;
    syncing = true;
    statusMessage = '$triggeredBy vyksta…';
    notifyListeners();
    try {
      var txs = [...state.transactions];
      final accounts = <ConnectedAccount>[];
      for (final account in state.accounts.where((a) => a.isLinked)) {
        final incoming = await _sync.pullAccount(
          credentials: credentials,
          account: account,
          from: account.lastSyncedAt,
        );
        txs = deduper.merge(txs, incoming);
        accounts.add(account.copyWith(lastSyncedAt: now()));
      }
      final untouched = state.accounts.where((a) => !a.isLinked);
      state = state.copyWith(
        transactions: txs,
        accounts: [...accounts, ...untouched],
        lastDailySyncAt: now(),
      );
      await _store.save(state);
      statusMessage = '$triggeredBy baigta.';
    } catch (error) {
      statusMessage = 'Sinchronizacija nepavyko: $error';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> connectBank(BankId bank, {String? personId}) async {
    final owner = personId ?? Person.meId;
    try {
      final session = await _sync.startOpenBankingLink(
        credentials: credentials,
        bank: bank,
        redirectUri: 'https://budget.local/gocardless/callback',
        personId: owner,
      );
      final existing = state.accounts.where((a) => a.bank != bank).toList();
      final account = ConnectedAccount(
        id: 'acc-${bank.name}',
        bank: bank,
        personId: owner,
        displayName: '${bank.label} sąskaita',
        gocardlessRequisitionId: session.sessionId,
        status: credentials.hasGoCardless
            ? AccountLinkStatus.pending
            : AccountLinkStatus.demo,
        lastSyncedAt: now(),
      );
      state = state.copyWith(accounts: [...existing, account]);
      await _store.save(state);
      statusMessage = credentials.hasGoCardless
          ? 'Atidarykite banko sutikimą: ${session.authorizationUrl}'
          : '${bank.label} susietas demo režimu. Įveskite GoCardless raktus gyvam PSD2.';
      notifyListeners();
    } catch (error) {
      statusMessage = 'Nepavyko susieti ${bank.label}: $error';
      notifyListeners();
    }
  }

  Future<void> importCsv({
    required String csv,
    required BankId bank,
    required String personId,
  }) async {
    final result = csvImporter.parse(
      csv: csv,
      fallbackBank: bank,
      defaultPersonId: personId,
    );
    state = state.copyWith(
      transactions: deduper.merge(state.transactions, result.transactions),
    );
    await _store.save(state);
    statusMessage =
        'Importuota ${result.transactions.length} operacijų iš ${result.bank.label}.';
    notifyListeners();
  }

  Future<String?> pickAndImportCsv({
    required BankId bank,
    required String personId,
  }) async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    await importCsv(
      csv: String.fromCharCodes(bytes),
      bank: bank,
      personId: personId,
    );
    return null;
  }

  Future<void> exportCsv() async {
    final csv = csvExporter.export(
      txs: visibleTransactions,
      household: state.household,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(csv),
            mimeType: 'text/csv',
            name: 'biudzetas.csv',
          ),
        ],
        fileNameOverrides: const ['biudzetas.csv'],
        title: 'Šeimos biudžetas',
        subject: 'biudzetas.csv',
      ),
    );
  }

  String csvForVisible() {
    return csvExporter.export(
      txs: visibleTransactions,
      household: state.household,
    );
  }

  Future<void> updateTransaction(MoneyTx tx) async {
    final txs = state.transactions.map((t) => t.id == tx.id ? tx : t).toList();
    state = state.copyWith(transactions: txs);
    await _store.save(state);
    notifyListeners();
  }

  Future<void> renamePeople({required String me, required String partner}) async {
    state = state.copyWith(
      household: state.household.copyWith(
        me: state.household.me.copyWith(name: me),
        partner: state.household.partner.copyWith(name: partner),
      ),
    );
    await _store.save(state);
    notifyListeners();
  }

  Future<void> saveCredentials(BankCredentials next) async {
    credentials = next;
    await _store.saveCredentials(next);
    statusMessage = 'Bankų raktai išsaugoti įrenginyje.';
    notifyListeners();
  }

  Future<void> setAutoSync(bool enabled) async {
    state = state.copyWith(autoSyncEnabled: enabled);
    if (enabled) {
      await _scheduler.registerDailySync();
    } else {
      await _scheduler.cancel();
    }
    await _store.save(state);
    notifyListeners();
  }

  Future<void> assignAccountPerson(BankId bank, String personId) async {
    final accounts = state.accounts
        .map((a) => a.bank == bank ? a.copyWith(personId: personId) : a)
        .toList();
    state = state.copyWith(accounts: accounts);
    await _store.save(state);
    notifyListeners();
  }

  void setPeriod(PeriodKind kind) {
    period = kind;
    notifyListeners();
  }

  void setPersonFilter(String personId) {
    filters = filters.copyWith(personId: personId);
    notifyListeners();
  }

  void setCategoryFilter(String? categoryId) {
    filters = filters.copyWith(
      categoryId: categoryId,
      clearCategory: categoryId == null,
    );
    notifyListeners();
  }

  void setTagFilter(SpendTag? tag) {
    filters = filters.copyWith(tag: tag, clearTag: tag == null);
    notifyListeners();
  }

  void setQuery(String query) {
    filters = filters.copyWith(query: query);
    notifyListeners();
  }

  void clearStatus() {
    statusMessage = null;
    notifyListeners();
  }
}
