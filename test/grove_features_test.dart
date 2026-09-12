import 'package:flutter_test/flutter_test.dart';

import 'package:budget_app/models/bank.dart';
import 'package:budget_app/models/budget_limit.dart';
import 'package:budget_app/models/gamification.dart';
import 'package:budget_app/models/notice.dart';
import 'package:budget_app/models/person.dart';
import 'package:budget_app/models/spend_tag.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/services/anomalies.dart';
import 'package:budget_app/services/gamification.dart';
import 'package:budget_app/services/notices.dart';
import 'package:budget_app/services/thresholds.dart';

void main() {
  const engine = ThresholdEngine();
  const games = GameEngine();
  const anomalies = AnomalyEngine();

  group('evaluateBudget', () {
    test('stays ok while spend is below the warning threshold and pace is healthy',
        () {
      final result = engine.evaluateBudget(
        spent: 40,
        limit: 200,
        warnAt: 0.8,
        day: 10,
        daysInMonth: 30,
      );
      expect(result.level, AlertLevel.ok);
      expect(result.ratio, closeTo(0.2, 0.0001));
    });

    test('warns when spend crosses the configured threshold', () {
      final result = engine.evaluateBudget(
        spent: 165,
        limit: 200,
        warnAt: 0.8,
        day: 18,
        daysInMonth: 30,
      );
      expect(result.level, AlertLevel.warning);
      expect(engine.alertMessage('Restoranai', result), contains('80%'));
      expect(engine.alertMessage('Restoranai', result), contains('įspėjimo'));
    });

    test('marks a breach at or above the monthly limit', () {
      final result = engine.evaluateBudget(
        spent: 210,
        limit: 200,
        warnAt: 0.75,
        day: 20,
        daysInMonth: 30,
      );
      expect(result.level, AlertLevel.breach);
      expect(engine.alertMessage('Restoranai', result), contains('viršijo'));
    });

    test('flags a pace risk when projected spend will miss the limit', () {
      final result = engine.evaluateBudget(
        spent: 80,
        limit: 120,
        warnAt: 0.8,
        day: 10,
        daysInMonth: 30,
      );
      expect(result.level, AlertLevel.pace);
      expect(result.projected, closeTo(240, 0.01));
      expect(engine.alertMessage('Drabužiai', result), contains('tempu'));
    });

    test('does not pace a single lump-sum bill', () {
      final result = engine.evaluateBudget(
        spent: 650,
        limit: 700,
        warnAt: 1,
        day: 12,
        daysInMonth: 30,
        transactionCount: 1,
        recentSpent: 0,
        recentDays: 7,
      );
      expect(result.level, AlertLevel.ok);
    });
  });

  group('stretchGoalForMonth', () {
    test('uses a starter target when there is no history', () {
      final goal = games.stretchGoalForMonth(const [], '2026-09');
      expect(goal.target, 200);
    });

    test('asks for a modest reset after negative months', () {
      final goal = games.stretchGoalForMonth(
        [
          _point('2026-07', -40),
          _point('2026-08', -120),
        ],
        '2026-09',
      );
      expect(goal.target, 80);
    });

    test('stretches about 8–20% above a healthy last month', () {
      final goal = games.stretchGoalForMonth(
        [
          _point('2026-06', 400),
          _point('2026-07', 420),
          _point('2026-08', 500),
        ],
        '2026-09',
      );
      expect(goal.target, greaterThanOrEqualTo(540));
      expect(goal.target, lessThanOrEqualTo(600));
    });
  });

  group('levelFromXp', () {
    test('starts at level 1 and climbs as XP accumulates', () {
      expect(games.levelFromXp(0).level, 1);
      expect(games.levelFromXp(119).level, 1);
      expect(games.levelFromXp(120).level, 2);
      expect(games.levelFromXp(4000).level, greaterThan(8));
    });
  });

  test('completes the stretch quest when net savings clear the target', () {
    final txs = [
      _tx(
        id: '1',
        categoryId: 'income',
        amount: 2000,
        bookedAt: DateTime(2026, 9, 1),
        merchant: 'Alga',
      ),
      _tx(
        id: '2',
        categoryId: 'housing',
        amount: -600,
        bookedAt: DateTime(2026, 9, 2),
        merchant: 'Nuoma',
      ),
    ];
    final quests = games.monthQuests(
      txs: txs,
      budgets: BudgetLimit.defaults,
      month: '2026-09',
      today: DateTime(2026, 9, 12),
      stretch: const StretchGoal(
        month: '2026-09',
        target: 1000,
        baseline: 800,
        reason: 'test',
      ),
      monthPoint: const MonthPoint(
        month: '2026-09',
        label: 'rugs. 2026',
        expenses: 600,
        gains: 2000,
        net: 1400,
      ),
      alerts: const [],
    );
    expect(quests.firstWhere((q) => q.id == 'stretch').complete, isTrue);
    expect(quests.firstWhere((q) => q.id == 'under-budget').complete, isTrue);
  });

  group('sampleStats', () {
    test('computes mean, median, and sample stdev', () {
      final stats = anomalies.sampleStats([10, 20, 30, 40]);
      expect(stats.n, 4);
      expect(stats.mean, 25);
      expect(stats.median, 25);
      expect(stats.stdev, closeTo(12.91, 0.1));
    });
  });

  group('findSpendingAnomalies', () {
    test('flags a category that is far above recent months', () {
      final txs = [
        _tx(id: 'd1', categoryId: 'dining', amount: -50, bookedAt: DateTime(2026, 5, 4)),
        _tx(id: 'd2', categoryId: 'dining', amount: -55, bookedAt: DateTime(2026, 6, 4)),
        _tx(id: 'd3', categoryId: 'dining', amount: -48, bookedAt: DateTime(2026, 7, 4)),
        _tx(id: 'd4', categoryId: 'dining', amount: -52, bookedAt: DateTime(2026, 8, 4)),
        _tx(id: 'd5', categoryId: 'dining', amount: -160, bookedAt: DateTime(2026, 9, 3)),
      ];
      final found = anomalies.findSpendingAnomalies(
        txs: txs,
        viewMonth: '2026-09',
        today: DateTime(2026, 9, 12),
      );
      final dining = found.where(
        (item) =>
            item.kind == AnomalyKind.categorySpike && item.categoryId == 'dining',
      );
      expect(dining, isNotEmpty);
      expect(dining.first.severity, AnomalySeverity.unusual);
      expect(dining.first.message, contains('Restoranai'));
    });

    test('does not flag a stable rent payment', () {
      final months = [4, 5, 6, 7, 8, 9];
      final txs = [
        for (var i = 0; i < months.length; i++)
          _tx(
            id: 'h$i',
            categoryId: 'housing',
            amount: -650,
            bookedAt: DateTime(2026, months[i], 2),
          ),
      ];
      final found = anomalies.findSpendingAnomalies(
        txs: txs,
        viewMonth: '2026-09',
        today: DateTime(2026, 9, 12),
      );
      expect(found.any((item) => item.categoryId == 'housing'), isFalse);
    });

    test('does not flag a modest grocery bump on an otherwise steady category',
        () {
      final txs = [
        _tx(id: 'g1', categoryId: 'dining', amount: -290, bookedAt: DateTime(2026, 5, 4)),
        _tx(id: 'g2', categoryId: 'dining', amount: -294, bookedAt: DateTime(2026, 6, 4)),
        _tx(id: 'g3', categoryId: 'dining', amount: -288, bookedAt: DateTime(2026, 7, 4)),
        _tx(id: 'g4', categoryId: 'dining', amount: -300, bookedAt: DateTime(2026, 8, 4)),
        _tx(id: 'g5', categoryId: 'dining', amount: -340, bookedAt: DateTime(2026, 9, 4)),
      ];
      final found = anomalies.findSpendingAnomalies(
        txs: txs,
        viewMonth: '2026-09',
        today: DateTime(2026, 9, 12),
      );
      expect(found.any((item) => item.categoryId == 'dining'), isFalse);
    });

    test('flags a single charge that is much larger than typical lines', () {
      final txs = [
        _tx(id: 'f1', categoryId: 'leisure', amount: -18, bookedAt: DateTime(2026, 5, 14)),
        _tx(id: 'f2', categoryId: 'leisure', amount: -22, bookedAt: DateTime(2026, 6, 14)),
        _tx(id: 'f3', categoryId: 'leisure', amount: -20, bookedAt: DateTime(2026, 7, 14)),
        _tx(id: 'f4', categoryId: 'leisure', amount: -24, bookedAt: DateTime(2026, 8, 14)),
        _tx(id: 'f5', categoryId: 'leisure', amount: -19, bookedAt: DateTime(2026, 8, 20)),
        _tx(
          id: 'f6',
          categoryId: 'leisure',
          amount: -96,
          bookedAt: DateTime(2026, 9, 10),
          merchant: 'Bilietai.lt',
          description: 'Koncerto bilietai',
        ),
      ];
      final found = anomalies.findSpendingAnomalies(
        txs: txs,
        viewMonth: '2026-09',
        today: DateTime(2026, 9, 12),
      );
      final charge = found.where(
        (item) => item.kind == AnomalyKind.largeCharge && item.transactionId == 'f6',
      );
      expect(charge, isNotEmpty);
      expect(charge.first.message, contains('Koncerto bilietai'));
    });
  });

  group('noticesAfterSync', () {
    ThresholdAlert alert({
      required String budgetId,
      required AlertLevel level,
      required String message,
    }) {
      return ThresholdAlert(
        budgetId: budgetId,
        categoryId: 'dining',
        label: 'Restoranai',
        spent: 130,
        limit: 160,
        warnAt: 0.75,
        ratio: 0.81,
        projected: 200,
        level: level,
        message: message,
      );
    }

    test('opens a notice when a sync finds a budget newly over its warning line',
        () {
      final dining = alert(
        budgetId: 'b-dining',
        level: AlertLevel.warning,
        message: 'Restoranai pasiekė 75%',
      );
      final notices = noticesAfterSync(
        previous: const {},
        alerts: [dining],
        month: '2026-09',
        at: DateTime(2026, 9, 12, 12),
        ids: const ['n1'],
      );
      expect(notices, hasLength(1));
      expect(notices.first.label, 'Restoranai');
      expect(notices.first.level, AlertLevel.warning);
      expect(noticeSnackTitle(notices.first), contains('įspėjimo ribą'));
    });

    test('does not repeat the same warning on a later sync', () {
      final dining = alert(
        budgetId: 'b-dining',
        level: AlertLevel.warning,
        message: 'Restoranai pasiekė 75%',
      );
      final previous = snapshotFromAlerts('2026-09', [dining]);
      final notices = noticesAfterSync(
        previous: previous,
        alerts: [dining],
        month: '2026-09',
        at: DateTime(2026, 9, 12, 12, 1),
        ids: const ['n2'],
      );
      expect(notices, isEmpty);
      expect(snapshotKey('2026-09', 'b-dining'), '2026-09:b-dining');
    });

    test('notifies again when a warning worsens to a breach', () {
      final previous = snapshotFromAlerts('2026-09', [
        alert(
          budgetId: 'b-dining',
          level: AlertLevel.warning,
          message: 'Restoranai pasiekė 75%',
        ),
      ]);
      final notices = noticesAfterSync(
        previous: previous,
        alerts: [
          alert(
            budgetId: 'b-dining',
            level: AlertLevel.breach,
            message: 'Restoranai viršijo biudžetą',
          ),
        ],
        month: '2026-09',
        at: DateTime(2026, 9, 12, 12, 2),
        ids: const ['n3'],
      );
      expect(notices, hasLength(1));
      expect(notices.first.level, AlertLevel.breach);
    });

    test('ignores pace alerts that are not yet over the threshold', () {
      final notices = noticesAfterSync(
        previous: const {},
        alerts: [
          alert(
            budgetId: 'b-dining',
            level: AlertLevel.pace,
            message: 'Restoranai gali viršyti',
          ),
        ],
        month: '2026-09',
        at: DateTime(2026, 9, 12, 12),
        ids: const ['n4'],
      );
      expect(notices, isEmpty);
    });
  });
}

MonthPoint _point(String month, double net) {
  return MonthPoint(
    month: month,
    label: month,
    expenses: 2000 - net,
    gains: 2000,
    net: net,
  );
}

MoneyTx _tx({
  required String id,
  required String categoryId,
  required double amount,
  required DateTime bookedAt,
  String merchant = 'Test',
  String? description,
}) {
  return MoneyTx(
    id: id,
    bookedAt: bookedAt,
    amount: amount,
    currency: 'EUR',
    description: description ?? merchant,
    merchant: merchant,
    bank: BankId.swed,
    personId: Person.meId,
    categoryId: categoryId,
    tag: SpendTag.essential,
    isTransfer: categoryId == 'transfers',
  );
}
