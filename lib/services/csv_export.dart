import '../models/category.dart';
import '../models/person.dart';
import '../models/transaction.dart';

class CsvExporter {
  const CsvExporter();

  static const bom = '\uFEFF';

  String export({
    required List<MoneyTx> txs,
    required Household household,
  }) {
    final rows = <List<String>>[
      const [
        'Data',
        'Bankas',
        'Žmogus',
        'Kategorija',
        'Žyma',
        'Pardavėjas',
        'Aprašymas',
        'Suma',
        'Valiuta',
        'Perkėlimas',
      ],
    ];

    final sorted = [...txs]..sort((a, b) => a.bookedAt.compareTo(b.bookedAt));
    for (final tx in sorted) {
      rows.add([
        _isoDate(tx.bookedAt),
        tx.bank.label,
        household.byId(tx.personId).name,
        Categories.byId(tx.categoryId).name,
        tx.tag.label,
        tx.merchant,
        tx.description,
        tx.amount.toStringAsFixed(2),
        tx.currency,
        tx.isTransfer ? 'taip' : 'ne',
      ]);
    }

    final buffer = StringBuffer(bom);
    for (final row in rows) {
      buffer.writeln(row.map(_escape).join(','));
    }
    return buffer.toString();
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _escape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains(';')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
