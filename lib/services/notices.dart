import '../models/notice.dart';

const _rank = <AlertLevel, int>{
  AlertLevel.ok: 0,
  AlertLevel.pace: 1,
  AlertLevel.warning: 2,
  AlertLevel.breach: 3,
};

String snapshotKey(String month, String budgetId) => '$month:$budgetId';

Map<String, String> snapshotFromAlerts(
  String month,
  List<ThresholdAlert> alerts,
) {
  return {
    for (final alert in alerts)
      snapshotKey(month, alert.budgetId): alert.level.name,
  };
}

List<ThresholdNotice> noticesAfterSync({
  required Map<String, String> previous,
  required List<ThresholdAlert> alerts,
  required String month,
  required DateTime at,
  List<String> ids = const [],
}) {
  final notices = <ThresholdNotice>[];
  var idIndex = 0;
  for (final alert in alerts) {
    if (alert.level != AlertLevel.warning &&
        alert.level != AlertLevel.breach) {
      continue;
    }
    final key = snapshotKey(month, alert.budgetId);
    final beforeName = previous[key] ?? AlertLevel.ok.name;
    final before = AlertLevel.values.firstWhere(
      (level) => level.name == beforeName,
      orElse: () => AlertLevel.ok,
    );
    if ((_rank[alert.level] ?? 0) <= (_rank[before] ?? 0)) continue;
    final id = idIndex < ids.length
        ? ids[idIndex]
        : '$key-${alert.level.name}-${at.toIso8601String()}';
    idIndex += 1;
    notices.add(
      ThresholdNotice(
        id: id,
        at: at,
        month: month,
        budgetId: alert.budgetId,
        categoryId: alert.categoryId,
        label: alert.label,
        level: alert.level,
        message: alert.message,
      ),
    );
  }
  return notices;
}

String noticeSnackTitle(ThresholdNotice notice) {
  if (notice.level == AlertLevel.breach) {
    return '${notice.label} viršijo biudžetą';
  }
  return '${notice.label} pasiekė įspėjimo ribą';
}
