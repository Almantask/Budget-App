import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/bank.dart';
import '../models/transaction.dart';
import '../services/categorizer.dart';
import 'bank_connector.dart';

/// PSD2 Account Information via Enable Banking.
/// Covers Artea (Šiaulių rebrand), Revolut, Swedbank LT and Wise.
class EnableBankingClient {
  EnableBankingClient({
    http.Client? httpClient,
    this.baseUrl = 'https://api.enablebanking.com',
    this.jwtFactory,
    DateTime Function()? now,
    String Function()? stateFactory,
    this._categorizer = const TransactionCategorizer(),
  })  : _http = httpClient ?? http.Client(),
        _now = now ?? DateTime.now,
        _stateFactory = stateFactory ?? const Uuid().v4;

  final http.Client _http;
  final String baseUrl;
  final TransactionCategorizer _categorizer;
  final DateTime Function() _now;
  final String Function() _stateFactory;

  /// Override JWT creation in tests. Production signs RS256 with the app key.
  final String Function(BankCredentials credentials)? jwtFactory;

  String createJwt(BankCredentials credentials) {
    if (jwtFactory != null) return jwtFactory!(credentials);
    final applicationId = credentials.enableBankingApplicationId?.trim() ?? '';
    final pem = credentials.enableBankingPrivateKey?.trim() ?? '';
    if (applicationId.isEmpty || pem.isEmpty) {
      throw BankSyncException(
        'Trūksta Enable Banking application ID arba RSA privataus rakto',
      );
    }
    final jwt = JWT(
      {
        'iss': 'enablebanking.com',
        'aud': 'api.enablebanking.com',
      },
      header: {'kid': applicationId},
    );
    return jwt.sign(
      RSAPrivateKey(pem),
      algorithm: JWTAlgorithm.RS256,
      expiresIn: const Duration(hours: 1),
    );
  }

  static String extractAuthorizationCode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw BankSyncException('Įklijuokite Enable Banking sutikimo nuorodą arba kodą');
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final queryCode = uri.queryParameters['code'];
      if (queryCode != null && queryCode.isNotEmpty) return queryCode;
      if (uri.hasFragment) {
        final fragment = Uri.splitQueryString(uri.fragment);
        final fragmentCode = fragment['code'];
        if (fragmentCode != null && fragmentCode.isNotEmpty) return fragmentCode;
      }
    }
    return trimmed;
  }

  Future<EnableBankingAspsp> lookupAspsp({
    required BankCredentials credentials,
    required BankId bank,
  }) async {
    final scoped = await _listAspsps(
      credentials: credentials,
      country: bank.enableBankingCountry,
    );
    final match = _matchAspsp(scoped, bank);
    if (match != null) return match;

    final all = await _listAspsps(credentials: credentials);
    final worldwide = _matchAspsp(all, bank);
    if (worldwide != null) return worldwide;

    return EnableBankingAspsp(
      name: bank.enableBankingAspspName,
      country: bank.enableBankingCountry,
      bic: bank.bic,
    );
  }

  Future<BankAuthSession> startAuthorization({
    required BankCredentials credentials,
    required BankId bank,
    required String redirectUri,
    EnableBankingAspsp? aspsp,
  }) async {
    final resolved = aspsp ??
        await lookupAspsp(credentials: credentials, bank: bank);
    final validUntil = _consentValidUntil(resolved);
    final state = _stateFactory();
    final response = await _http.post(
      Uri.parse('$baseUrl/auth'),
      headers: _headers(credentials),
      body: jsonEncode({
        'access': {
          'valid_until': validUntil,
          'balances': true,
          'transactions': true,
        },
        'aspsp': {
          'name': resolved.name,
          'country': resolved.country,
        },
        'state': state,
        'redirect_url': redirectUri,
        'psu_type': 'personal',
        'language': 'lt',
      }),
    );
    _ensureOk(response, 'Nepavyko pradėti ${bank.label} susiejimo');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return BankAuthSession(
      sessionId: body['authorization_id'] as String,
      authorizationUrl: body['url'] as String,
      state: state,
    );
  }

  Future<EnableBankingLinkedSession> authorizeSession({
    required BankCredentials credentials,
    required String code,
  }) async {
    final response = await _http.post(
      Uri.parse('$baseUrl/sessions'),
      headers: _headers(credentials),
      body: jsonEncode({'code': code}),
    );
    _ensureOk(response, 'Nepavyko užbaigti Enable Banking sesijos');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final accounts = body['accounts'] as List<dynamic>? ?? const [];
    String? accountId;
    String? iban;
    String? displayName;
    if (accounts.isNotEmpty) {
      final first = accounts.first as Map<String, dynamic>;
      accountId = first['uid'] as String?;
      displayName = first['name'] as String?;
      final accountIdNode = first['account_id'];
      if (accountIdNode is Map<String, dynamic>) {
        iban = accountIdNode['iban'] as String?;
      }
    }
    return EnableBankingLinkedSession(
      sessionId: body['session_id'] as String,
      accountId: accountId,
      iban: iban,
      displayName: displayName,
    );
  }

  Future<List<String>> listAccountIds({
    required BankCredentials credentials,
    required String sessionId,
  }) async {
    final response = await _http.get(
      Uri.parse('$baseUrl/sessions/$sessionId'),
      headers: _headers(credentials),
    );
    _ensureOk(response, 'Nepavyko nuskaityti susietų sąskaitų');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final accounts = body['accounts'] as List<dynamic>? ?? const [];
    return accounts.map((e) {
      if (e is String) return e;
      if (e is Map<String, dynamic>) {
        return (e['uid'] ?? e['account_id'] ?? e).toString();
      }
      return e.toString();
    }).where((id) => id.isNotEmpty).toList();
  }

  Future<BankSyncResult> fetchTransactions({
    required BankCredentials credentials,
    required String accountId,
    required BankId bank,
    required String personId,
    DateTime? from,
    String Function()? idFactory,
  }) async {
    final txs = <MoneyTx>[];
    String? continuation;
    do {
      final params = <String, String>{
        if (from != null) 'date_from': _dateParam(from),
        'continuation_key': ?continuation,
      };
      final uri = Uri.parse('$baseUrl/accounts/$accountId/transactions')
          .replace(queryParameters: params.isEmpty ? null : params);
      final response = await _http.get(uri, headers: _headers(credentials));
      _ensureOk(response, 'Nepavyko gauti ${bank.label} operacijų');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = body['transactions'] as List<dynamic>? ?? const [];
      var i = txs.length;
      for (final raw in items) {
        final item = raw as Map<String, dynamic>;
        final tx = _mapTransaction(
          item,
          bank: bank,
          personId: personId,
          id: idFactory?.call() ??
              'eb-$accountId-${item['transaction_id'] ?? item['entry_reference'] ?? i}',
        );
        i += 1;
        if (tx == null) continue;
        if (from != null && tx.bookedAt.isBefore(from)) continue;
        txs.add(tx);
      }
      final next = body['continuation_key'] as String?;
      continuation = (next != null && next.isNotEmpty) ? next : null;
    } while (continuation != null);
    return BankSyncResult(bank: bank, transactions: txs);
  }

  Map<String, String> _headers(BankCredentials credentials) => {
        'Authorization': 'Bearer ${createJwt(credentials)}',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<List<Map<String, dynamic>>> _listAspsps({
    required BankCredentials credentials,
    String? country,
  }) async {
    final uri = Uri.parse('$baseUrl/aspsps').replace(
      queryParameters: country == null ? null : {'country': country},
    );
    final response = await _http.get(uri, headers: _headers(credentials));
    if (response.statusCode != 200) return const [];
    final body = jsonDecode(response.body);
    final list = body is Map<String, dynamic>
        ? body['aspsps'] as List<dynamic>? ?? const []
        : body is List
            ? body
            : const [];
    return [
      for (final raw in list)
        if (raw is Map<String, dynamic>) raw,
    ];
  }

  EnableBankingAspsp? _matchAspsp(
    List<Map<String, dynamic>> aspsps,
    BankId bank,
  ) {
    for (final item in aspsps) {
      final bic = (item['bic'] as String? ?? '').toUpperCase();
      final name = (item['name'] as String? ?? '').toLowerCase();
      final hints = bank.enableBankingNameHints;
      final bicHit = bic.contains(bank.bic);
      final nameHit = hints.any(name.contains);
      if (bicHit || nameHit) {
        return EnableBankingAspsp(
          name: item['name'] as String? ?? bank.enableBankingAspspName,
          country: (item['country'] as String?) ?? bank.enableBankingCountry,
          bic: item['bic'] as String?,
          maximumConsentValidity: item['maximum_consent_validity'] as int?,
        );
      }
    }
    return null;
  }

  String _consentValidUntil(EnableBankingAspsp aspsp) {
    final now = _now().toUtc();
    var seconds = 90 * 24 * 60 * 60;
    final max = aspsp.maximumConsentValidity;
    if (max != null && max > 0 && max < seconds) {
      seconds = max;
    }
    return now.add(Duration(seconds: seconds)).toIso8601String();
  }

  String _dateParam(DateTime value) {
    final utc = value.toUtc();
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$month-$day';
  }

  MoneyTx? _mapTransaction(
    Map<String, dynamic> item, {
    required BankId bank,
    required String personId,
    required String id,
  }) {
    final status = (item['status'] as String? ?? 'BOOK').toUpperCase();
    if (status.isNotEmpty &&
        status != 'BOOK' &&
        status != 'BOOKED' &&
        status != 'OTHR') {
      return null;
    }
    final amountNode = item['transaction_amount'] as Map<String, dynamic>?;
    if (amountNode == null) return null;
    var amount = double.tryParse(amountNode['amount']?.toString() ?? '');
    if (amount == null || amount == 0) return null;
    final indicator =
        (item['credit_debit_indicator'] as String? ?? '').toUpperCase();
    if (indicator == 'DBIT' && amount > 0) amount = -amount;
    if (indicator == 'CRDT' && amount < 0) amount = amount.abs();
    final currency = amountNode['currency'] as String? ?? 'EUR';
    final bookedRaw = item['booking_date'] as String? ??
        item['transaction_date'] as String? ??
        item['value_date'] as String?;
    if (bookedRaw == null) return null;
    final bookedAt = DateTime.tryParse(bookedRaw);
    if (bookedAt == null) return null;

    String? partyName(dynamic node) {
      if (node is Map<String, dynamic>) return node['name'] as String?;
      return null;
    }

    final creditor = partyName(item['creditor']);
    final debtor = partyName(item['debtor']);
    final codeNode = item['bank_transaction_code'];
    final codeDescription = codeNode is Map
        ? codeNode['description']?.toString()
        : null;
    final merchant = (amount < 0 ? creditor : debtor) ??
        creditor ??
        debtor ??
        codeDescription ??
        '';
    final remittance = item['remittance_information'];
    final remittanceText = remittance is List
        ? remittance.where((e) => e != null && e.toString().isNotEmpty).join(' ')
        : remittance?.toString() ?? '';
    final description = (remittanceText.isNotEmpty
            ? remittanceText
            : (item['note'] as String? ?? merchant))
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
      externalId: (item['transaction_id'] ?? item['entry_reference'])?.toString(),
    );
  }

  void _ensureOk(http.Response response, String message) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw BankSyncException(
      '$message (${response.statusCode}): ${response.body}',
    );
  }
}
