class StretchGoal {
  const StretchGoal({
    required this.month,
    required this.target,
    required this.baseline,
    required this.reason,
  });

  final String month;
  final double target;
  final double baseline;
  final String reason;
}

class StretchHit {
  const StretchHit({
    required this.month,
    required this.hit,
    required this.goal,
    required this.net,
  });

  final String month;
  final bool hit;
  final StretchGoal goal;
  final double net;
}

class Quest {
  const Quest({
    required this.id,
    required this.title,
    required this.detail,
    required this.xp,
    required this.current,
    required this.target,
    required this.unit,
    required this.complete,
  });

  final String id;
  final String title;
  final String detail;
  final int xp;
  final double current;
  final double target;
  final String unit;
  final bool complete;
}

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.detail,
    required this.xp,
    required this.unlocked,
  });

  final String id;
  final String title;
  final String detail;
  final int xp;
  final bool unlocked;

  Achievement copyWith({bool? unlocked}) => Achievement(
        id: id,
        title: title,
        detail: detail,
        xp: xp,
        unlocked: unlocked ?? this.unlocked,
      );
}

class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.intoLevel,
    required this.toNext,
    required this.progress,
    required this.totalXp,
  });

  final int level;
  final int intoLevel;
  final int toNext;
  final double progress;
  final int totalXp;
}
