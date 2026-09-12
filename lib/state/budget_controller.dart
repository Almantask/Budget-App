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
import '../models/budget_limit.dart';
import '../models/connected_account.dart';
import '../models/filters.dart';
import '../models/gamification.dart';
import '../models/insight.dart';
import '../models/notice.dart';
import '../models/period.dart';
import '../models/person.dart';
import '../models/spend_tag.dart';
import '../models/transaction.dart';
import '../services/analytics.dart';
import '../services/anomalies.dart';
import '../services/csv_export.dart';
import '../services/csv_import.dart';
import '../services/dates.dart';
import '../services/gamification.dart';
import '../services/insights_engine.dart';
import '../services/notices.dart';
import '../services/thresholds.dart';

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
  final thresholds = const ThresholdEngine();
  final games = const GameEngine();
  final anomalyEngine = const AnomalyEngine();

  BudgetState state = BudgetState.empty();
  BudgetFilters filters = const BudgetFilters();
  PeriodKind period = PeriodKind.month;
  BankCredentials credentials = const BankCredentials();
  bool loading = true;
  bool syncing = false;
  bool trendWeekly = false;
  String? statusMessage;
  _ViewCache? _viewCache;

  Object _viewToken() {
    final n = now();
    return Object.hash(
      identityHashCode(state),
      identityHashCode(filters),
      period,
      DateTime(n.year, n.month, n.day),
    );
  }

  _ViewCache _view() {
    final token = _viewToken();
    final cached = _viewCache;
    if (cached != null && cached.token == token) return cached;
    return _viewCache = _ViewCache(token);
  }

  void _invalidateView() => _viewCache = null;

  List<MoneyTx> get _filteredAll {
    final view = _view();
    return view.filtered ??=
        analytics.applyFilters(state.transactions, filters);
  }

  List<MoneyTx> get visibleTransactions {
    final view = _view();
    return view.visibleTransactions ??= () {
      final range = currentRange;
      return _filteredAll.where((t) => range.contains(t.bookedAt)).toList()
        ..sort((a, b) => b.bookedAt.compareTo(a.bookedAt));
    }();
  }

  DateRange get currentRange {
    final view = _view();
    return view.currentRange ??= const PeriodResolver().resolve(
      kind: period,
      now: now(),
      dataStart: analytics.earliest(state.transactions),
    );
  }

  DateRange get previousRange {
    final view = _view();
    return view.previousRange ??= currentRange.previous;
  }

  PeriodSnapshot get snapshot {
    final view = _view();
    return view.snapshot ??= analytics.snapshot(
      txs: _filteredAll,
      current: currentRange,
      previous: previousRange,
    );
  }

  List<SavingTip> get savingTips {
    final view = _view();
    return view.savingTips ??= insights.savingTips(
      txs: _filteredAll,
      snapshot: snapshot,
      period: period,
    );
  }

  List<BiggestValueItem> get biggestValue {
    final view = _view();
    return view.biggestValue ??= insights.biggestValue(
      txs: _filteredAll,
      current: currentRange,
    );
  }

  String get viewMonth => monthKey(now());

  List<ThresholdAlert> get thresholdAlerts {
    final view = _view();
    return view.thresholdAlerts ??= thresholds.collectAlerts(
      txs: state.transactions,
      budgets: state.budgets,
      month: viewMonth,
      today: now(),
    );
  }

  List<SpendingAnomaly> get spendingAnomalies {
    final view = _view();
    return view.spendingAnomalies ??= anomalyEngine.findSpendingAnomalies(
      txs: state.transactions,
      viewMonth: viewMonth,
      today: now(),
    );
  }

  Set<String> get unusualTransactionIds {
    final view = _view();
    return view.unusualTransactionIds ??= {
      for (final item in spendingAnomalies)
        if (item.transactionId != null) item.transactionId!,
    };
  }

  List<MonthPoint> get trendMonths {
    final view = _view();
    return view.trendMonths ??= analytics.trimSeries(
      analytics.monthlySeries(state.transactions, viewMonth),
    );
  }

  List<WeekPoint> get trendWeeks {
    final view = _view();
    return view.trendWeeks ??=
        analytics.weeklySeries(state.transactions, viewMonth);
  }

  MonthPoint get currentMonthPoint {
    final view = _view();
    return view.currentMonthPoint ??=
        analytics.monthTotals(state.transactions, viewMonth);
  }

  List<MonthPoint> get savingsHistory {
    final view = _view();
    return view.savingsHistory ??=
        analytics.fullHistory(state.transactions, viewMonth);
  }

  StretchGoal get stretchGoal {
    final view = _view();
    return view.stretchGoal ??=
        games.stretchGoalForMonth(savingsHistory, viewMonth);
  }

  List<StretchHit> get stretchHistory {
    final view = _view();
    return view.stretchHistory ??= games.stretchHits(savingsHistory);
  }

  List<Quest> get monthQuestList {
    final view = _view();
    return view.monthQuestList ??= games.monthQuests(
      txs: state.transactions,
      budgets: state.budgets,
      month: viewMonth,
      today: now(),
      stretch: stretchGoal,
      monthPoint: currentMonthPoint,
      alerts: thresholdAlerts,
    );
  }

  List<Achievement> get achievements {
    final view = _view();
    return view.achievements ??= games.collectAchievements(
      txs: state.transactions,
      budgets: state.budgets,
      today: now(),
      history: savingsHistory,
      hits: stretchHistory,
    );
  }

  LevelProgress get levelProgress {
    final view = _view();
    return view.levelProgress ??= () {
      final uniqueDays =
          state.transactions.map((tx) => dateKey(tx.bookedAt)).toSet().length;
      final xp = games.computeXp(
        transactionCount:
            state.transactions.where((tx) => !tx.isTransfer).length,
        uniqueDays: uniqueDays,
        hits: stretchHistory,
        underBudgetMonths: games.pastUnderBudgetCount(
          txs: state.transactions,
          budgets: state.budgets,
          history: savingsHistory,
          today: now(),
        ),
        questsComplete: monthQuestList.where((quest) => quest.complete).length,
        achievements: achievements,
      );
      return games.levelFromXp(xp);
    }();
  }

  int get loggingStreak {
    final view = _view();
    return view.loggingStreak ??= games.loggingStreak(state.transactions, now());
  }

  List<ThresholdNotice> get unreadNotices =>
      state.notices.where((notice) => !notice.read).toList();

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
    _invalidateView();
    notifyListeners();
  }

  Future<void> loadDemoData() async {
    final demo = const DemoHouseholdFactory().build(now());
    state = state.copyWith(
      transactions: demo.transactions,
      accounts: demo.accounts,
      demoLoaded: true,
      lastDailySyncAt: now(),
      notices: const [],
      alertSnapshot: const {},
      budgets: state.budgets.isEmpty ? BudgetLimit.defaults : state.budgets,
    );
    await _finishLedgerChange(
      'Įkelti demo šeimos duomenys. Galite jungti tikrus bankus.',
    );
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
      await _finishLedgerChange('$triggeredBy baigta.');
    } catch (error) {
      statusMessage = 'Sinchronizacija nepavyko: $error';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<Uri?> connectBank(BankId bank, {String? personId}) async {
    final owner = personId ?? Person.meId;
    try {
      final session = await _sync.startOpenBankingLink(
        credentials: credentials,
        bank: bank,
        redirectUri: credentials.redirectUri,
        personId: owner,
      );
      final existing = state.accounts.where((a) => a.bank != bank).toList();
      final live = credentials.hasEnableBanking;
      final account = ConnectedAccount(
        id: 'acc-${bank.name}',
        bank: bank,
        personId: owner,
        displayName: '${bank.label} sąskaita',
        enableBankingAuthorizationId: live ? session.sessionId : null,
        authorizationUrl: live ? session.authorizationUrl : null,
        status: live ? AccountLinkStatus.pending : AccountLinkStatus.demo,
        lastSyncedAt: now(),
      );
      state = state.copyWith(accounts: [...existing, account]);
      await _store.save(state);
      statusMessage = live
          ? 'Patvirtinkite ${bank.label} Enable Banking sutikimą naršyklėje, tada įklijuokite grįžimo nuorodą.'
          : '${bank.label} susietas demo režimu. Įveskite Enable Banking raktus gyvam PSD2.';
      notifyListeners();
      if (!live) return null;
      return Uri.parse(session.authorizationUrl);
    } catch (error) {
      statusMessage = 'Nepavyko susieti ${bank.label}: $error';
      notifyListeners();
      return null;
    }
  }

  Future<void> completeBankLink(BankId bank, String callbackOrCode) async {
    try {
      final linked = await _sync.completeOpenBankingLink(
        credentials: credentials,
        callbackOrCode: callbackOrCode,
      );
      var found = false;
      final accounts = state.accounts.map((account) {
        if (account.bank != bank) return account;
        found = true;
        return account.copyWith(
          enableBankingSessionId: linked.sessionId,
          enableBankingAccountId: linked.accountId,
          iban: linked.iban,
          displayName: linked.displayName ?? account.displayName,
          status: AccountLinkStatus.connected,
        );
      }).toList();
      if (!found) {
        accounts.add(
          ConnectedAccount(
            id: 'acc-${bank.name}',
            bank: bank,
            personId: Person.meId,
            displayName: linked.displayName ?? '${bank.label} sąskaita',
            iban: linked.iban,
            enableBankingSessionId: linked.sessionId,
            enableBankingAccountId: linked.accountId,
            status: AccountLinkStatus.connected,
            lastSyncedAt: now(),
          ),
        );
      }
      state = state.copyWith(accounts: accounts);
      await _store.save(state);
      statusMessage = '${bank.label} prijungtas per Enable Banking.';
      notifyListeners();
      await syncAll(triggeredBy: '${bank.label} sinchronizacija');
    } catch (error) {
      statusMessage = 'Nepavyko užbaigti ${bank.label} susiejimo: $error';
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
    await _finishLedgerChange(
      'Importuota ${result.transactions.length} operacijų iš ${result.bank.label}.',
    );
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
    _invalidateView();
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
    _invalidateView();
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
    _invalidateView();
    notifyListeners();
  }

  void setPersonFilter(String personId) {
    filters = filters.copyWith(personId: personId);
    _invalidateView();
    notifyListeners();
  }

  void setCategoryFilter(String? categoryId) {
    filters = filters.copyWith(
      categoryId: categoryId,
      clearCategory: categoryId == null,
    );
    _invalidateView();
    notifyListeners();
  }

  void setTagFilter(SpendTag? tag) {
    filters = filters.copyWith(tag: tag, clearTag: tag == null);
    _invalidateView();
    notifyListeners();
  }

  void setQuery(String query) {
    filters = filters.copyWith(query: query);
    _invalidateView();
    notifyListeners();
  }

  void setTrendWeekly(bool weekly) {
    trendWeekly = weekly;
    notifyListeners();
  }

  Future<void> updateBudget({
    required String categoryId,
    required double monthlyLimit,
    required double warnAt,
  }) async {
    final next = [...state.budgets];
    final index = next.indexWhere((b) => b.categoryId == categoryId);
    final clampedWarn = warnAt.clamp(0.5, 1.0).toDouble();
    if (monthlyLimit <= 0) {
      if (index >= 0) next.removeAt(index);
    } else if (index >= 0) {
      next[index] = next[index].copyWith(
        monthlyLimit: monthlyLimit,
        warnAt: clampedWarn,
      );
    } else {
      next.add(
        BudgetLimit(
          id: 'b-$categoryId',
          categoryId: categoryId,
          monthlyLimit: monthlyLimit,
          warnAt: clampedWarn,
        ),
      );
    }
    state = state.copyWith(budgets: next);
    await _store.save(state);
    _invalidateView();
    notifyListeners();
  }

  Future<void> markNoticesRead() async {
    if (state.notices.every((notice) => notice.read)) return;
    state = state.copyWith(
      notices: [
        for (final notice in state.notices) notice.copyWith(read: true),
      ],
    );
    await _store.save(state);
    notifyListeners();
  }

  Future<void> _finishLedgerChange(String fallbackStatus) async {
    final today = now();
    final month = monthKey(today);
    final alerts = thresholds.collectAlerts(
      txs: state.transactions,
      budgets: state.budgets,
      month: month,
      today: today,
    );
    final fresh = noticesAfterSync(
      previous: state.alertSnapshot,
      alerts: alerts,
      month: month,
      at: today,
    );
    final snapshot = Map<String, String>.from(state.alertSnapshot)
      ..addAll(snapshotFromAlerts(month, alerts));
    state = state.copyWith(
      notices: [...fresh, ...state.notices].take(40).toList(),
      alertSnapshot: snapshot,
    );
    await _store.save(state);
    if (fresh.isEmpty) {
      statusMessage = fallbackStatus;
    } else if (fresh.length == 1) {
      statusMessage = noticeSnackTitle(fresh.first);
    } else {
      statusMessage = '${fresh.length} nauji biudžeto įspėjimai.';
    }
    _invalidateView();
    notifyListeners();
  }

  void clearStatus() {
    statusMessage = null;
    notifyListeners();
  }
}

class _ViewCache {
  _ViewCache(this.token);

  final Object token;
  DateRange? currentRange;
  DateRange? previousRange;
  List<MoneyTx>? filtered;
  List<MoneyTx>? visibleTransactions;
  PeriodSnapshot? snapshot;
  List<MonthPoint>? trendMonths;
  List<WeekPoint>? trendWeeks;
  List<ThresholdAlert>? thresholdAlerts;
  List<SpendingAnomaly>? spendingAnomalies;
  Set<String>? unusualTransactionIds;
  List<SavingTip>? savingTips;
  List<BiggestValueItem>? biggestValue;
  MonthPoint? currentMonthPoint;
  List<MonthPoint>? savingsHistory;
  StretchGoal? stretchGoal;
  List<StretchHit>? stretchHistory;
  List<Quest>? monthQuestList;
  List<Achievement>? achievements;
  LevelProgress? levelProgress;
  int? loggingStreak;
}

