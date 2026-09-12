String monthKey(DateTime value) {
  final date = DateTime(value.year, value.month, value.day);
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

String dateKey(DateTime value) {
  final date = DateTime(value.year, value.month, value.day);
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

int daysInMonth(String month) {
  final parts = month.split('-');
  final year = int.parse(parts[0]);
  final monthPart = int.parse(parts[1]);
  return DateTime(year, monthPart + 1, 0).day;
}

String addMonths(String month, int delta) {
  final parts = month.split('-').map(int.parse).toList();
  final date = DateTime(parts[0], parts[1] + delta, 1);
  return monthKey(date);
}

String startOfMonth(String month) => '$month-01';

String endOfMonth(String month) =>
    '$month-${daysInMonth(month).toString().padLeft(2, '0')}';

String addDays(String iso, int delta) {
  final parts = iso.split('-').map(int.parse).toList();
  final date = DateTime(parts[0], parts[1], parts[2]).add(Duration(days: delta));
  return dateKey(date);
}

List<String> monthsUntil(String endMonth, int count) {
  return [
    for (var i = count - 1; i >= 0; i--) addMonths(endMonth, -i),
  ];
}

double roundMoney(double value) => (value * 100).round() / 100;

double niceAmount(double value) {
  if (value <= 0) return 0;
  if (value < 50) return value.roundToDouble();
  return (value / 10).round() * 10;
}
