import 'dart:math' as math;

import '../models/category.dart';
import '../models/notice.dart';
import '../models/transaction.dart';
import '../ui/theme.dart';
import 'dates.dart';

class SampleStats {
  const SampleStats({
    required this.n,
    required this.mean,
    required this.median,
    required this.stdev,
  });

  final int n;
  final double mean;
  final double median;
  final double stdev;
}

class _Spike {
  const _Spike({required this.severity, required this.multiple});
  final AnomalySeverity severity;
  final double multiple;
}

class AnomalyEngine {
  const AnomalyEngine();

  SampleStats sampleStats(List<double> values) {
    final n = values.length;
    if (n == 0) {
      return const SampleStats(n: 0, mean: 0, median: 0, stdev: 0);
    }
    final sorted = [...values]..sort();
    final mean = values.reduce((a, b) => a + b) / n;
    final mid = sorted.length ~/ 2;
    final median = sorted.length.isEven
        ? (sorted[mid - 1] + sorted[mid]) / 2
        : sorted[mid];
    final variance = n < 2
        ? 0.0
        : values.fold<double>(0, (sum, value) => sum + (value - mean) * (value - mean)) /
            (n - 1);
    return SampleStats(
      n: n,
      mean: mean,
      median: median,
      stdev: variance <= 0 ? 0 : math.sqrt(variance),
    );
  }

  String asOfDate(String viewMonth, DateTime today) {
    return monthKey(today) == viewMonth ? dateKey(today) : endOfMonth(viewMonth);
  }

  List<String> priorMonths(String viewMonth, {int count = 8}) {
    return [for (var i = count; i >= 1; i--) addMonths(viewMonth, -i)];
  }

  bool isStableBill(SampleStats stats) {
    return stats.n >= 3 && stats.mean > 0 && stats.stdev / stats.mean < 0.12;
  }

  _Spike? _classifySpike(double current, SampleStats baseline) {
    if (baseline.n < 3 || current < 30) return null;
    final multiple = baseline.median > 0 ? current / baseline.median : 0.0;
    final z = baseline.stdev > 1 ? (current - baseline.mean) / baseline.stdev : 0.0;
    final delta = current - baseline.median;
    if (delta < 40 || multiple < 1.25) return null;
    if (isStableBill(baseline) && multiple < 1.5) return null;
    if (multiple >= 1.75 || (z >= 2.15 && multiple >= 1.5)) {
      return _Spike(severity: AnomalySeverity.unusual, multiple: multiple);
    }
    if (multiple >= 1.35 || z >= 1.4) {
      return _Spike(severity: AnomalySeverity.watch, multiple: multiple);
    }
    return null;
  }

  _Spike? _classifyCharge(double amount, SampleStats baseline) {
    if (baseline.n < 4 || amount < 40) return null;
    final multiple = baseline.median > 0 ? amount / baseline.median : 0.0;
    final z = baseline.stdev > 1 ? (amount - baseline.mean) / baseline.stdev : 0.0;
    if (amount - baseline.median < 25) return null;
    if (multiple < 1.8) return null;
    if (multiple >= 2.5 || z >= 2.4) {
      return _Spike(severity: AnomalySeverity.unusual, multiple: multiple);
    }
    if (multiple >= 2.1 || z >= 2) {
      return _Spike(severity: AnomalySeverity.watch, multiple: multiple);
    }
    return null;
  }

  double spentThrough(
    List<MoneyTx> txs,
    String month,
    String throughDate, {
    String? categoryId,
  }) {
    var total = 0.0;
    for (final tx in txs) {
      if (!tx.isExpense) continue;
      if (monthKey(tx.bookedAt) != month) continue;
      if (dateKey(tx.bookedAt).compareTo(throughDate) > 0) continue;
      if (categoryId != null && tx.categoryId != categoryId) continue;
      total += tx.absAmount;
    }
    return roundMoney(total);
  }

  List<SpendingAnomaly> findSpendingAnomalies({
    required List<MoneyTx> txs,
    required String viewMonth,
    required DateTime today,
  }) {
    final through = asOfDate(viewMonth, today);
    final history = priorMonths(viewMonth);
    final pointInMonth = monthKey(today) == viewMonth;
    final anomalies = <SpendingAnomaly>[];

    final overallHistory = history
        .map((month) => spentThrough(txs, month, endOfMonth(month)))
        .where((value) => value > 0)
        .toList();
    final overallNow = spentThrough(txs, viewMonth, through);
    final overallStats = sampleStats(overallHistory);
    final overallSpike = _classifySpike(overallNow, overallStats);
    if (overallSpike != null) {
      anomalies.add(
        SpendingAnomaly(
          id: 'month-spike:$viewMonth',
          kind: AnomalyKind.monthSpike,
          severity: overallSpike.severity,
          categoryId: 'overall',
          label: 'Visos išlaidos',
          month: viewMonth,
          amount: overallNow,
          baseline: overallStats.median,
          multiple: overallSpike.multiple,
          message: _monthSpikeMessage(
            overallNow,
            overallStats.median,
            overallSpike.multiple,
            pointInMonth,
            viewMonth,
          ),
        ),
      );
    }

    for (final category in Categories.spendable) {
      final prior = history
          .map(
            (month) => spentThrough(
              txs,
              month,
              endOfMonth(month),
              categoryId: category.id,
            ),
          )
          .where((value) => value > 0)
          .toList();
      final current = spentThrough(
        txs,
        viewMonth,
        through,
        categoryId: category.id,
      );
      final stats = sampleStats(prior);
      final spike = _classifySpike(current, stats);
      if (spike != null) {
        anomalies.add(
          SpendingAnomaly(
            id: 'category-spike:${category.id}:$viewMonth',
            kind: AnomalyKind.categorySpike,
            severity: spike.severity,
            categoryId: category.id,
            label: category.name,
            month: viewMonth,
            amount: current,
            baseline: stats.median,
            multiple: spike.multiple,
            message: _categorySpikeMessage(
              category.name,
              current,
              stats.median,
              spike.multiple,
              pointInMonth,
            ),
          ),
        );
      }

      if (category.id == 'housing' || category.id == 'utilities') {
        continue;
      }

      final historyCharges = txs
          .where(
            (tx) =>
                tx.isExpense &&
                tx.categoryId == category.id &&
                monthKey(tx.bookedAt).compareTo(viewMonth) < 0,
          )
          .map((tx) => tx.absAmount)
          .toList();
      final chargeStats = sampleStats(historyCharges);
      final monthCharges = txs.where(
        (tx) =>
            tx.isExpense &&
            tx.categoryId == category.id &&
            monthKey(tx.bookedAt) == viewMonth &&
            dateKey(tx.bookedAt).compareTo(through) <= 0,
      );
      for (final tx in monthCharges) {
        final charge = _classifyCharge(tx.absAmount, chargeStats);
        if (charge == null) continue;
        anomalies.add(
          SpendingAnomaly(
            id: 'large-charge:${tx.id}',
            kind: AnomalyKind.largeCharge,
            severity: charge.severity,
            categoryId: category.id,
            label: category.name,
            month: viewMonth,
            amount: tx.absAmount,
            baseline: chargeStats.median,
            multiple: charge.multiple,
            message: _chargeMessage(
              category.name,
              tx,
              chargeStats.median,
              charge.multiple,
            ),
            transactionId: tx.id,
          ),
        );
      }
    }

    anomalies.sort((a, b) {
      final rank = _rank(b.severity) - _rank(a.severity);
      if (rank != 0) return rank;
      return b.amount.compareTo(a.amount);
    });
    return anomalies;
  }

  String _categorySpikeMessage(
    String name,
    double current,
    double baseline,
    double multiple,
    bool pointInMonth,
  ) {
    final timing = pointInMonth
        ? 'iki šios mėnesio dienos'
        : 'per visą mėnesį';
    return '$name yra ${multiple.toStringAsFixed(1)}× įprastos ${formatEur(baseline)} $timing (${formatEur(current)} vs ${formatEur(baseline)}).';
  }

  String _monthSpikeMessage(
    double current,
    double baseline,
    double multiple,
    bool pointInMonth,
    String viewMonth,
  ) {
    final extra = current - baseline;
    if (pointInMonth) {
      return 'Bendros išlaidos jau ${formatEur(extra)} viršija įprastą mėnesį (${formatEur(current)} vs ${formatEur(baseline)}).';
    }
    return '${_monthLabel(viewMonth)} išlaidos yra ${multiple.toStringAsFixed(1)}× įprastos ${formatEur(baseline)}.';
  }

  String _chargeMessage(
    String name,
    MoneyTx tx,
    double baseline,
    double multiple,
  ) {
    final note = tx.description.isNotEmpty &&
            tx.description.toLowerCase() != tx.merchant.toLowerCase()
        ? ' „${tx.description}“'
        : '';
    return '$name$note turi ${formatEur(tx.absAmount)} mokėjimą — apie ${multiple.toStringAsFixed(1)}× įprastos ${formatEur(baseline)} eilutės.';
  }

  String _monthLabel(String month) {
    final parts = month.split('-');
    return '${parts[1]}.${parts[0]}';
  }

  int _rank(AnomalySeverity severity) =>
      severity == AnomalySeverity.unusual ? 2 : 1;
}
