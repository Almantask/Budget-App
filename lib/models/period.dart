enum PeriodKind {
  week,
  month,
  year,
  allTime;

  String get label => switch (this) {
        PeriodKind.week => 'Savaitė',
        PeriodKind.month => 'Mėnuo',
        PeriodKind.year => 'Metai',
        PeriodKind.allTime => 'Visas laikotarpis',
      };

  String get previousLabel => switch (this) {
        PeriodKind.week => 'praėjusią savaitę',
        PeriodKind.month => 'praėjusį mėnesį',
        PeriodKind.year => 'praėjusiais metais',
        PeriodKind.allTime => 'ankstesniu langu',
      };
}

class DateRange {
  const DateRange(this.start, this.end);

  /// Inclusive start, exclusive end, local dates.
  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  bool contains(DateTime value) {
    return !value.isBefore(start) && value.isBefore(end);
  }

  DateRange get previous {
    final length = duration;
    return DateRange(start.subtract(length), start);
  }

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

class PeriodResolver {
  const PeriodResolver();

  DateRange resolve({
    required PeriodKind kind,
    required DateTime now,
    DateTime? dataStart,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    switch (kind) {
      case PeriodKind.week:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return DateRange(monday, monday.add(const Duration(days: 7)));
      case PeriodKind.month:
        final start = DateTime(now.year, now.month, 1);
        return DateRange(start, DateTime(now.year, now.month + 1, 1));
      case PeriodKind.year:
        return DateRange(
          DateTime(now.year, 1, 1),
          DateTime(now.year + 1, 1, 1),
        );
      case PeriodKind.allTime:
        final start = dataStart == null
            ? DateTime(today.year - 5, 1, 1)
            : DateTime(dataStart.year, dataStart.month, dataStart.day);
        return DateRange(start, today.add(const Duration(days: 1)));
    }
  }
}
