enum BankId {
  artea,
  revolut,
  swed,
  wise;

  String get label => switch (this) {
        BankId.artea => 'Artea',
        BankId.revolut => 'Revolut',
        BankId.swed => 'Swedbank',
        BankId.wise => 'Wise',
      };

  String get shortLabel => switch (this) {
        BankId.artea => 'Artea',
        BankId.revolut => 'Revolut',
        BankId.swed => 'Swed',
        BankId.wise => 'Wise',
      };

  /// Enable Banking ASPSP names. Artea is the Šiaulių bankas rebrand
  /// (BIC CBSBLT26). Live GET /aspsps lookup can override these.
  String get enableBankingAspspName => switch (this) {
        BankId.artea => 'Artea',
        BankId.revolut => 'Revolut',
        BankId.swed => 'Swedbank',
        BankId.wise => 'Wise',
      };

  String get enableBankingCountry => switch (this) {
        BankId.wise => 'GB',
        _ => 'LT',
      };

  List<String> get enableBankingNameHints => switch (this) {
        BankId.artea => const ['artea', 'siauliu', 'šiaulių', 'siauliu bankas'],
        BankId.revolut => const ['revolut'],
        BankId.swed => const ['swedbank'],
        BankId.wise => const ['wise', 'transferwise'],
      };

  String get bic => switch (this) {
        BankId.artea => 'CBSBLT26',
        BankId.revolut => 'REVOLT21',
        BankId.swed => 'HABALT22',
        BankId.wise => 'TRWIGB22',
      };

  static BankId? tryParse(String raw) {
    final value = raw.trim().toLowerCase();
    return switch (value) {
      'artea' || 'siauliu' || 'šiaulių' || 'siauliu bankas' => BankId.artea,
      'revolut' => BankId.revolut,
      'swed' || 'swedbank' => BankId.swed,
      'wise' || 'transferwise' => BankId.wise,
      _ => null,
    };
  }
}
