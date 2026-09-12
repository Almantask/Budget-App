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

  /// GoCardless / Nordigen institution ids. Artea is the Šiaulių bankas rebrand
  /// (BIC CBSBLT26). Live lookup can override these if the catalog changes.
  String get gocardlessInstitutionId => switch (this) {
        BankId.artea => 'SIAULIUBANKAS_CBSBLT26',
        BankId.revolut => 'REVOLUT_REVOLT21',
        BankId.swed => 'SWEDBANK_HABALT22',
        BankId.wise => 'WISE_TRWIGB22',
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
