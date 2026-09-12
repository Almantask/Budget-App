import '../models/budget_limit.dart';
import '../models/gamification.dart';
import '../models/notice.dart';
import '../models/transaction.dart';
import '../ui/theme.dart';
import 'dates.dart';
import 'thresholds.dart';

class GameEngine {
  const GameEngine();

  StretchGoal stretchGoalForMonth(List<MonthPoint> history, String month) {
    final older =
        history.where((point) => point.month.compareTo(month) < 0).toList();
    final recent = older.length <= 3 ? older : older.sublist(older.length - 3);

    if (recent.isEmpty) {
      return StretchGoal(
        month: month,
        target: 200,
        baseline: 0,
        reason:
            'Pirmas mėnuo programėlėje — atidėkite 200 € ir pradėkite taupymo įprotį.',
      );
    }

    final last = recent.last;
    final average =
        recent.fold<double>(0, (sum, point) => sum + point.net) / recent.length;
    final best = recent.map((point) => point.net).reduce((a, b) => a > b ? a : b);

    if (last.net <= 0 && average <= 0) {
      return StretchGoal(
        month: month,
        target: 80,
        baseline: last.net,
        reason:
            'Švarus startas: užbaikite mėnesį 80 € pliusu ir atgaukite pagreitį.',
      );
    }

    final reference = [last.net, average, 0.0].reduce((a, b) => a > b ? a : b);
    var target = reference * 1.1;

    if (last.net > 0) {
      final floor = last.net * 1.08;
      final cap = last.net * 1.2;
      if (target < floor) target = floor;
      if (target > cap) target = cap;
    }

    if (last.net > 0 &&
        best > average * 1.35 &&
        last.net == best &&
        average > 0) {
      target = last.net * 1.05;
    }

    target = target < 50 ? 50 : niceAmount(target);

    final extra = target - (last.net > 0 ? last.net : 0);
    final extraClamped = extra < 0 ? 0.0 : extra;
    final perDay = extraClamped / daysInMonth(month);
    final extraText = extraClamped > 0
        ? ' Tai apie ${formatEur(perDay)} papildomai per dieną palyginti su praėjusiu mėnesiu.'
        : '';

    return StretchGoal(
      month: month,
      target: target,
      baseline: niceAmount(reference),
      reason:
          'Pastarųjų mėnesių taupymas apie ${formatEur(reference)}. Iššūkis — ${formatEur(target)} šį mėnesį.$extraText',
    );
  }

  List<Quest> monthQuests({
    required List<MoneyTx> txs,
    required List<BudgetLimit> budgets,
    required String month,
    required DateTime today,
    required StretchGoal stretch,
    required MonthPoint monthPoint,
    required List<ThresholdAlert> alerts,
  }) {
    final through =
        monthKey(today) == month ? dateKey(today) : '$month-31';
    final logged = datesLoggedInMonth(txs, month, through);
    final logTarget = (daysInMonth(month) / 4).ceil().clamp(6, 10);
    final warningCount =
        alerts.where((alert) => alert.level != AlertLevel.pace).length;
    BudgetLimit? overall;
    for (final budget in budgets) {
      if (budget.categoryId == 'overall') {
        overall = budget;
        break;
      }
    }
    final overallSpent = const ThresholdEngine().spentInMonth(txs, month);
    final overallLimit = overall?.monthlyLimit ?? 0;
    final stretchProgress = monthPoint.net < 0 ? 0.0 : monthPoint.net;

    return [
      Quest(
        id: 'stretch',
        title: 'Sutaupyk daugiau',
        detail: 'Po išlaidų atidėkite ${formatEur(stretch.target)}.',
        xp: 120,
        current: stretchProgress,
        target: stretch.target,
        unit: 'money',
        complete: monthPoint.net >= stretch.target,
      ),
      Quest(
        id: 'under-budget',
        title: 'Tilpk į biudžetą',
        detail: overall == null
            ? 'Nustatykite bendrą biudžetą, kad įjungtumėte šį iššūkį.'
            : 'Laikykite visas išlaidas iki ${formatEur(overall.monthlyLimit)}.',
        xp: 60,
        current: overallSpent,
        target: overallLimit == 0 ? 1 : overallLimit,
        unit: 'money',
        complete: overall != null && overallSpent <= overallLimit,
      ),
      Quest(
        id: 'calm-categories',
        title: 'Ramios kategorijos',
        detail: 'Nesužadinkite įspėjimo ar viršijimo nė vienoje kategorijoje.',
        xp: 50,
        current: warningCount == 0 ? 1 : 0,
        target: 1,
        unit: 'count',
        complete: warningCount == 0,
      ),
      Quest(
        id: 'keep-logging',
        title: 'Fiksuokite operacijas',
        detail: 'Turėkite aktyvumą $logTarget skirtingomis šio mėnesio dienomis.',
        xp: 40,
        current: logged.toDouble(),
        target: logTarget.toDouble(),
        unit: 'count',
        complete: logged >= logTarget,
      ),
    ];
  }

  List<StretchHit> stretchHits(List<MonthPoint> history) {
    return [
      for (var i = 0; i < history.length; i++)
        StretchHit(
          month: history[i].month,
          hit: history[i].net >=
              stretchGoalForMonth(history.sublist(0, i), history[i].month)
                  .target,
          goal: stretchGoalForMonth(history.sublist(0, i), history[i].month),
          net: history[i].net,
        ),
    ];
  }

  List<Achievement> collectAchievements({
    required List<MoneyTx> txs,
    required List<BudgetLimit> budgets,
    required DateTime today,
    required List<MonthPoint> history,
    required List<StretchHit> hits,
  }) {
    final streak = loggingStreak(txs, today);
    final completedMonths = history
        .where((point) => point.month.compareTo(monthKey(today)) < 0)
        .toList();
    BudgetLimit? overall;
    for (final budget in budgets) {
      if (budget.categoryId == 'overall') {
        overall = budget;
        break;
      }
    }
    final engine = const ThresholdEngine();
    final underBudgetMonths = completedMonths.where((point) {
      final spent = engine.spentInMonth(txs, point.month);
      return overall != null ? spent <= overall.monthlyLimit : point.net > 0;
    });
    final quietMonths = completedMonths.where((point) {
      final monthEnd = DateTime(
        int.parse(point.month.split('-')[0]),
        int.parse(point.month.split('-')[1]),
        28,
      );
      final alerts = engine.collectAlerts(
        txs: txs,
        budgets: budgets,
        month: point.month,
        today: monthEnd,
      );
      return alerts.where((alert) => alert.level != AlertLevel.pace).isEmpty;
    });
    final balancedMonths = completedMonths.where((point) {
      final monthEnd = DateTime(
        int.parse(point.month.split('-')[0]),
        int.parse(point.month.split('-')[1]),
        28,
      );
      final alerts = engine
          .collectAlerts(
            txs: txs,
            budgets: budgets,
            month: point.month,
            today: monthEnd,
          )
          .where(
            (alert) =>
                alert.categoryId != 'overall' && alert.level != AlertLevel.pace,
          );
      return alerts.isEmpty;
    });
    final hitMonths = hits.where((hit) => hit.hit);
    var longestStretchRun = 0;
    var run = 0;
    for (final hit in hits) {
      run = hit.hit ? run + 1 : 0;
      if (run > longestStretchRun) longestStretchRun = run;
    }
    var cameBack = false;
    for (var i = 1; i < hits.length; i++) {
      if (hits[i].hit && !hits[i - 1].hit) cameBack = true;
    }
    final earlyRoot = txs.any((tx) => dateKey(tx.bookedAt).endsWith('-01'));
    final unlocked = <String>{};
    if (txs.isNotEmpty) unlocked.add('first-leaf');
    if (streak >= 7) unlocked.add('week-streak');
    if (underBudgetMonths.isNotEmpty) unlocked.add('month-under');
    if (hitMonths.isNotEmpty) unlocked.add('stretch-rookie');
    if (longestStretchRun >= 3) unlocked.add('stretch-streak');
    if (history.any((point) => point.net >= 500)) unlocked.add('big-save');
    if (quietMonths.isNotEmpty) unlocked.add('quiet-month');
    if (balancedMonths.isNotEmpty) unlocked.add('balanced-grove');
    if (cameBack) unlocked.add('comeback');
    if (earlyRoot) unlocked.add('early-root');

    return [
      for (final item in achievementCatalog())
        item.copyWith(unlocked: unlocked.contains(item.id)),
    ];
  }

  List<Achievement> achievementCatalog() {
    return const [
      Achievement(
        id: 'first-leaf',
        title: 'Pirmas lapas',
        detail: 'Įrašykite pirmą operaciją.',
        xp: 15,
        unlocked: false,
      ),
      Achievement(
        id: 'early-root',
        title: 'Ankstyva šaknis',
        detail: 'Turėkite operaciją pirmą mėnesio dieną.',
        xp: 20,
        unlocked: false,
      ),
      Achievement(
        id: 'week-streak',
        title: 'Septynios saulės',
        detail: '7 dienų operacijų serija.',
        xp: 40,
        unlocked: false,
      ),
      Achievement(
        id: 'month-under',
        title: 'Viduje tvoros',
        detail: 'Užbaikite mėnesį neviršydami bendro biudžeto.',
        xp: 50,
        unlocked: false,
      ),
      Achievement(
        id: 'quiet-month',
        title: 'Ramus lajas',
        detail: 'Užbaikite mėnesį be įspėjimo ribų.',
        xp: 55,
        unlocked: false,
      ),
      Achievement(
        id: 'balanced-grove',
        title: 'Subalansuotas miškas',
        detail: 'Visą mėnesį ramios visų kategorijų ribos.',
        xp: 60,
        unlocked: false,
      ),
      Achievement(
        id: 'stretch-rookie',
        title: 'Taupymo daigas',
        detail: 'Įvykdykite mėnesio taupymo iššūkį.',
        xp: 70,
        unlocked: false,
      ),
      Achievement(
        id: 'stretch-streak',
        title: 'Trigubas iššūkis',
        detail: 'Tris mėnesius iš eilės pasiekite taupymo tikslą.',
        xp: 120,
        unlocked: false,
      ),
      Achievement(
        id: 'big-save',
        title: 'Gilios šaknys',
        detail: 'Sutaupykite bent 500 € per vieną mėnesį.',
        xp: 80,
        unlocked: false,
      ),
      Achievement(
        id: 'comeback',
        title: 'Antras pavasaris',
        detail: 'Pasiekite tikslą po praleisto mėnesio.',
        xp: 45,
        unlocked: false,
      ),
    ];
  }

  int computeXp({
    required int transactionCount,
    required int uniqueDays,
    required List<StretchHit> hits,
    required int underBudgetMonths,
    required int questsComplete,
    required List<Achievement> achievements,
  }) {
    final stretchXp = hits.where((hit) => hit.hit).length * 120;
    final achievementXp = achievements
        .where((item) => item.unlocked)
        .fold<int>(0, (sum, item) => sum + item.xp);
    return transactionCount * 6 +
        uniqueDays * 8 +
        stretchXp +
        underBudgetMonths * 40 +
        questsComplete * 20 +
        achievementXp;
  }

  LevelProgress levelFromXp(int totalXp) {
    var remaining = totalXp < 0 ? 0 : totalXp;
    var level = 1;
    var need = 120;
    while (remaining >= need) {
      remaining -= need;
      level += 1;
      need = (need * 1.18).round();
    }
    return LevelProgress(
      level: level,
      intoLevel: remaining,
      toNext: need,
      progress: need == 0 ? 1 : remaining / need,
      totalXp: totalXp,
    );
  }

  int pastUnderBudgetCount({
    required List<MoneyTx> txs,
    required List<BudgetLimit> budgets,
    required List<MonthPoint> history,
    required DateTime today,
  }) {
    BudgetLimit? overall;
    for (final budget in budgets) {
      if (budget.categoryId == 'overall') {
        overall = budget;
        break;
      }
    }
    if (overall == null) return 0;
    final engine = const ThresholdEngine();
    return history.where((point) {
      if (point.month.compareTo(monthKey(today)) >= 0) return false;
      final spent = engine.spentInMonth(txs, point.month);
      return spent <= overall!.monthlyLimit;
    }).length;
  }

  int datesLoggedInMonth(List<MoneyTx> txs, String month, String throughDate) {
    return txs
        .where(
          (tx) =>
              monthKey(tx.bookedAt) == month &&
              dateKey(tx.bookedAt).compareTo(throughDate) <= 0,
        )
        .map((tx) => dateKey(tx.bookedAt))
        .toSet()
        .length;
  }

  int loggingStreak(List<MoneyTx> txs, DateTime today) {
    final dates = txs.map((tx) => dateKey(tx.bookedAt)).toSet();
    var streak = 0;
    var cursor = DateTime(today.year, today.month, today.day);
    if (!dates.contains(dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (dates.contains(dateKey(cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
