import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bank.dart';
import '../models/transaction.dart';
import '../services/categorizer.dart';
import 'bank_connector.dart';

/// PSD2 Account Information via GoCardless Bank Account Data (ex-Nordigen).
/// Covers Artea (Šiaulių rebrand), Revolut, Swedbank LT and Wise.
class GoCardlessClient {
  GoCardlessClient({
    http.Client? httpClient,
    this.baseUrl = 'https://bankaccountdata.gocardless.com/api/v2',
    this._categorizer = const TransactionCategorizer(),
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final String baseUrl;
  final TransactionCategorizer _categorizer;

  Future<String> createAccessToken({
    required String secretId,
    required String secretKey,
  }) async {
    final response = await _http.post(
      Uri.parse('$baseUrl/token/new/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'secret_id': secretId, 'secret_key': secretKey}),
    );
    _ensureOk(response, 'Nepavyko gauti GoCardless prieigos rakto');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['access'] as String;
  }

  Future<String?> lookupInstitutionId({
    required String accessToken,
    required BankId bank,
  }) async {
    final response = await _http.get(
      Uri.parse('$baseUrl/institutions/?country=LT'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) return bank.gocardlessInstitutionId;
    final list = jsonDecode(response.body) as List<dynamic>;
    for (final raw in list) {
      final item = raw as Map<String, dynamic>;
      final id = (item['id'] as String? ?? '').toUpperCase();
      final bic = (item['bic'] as String? ?? '').toUpperCase();
      final name = (item['name'] as String? ?? '').toLowerCase();
      if (bic.contains(bank.bic) ||
          id.contains(bank.gocardlessInstitutionId) ||
          name.contains(bank.label.toLowerCase())) {
        return item['id'] as String;
      }
    }
    return bank.gocardlessInstitutionId;
  }

  Future<BankAuthSession> createRequisition({
    required String accessToken,
    required BankId bank,
    required String redirectUri,
    String? institutionId,
  }) async {
    final inst = institutionId ?? bank.gocardlessInstitutionId;
    final response = await _http.post(
      Uri.parse('$baseUrl/requisitions/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'redirect': redirectUri,
        'institution_id': inst,
        'user_language': 'LT',
        'account_selection': false,
      }),
    );
    _ensureOk(response, 'Nepavyko pradėti ${bank.label} susiejimo');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return BankAuthSession(
      sessionId: body['id'] as String,
      authorizationUrl: body['link'] as String,
    );
  }

  Future<List<String>> listAccountIds({
    required String accessToken,
    required String requisitionId,
  }) async {
    final response = await _http.get(
      Uri.parse('$baseUrl/requisitions/$requisitionId/'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    _ensureOk(response, 'Nepavyko nuskaityti susietų sąskaitų');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final accounts = body['accounts'] as List<dynamic>? ?? const [];
    return accounts.map((e) => e.toString()).toList();
  }

  Future<BankSyncResult> fetchTransactions({
    required String accessToken,
    required String accountId,
    required BankId bank,
    required String personId,
    DateTime? from,
    String Function()? idFactory,
  }) async {
    final uri = Uri.parse('$baseUrl/accounts/$accountId/transactions/');
    final response = await _http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    _ensureOk(response, 'Nepavyko gauti ${bank.label} operacijų');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final booked = (body['transactions'] as Map<String, dynamic>?)?['booked']
            as List<dynamic>? ??
        const [];
    final txs = <MoneyTx>[];
    var i = 0;
    for (final raw in booked) {
      final item = raw as Map<String, dynamic>;
      final tx = _mapTransaction(
        item,
        bank: bank,
        personId: personId,
        id: idFactory?.call() ?? 'gc-$accountId-${item['transactionId'] ?? i}',
      );
      i += 1;
      if (tx == null) continue;
      if (from != null && tx.bookedAt.isBefore(from)) continue;
      txs.add(tx);
    }
    return BankSyncResult(bank: bank, transactions: txs);
  }

  MoneyTx? _mapTransaction(
    Map<String, dynamic> item, {
    required BankId bank,
    required String personId,
    required String id,
  }) {
    final amountNode = item['transactionAmount'] as Map<String, dynamic>?;
    if (amountNode == null) return null;
    final amount = double.tryParse(amountNode['amount']?.toString() ?? '');
    if (amount == null || amount == 0) return null;
    final currency = amountNode['currency'] as String? ?? 'EUR';
    final bookedRaw =
        item['bookingDateTime'] as String? ?? item['bookingDate'] as String?;
    if (bookedRaw == null) return null;
    final bookedAt = DateTime.tryParse(bookedRaw);
    if (bookedAt == null) return null;
    final merchant = (item['creditorName'] ??
            item['debtorName'] ??
            item['proprietaryBankTransactionCode'] ??
            '')
        .toString();
    final description = (item['remittanceInformationUnstructured'] ??
            (item['remittanceInformationUnstructuredArray'] is List
                ? (item['remittanceInformationUnstructuredArray'] as List)
                    .join(' ')
                : '') ??
            merchant)
        .toString();
    final cat = _categorizer.categorize(
      description: description,
      merchant: merchant,
      amount: amount,
    );
    return MoneyTx(
      id: id,
      bookedAt: bookedAt,
      amount: amount,
      currency: currency,
      description: description,
      merchant: merchant,
      bank: bank,
      personId: personId,
      categoryId: cat.categoryId,
      tag: cat.tag,
      isTransfer: cat.isTransfer,
      externalId: (item['transactionId'] ?? item['internalTransactionId'])
          ?.toString(),
    );
  }

  void _ensureOk(http.Response response, String message) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw BankSyncException('$message (${response.statusCode}): ${response.body}');
  }
}

class BankSyncException implements Exception {
  BankSyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

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
