import 'package:uuid/uuid.dart';

import '../models/bank.dart';
import '../models/transaction.dart';
import 'categorizer.dart';

class CsvImportResult {
  const CsvImportResult({required this.transactions, required this.bank});

  final List<MoneyTx> transactions;
  final BankId bank;
}

class BankCsvImporter {
  BankCsvImporter({
    this._categorizer = const TransactionCategorizer(),
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final TransactionCategorizer _categorizer;
  final Uuid _uuid;

  CsvImportResult parse({
    required String csv,
    required BankId fallbackBank,
    required String defaultPersonId,
  }) {
    final table = _parseTable(csv);
    if (table.isEmpty) {
      return CsvImportResult(transactions: const [], bank: fallbackBank);
    }
    final headers = table.first.map((h) => h.trim().toLowerCase()).toList();
    final bank = _detectBank(headers) ?? fallbackBank;
    final txs = <MoneyTx>[];

    for (var i = 1; i < table.length; i++) {
      final row = table[i];
      if (row.every((c) => c.trim().isEmpty)) continue;
      final mapped = _mapRow(headers, row, bank);
      if (mapped == null) continue;
      final cat = _categorizer.categorize(
        description: mapped.description,
        merchant: mapped.merchant,
        amount: mapped.amount,
      );
      txs.add(
        MoneyTx(
          id: _uuid.v4(),
          bookedAt: mapped.bookedAt,
          amount: mapped.amount,
          currency: mapped.currency,
          description: mapped.description,
          merchant: mapped.merchant,
          bank: bank,
          personId: defaultPersonId,
          categoryId: cat.categoryId,
          tag: cat.tag,
          isTransfer: cat.isTransfer,
          externalId: mapped.externalId,
        ),
      );
    }

    return CsvImportResult(transactions: txs, bank: bank);
  }

  BankId? _detectBank(List<String> headers) {
    final joined = headers.join('|');
    if (joined.contains('started date') && joined.contains('product')) {
      return BankId.revolut;
    }
    if (joined.contains('transferwise') ||
        joined.contains('exchange from') ||
        (joined.contains('payee name') && joined.contains('merchant'))) {
      return BankId.wise;
    }
    if (joined.contains('gavėjas') ||
        joined.contains('gavejas') ||
        joined.contains('beneficiary') ||
        joined.contains('mokėtojas')) {
      return BankId.swed;
    }
    if (joined.contains('kontrahentas') || joined.contains('paskirtis')) {
      return BankId.artea;
    }
    return null;
  }

  _MappedRow? _mapRow(List<String> headers, List<String> row, BankId bank) {
    String col(List<String> names) {
      for (final name in names) {
        final idx = headers.indexWhere((h) => h == name || h.contains(name));
        if (idx >= 0 && idx < row.length) return row[idx].trim();
      }
      return '';
    }

    final dateRaw = col([
      'completed date',
      'started date',
      'date',
      'data',
      'booking date',
      'booked',
    ]);
    final bookedAt = _parseDate(dateRaw);
    if (bookedAt == null) return null;

    final amountRaw = col(['amount', 'suma', 'sum']);
    final amount = _parseAmount(amountRaw);
    if (amount == null || amount == 0) return null;

    final currency = col(['currency', 'valiuta']).isEmpty
        ? 'EUR'
        : col(['currency', 'valiuta']);
    final description = col([
      'description',
      'details',
      'paaiškinimas',
      'paaiskinimas',
      'paskirtis',
      'payment reference',
      'note',
    ]);
    final merchant = col([
      'merchant',
      'gavėjas',
      'gavejas',
      'beneficiary',
      'payee name',
      'kontrahentas',
      'payer',
    ]);
    final external = col(['id', 'transferwise id', 'transaction id']);

    return _MappedRow(
      bookedAt: bookedAt,
      amount: amount,
      currency: currency.toUpperCase(),
      description: description.isEmpty ? merchant : description,
      merchant: merchant.isEmpty ? description : merchant,
      externalId: external.isEmpty
          ? '$bank|$bookedAt|$amount|$description|$merchant'
          : external,
    );
  }

  DateTime? _parseDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final iso = DateTime.tryParse(value.replaceFirst(' ', 'T'));
    if (iso != null) return iso;
    final parts = value.split(RegExp(r'[./-]'));
    if (parts.length >= 3) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      if (a == null || b == null || c == null) return null;
      if (parts[0].length == 4) {
        return DateTime(a, b, c);
      }
      // LT often DD.MM.YYYY
      return DateTime(c, b, a);
    }
    return null;
  }

  double? _parseAmount(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    value = value.replaceAll(' ', '').replaceAll('\u00a0', '');
    if (value.contains(',') && value.contains('.')) {
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else if (value.contains(',')) {
      value = value.replaceAll(',', '.');
    }
    return double.tryParse(value);
  }

  List<List<String>> _parseTable(String csv) {
    final normalized = csv.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final firstLine = normalized.split('\n').first;
    final delimiter = _detectDelimiter(firstLine);
    final rows = <List<String>>[];
    var current = <String>[];
    var field = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < normalized.length; i++) {
      final ch = normalized[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < normalized.length && normalized[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == delimiter) {
          current.add(field.toString());
          field = StringBuffer();
        } else if (ch == '\n') {
          current.add(field.toString());
          field = StringBuffer();
          rows.add(current);
          current = <String>[];
        } else {
          field.write(ch);
        }
      }
    }
    if (field.isNotEmpty || current.isNotEmpty) {
      current.add(field.toString());
      rows.add(current);
    }
    return rows;
  }

  String _detectDelimiter(String headerLine) {
    final commas = ','.allMatches(headerLine).length;
    final semis = ';'.allMatches(headerLine).length;
    return semis > commas ? ';' : ',';
  }
}

class _MappedRow {
  const _MappedRow({
    required this.bookedAt,
    required this.amount,
    required this.currency,
    required this.description,
    required this.merchant,
    required this.externalId,
  });

  final DateTime bookedAt;
  final double amount;
  final String currency;
  final String description;
  final String merchant;
  final String externalId;
}
