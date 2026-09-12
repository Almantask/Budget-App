enum SpendTag {
  essential,
  optional;

  String get label => switch (this) {
        SpendTag.essential => 'Būtina',
        SpendTag.optional => 'Nebūtina',
      };

  static SpendTag parse(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'optional' || value == 'nebūtina' || value == 'nebutina') {
      return SpendTag.optional;
    }
    return SpendTag.essential;
  }
}
