import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bank.dart';
import '../models/transaction.dart';
import '../services/categorizer.dart';
import 'bank_connector.dart';

/// Wise personal API — used when the user pastes a Wise token instead of PSD2.
class WiseApiClient {
  WiseApiClient({
    http.Client? httpClient,
    this.baseUrl = 'https://api.transferwise.com',
    this._categorizer = const TransactionCategorizer(),
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final String baseUrl;
  final TransactionCategorizer _categorizer;

  Future<BankSyncResult> pull({
    required String token,
    required String personId,
    DateTime? from,
    String Function()? idFactory,
  }) async {
    final profiles = await _http.get(
      Uri.parse('$baseUrl/v1/profiles'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (profiles.statusCode < 200 || profiles.statusCode >= 300) {
      throw BankSyncException(
        'Wise profilio nepavyko gauti (${profiles.statusCode})',
      );
    }
    final list = jsonDecode(profiles.body) as List<dynamic>;
    if (list.isEmpty) {
      return const BankSyncResult(bank: BankId.wise, transactions: []);
    }
    final profileId = (list.first as Map<String, dynamic>)['id'];
    final statement = await _http.get(
      Uri.parse('$baseUrl/v1/profiles/$profileId/borderless-accounts'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (statement.statusCode < 200 || statement.statusCode >= 300) {
      throw BankSyncException('Wise sąskaitų nepavyko gauti');
    }
    // Statement endpoint varies by account; map whatever transaction-like maps we find.
    final txs = <MoneyTx>[];
    final decoded = jsonDecode(statement.body);
    final accounts = decoded is List ? decoded : const [];
    for (final account in accounts) {
      final map = account as Map<String, dynamic>;
      final balances = map['balances'] as List<dynamic>? ?? const [];
      for (final balance in balances) {
        final b = balance as Map<String, dynamic>;
        final bankTx = b['transactions'] as List<dynamic>? ?? const [];
        for (final raw in bankTx) {
          final item = raw as Map<String, dynamic>;
          final amount =
              (item['amount'] as num?)?.toDouble() ??
                  double.tryParse(item['amount']?.toString() ?? '');
          if (amount == null || amount == 0) continue;
          final date = DateTime.tryParse(
            item['date']?.toString() ?? item['created']?.toString() ?? '',
          );
          if (date == null) continue;
          if (from != null && date.isBefore(from)) continue;
          final details =
              (item['details'] as Map<String, dynamic>?) ?? const {};
          final merchant =
              (details['merchant'] ?? details['payeeName'] ?? 'Wise')
                  .toString();
          final description =
              (item['reference'] ?? details['type'] ?? merchant).toString();
          final cat = _categorizer.categorize(
            description: description,
            merchant: merchant,
            amount: amount,
          );
          txs.add(
            MoneyTx(
              id: idFactory?.call() ?? 'wise-${item['id'] ?? date}',
              bookedAt: date,
              amount: amount,
              currency: (item['currency'] ?? b['currency'] ?? 'EUR').toString(),
              description: description,
              merchant: merchant,
              bank: BankId.wise,
              personId: personId,
              categoryId: cat.categoryId,
              tag: cat.tag,
              isTransfer: cat.isTransfer,
              externalId: item['id']?.toString(),
            ),
          );
        }
      }
    }
    return BankSyncResult(bank: BankId.wise, transactions: txs);
  }
}
