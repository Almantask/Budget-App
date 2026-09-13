import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_app/banks/bank_connector.dart';
import 'package:budget_app/banks/enable_banking_callback.dart';
import 'package:budget_app/banks/enable_banking_client.dart';
import 'package:budget_app/banks/sync_scheduler.dart';
import 'package:budget_app/banks/sync_service.dart';
import 'package:budget_app/data/budget_store.dart';
import 'package:budget_app/models/bank.dart';
import 'package:budget_app/models/connected_account.dart';
import 'package:budget_app/models/person.dart';
import 'package:budget_app/models/spend_tag.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/state/budget_controller.dart';

const _testPrivateKey = '''
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC9KVmrLz4/FL0x
fJYJ6BmOoUQSPBOH0TTxS/IaZIPr4A0pH5vsxHvhWTNchNvLCd21CPndLUHvriFf
KHcDDUj+onsrMlQUaEQJBy+D5whR2m5mugBYMK6h+Mn1T6rPl9ywb4qpkMkCEdNq
rG5KY/pAdWdNDayoSl0JiIL8KgTfK7kvF8GxgDejcvOIuKVqxKlcg7y0eHoQnsDz
W/9WS435FV5H6aU40+FkQc4ofeO33xRlT16T1gfkMrdiyCILX2HtdROfVC8IpQQD
A5sxd2DxS+YPgpcu+G5EKFG6xp1/uQyuPzGzy3hPfCMNbXGBridwopc51D+ZMiUB
gNEl1+dJAgMBAAECggEABEoZYZGAD7niiupcdCPOXY7AXon8duRadxzN5AWSvMDv
R3cTJ/iyJvNo/+B24/korQPjt51gvQTFtrTSExCEbtrEIIADClXtcgd2zz7IUGPb
xEpUOuu6sAtWWBDbCptS2rDi0/LHrht1n/oCQ79V48uNwMBuQYAzMSXGc52nz+Ax
0T2+jXKOJZw1m382EgCvhKTV+eR3dCf9CpIqPJqhJ4L4BQvSZ54mVnipHq9XFS+A
dMv5eovsOgvd9B2GUTFcYkXL/oh++mekdCqhxAFLtcdbckRIXvJ3zrrcR07gq/5d
0P6ifIFu3a9hFzkemlbDTe5cn2giTbLkQR1JRV3C0QKBgQDrsHKdzYhHgGPzfv6Z
ArSWSAuGkYfg7fWuIJNfA+1ZORYHQdKb1ksMSiUW+CXKggrE67crRQ0Lx1O3AB4p
KxGgOVDQs1se4c1YJp3d3DrtopbrtCDZa/irQuzeI6VENZJ2zSo/SLhTPWoGOHcS
qrax5s+xUD4fImcUFufqAIzJWQKBgQDNdnO8sfkVo712TVO24rYAHh6om2cNsPUM
nJ2NIgzw4HJ9ivkM4jD8yX6muLdl+B/HbJnPm81lHFEPKOVe1pVcTj1+nhzvLlYn
9tMX5YlT1etlGAKbw+5iWrbESWR9mBeAm4TKQesjU9/7AhnzW0kV8ZT2GgiOsjt+
0TmZJnNfcQKBgQCxYurQ4/k2v2X6xND//m5GUVEDZhLbcp2fAXuJXp5LsdBng93s
VhvD0yYZJIjk4n0SesowcdcAz3OtXxRULcslSR4PBX6GPrJbLy1P5sofQmjOW5MB
sObGlydJhZCERsHGUmICoUvBso5Swjq0PPIl8S7OKDOpIS5ti1Pe5a0QeQKBgBva
5EP/yOozIbuJLkFMKSqI6tUnBGipxf8ouH9qz2BUvZDhp3QkskmDM8V8o3iSlBRg
V9X6pHUByseIXthltSgnf1TMMNYIbSvL3cCOoPiZtukkwS3G+WmiLMcdwB764KzR
6MXW+/71HxeTqFsC1DzCXNSkoOZfqYs+6FUoDloxAoGBANZbJbT+DG0i7JCwory5
jgDtwGZAKPTjXYIluV4b6grHytIp/qPF66fjcTZV2q706UgiV3yyf4jYDVlC2q77
vju9xf2AX6w2VrhsIZTCTLUOlOsSlEPIiwndUVOWSbrjB8/JOK+d2fOGHe+lF5M/
NhT9GnczbMcXChUNXGpw5Kxd
-----END PRIVATE KEY-----
''';

const _credentials = BankCredentials(
  enableBankingApplicationId: 'app-123',
  enableBankingPrivateKey: _testPrivateKey,
);

EnableBankingClient _client(MockClient httpClient) {
  return EnableBankingClient(
    httpClient: httpClient,
    jwtFactory: (_) => 'test-jwt',
    now: () => DateTime.utc(2026, 9, 12, 12),
    stateFactory: () => 'state-1',
  );
}

void main() {
  test('Enable Banking maps booked PSD2 transactions', () async {
    final client = _client(
      MockClient((request) async {
        expect(request.url.path, contains('/accounts/acc-1/transactions'));
        expect(request.headers['Authorization'], 'Bearer test-jwt');
        return http.Response(
          jsonEncode({
            'transactions': [
              {
                'transaction_id': 't1',
                'booking_date': '2026-09-10',
                'credit_debit_indicator': 'DBIT',
                'status': 'BOOK',
                'transaction_amount': {'amount': '15.20', 'currency': 'EUR'},
                'creditor': {'name': 'Maxima'},
                'remittance_information': ['Pirkimas'],
              }
            ],
          }),
          200,
        );
      }),
    );

    final result = await client.fetchTransactions(
      credentials: _credentials,
      accountId: 'acc-1',
      bank: BankId.swed,
      personId: Person.meId,
    );
    expect(result.transactions, hasLength(1));
    expect(result.transactions.first.merchant, 'Maxima');
    expect(result.transactions.first.amount, -15.20);
    expect(result.transactions.first.categoryId, 'groceries');
    expect(result.transactions.first.tag, SpendTag.essential);
  });

  test('Enable Banking looks up Lithuanian ASPSP by BIC', () async {
    final client = _client(
      MockClient((request) async {
        expect(request.url.path, contains('/aspsps'));
        expect(request.url.queryParameters['country'], 'LT');
        return http.Response(
          jsonEncode({
            'aspsps': [
              {'name': 'Swedbank', 'bic': 'HABALT22', 'country': 'LT'},
              {'name': 'Siauliu Bankas', 'bic': 'CBSBLT26', 'country': 'LT'},
            ],
          }),
          200,
        );
      }),
    );
    final aspsp = await client.lookupAspsp(
      credentials: _credentials,
      bank: BankId.artea,
    );
    expect(aspsp.name, 'Siauliu Bankas');
    expect(aspsp.country, 'LT');
  });

  test('Enable Banking starts auth with ASPSP name and redirect', () async {
    final client = _client(
      MockClient((request) async {
        if (request.url.path.endsWith('/aspsps')) {
          return http.Response(
            jsonEncode({
              'aspsps': [
                {'name': 'Swedbank', 'bic': 'HABALT22', 'country': 'LT'},
              ],
            }),
            200,
          );
        }
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/auth'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['aspsp'], {'name': 'Swedbank', 'country': 'LT'});
        expect(body['redirect_url'], EnableBankingCallback.hostedRedirectUri);
        expect(body['state'], 'state-1');
        expect(body['psu_type'], 'personal');
        expect((body['access'] as Map)['transactions'], isTrue);
        return http.Response(
          jsonEncode({
            'url': 'https://auth.enablebanking.com/ais/start?sessionid=auth-1',
            'authorization_id': 'auth-1',
          }),
          200,
        );
      }),
    );
    final session = await client.startAuthorization(
      credentials: _credentials,
      bank: BankId.swed,
      redirectUri: BankCredentials.defaultRedirectUri,
    );
    expect(session.sessionId, 'auth-1');
    expect(session.state, 'state-1');
    expect(session.authorizationUrl, contains('auth.enablebanking.com'));
  });

  test('Enable Banking exchanges callback code for a session', () async {
    final client = _client(
      MockClient((request) async {
        expect(request.url.path, endsWith('/sessions'));
        expect(jsonDecode(request.body), {'code': 'auth-code'});
        return http.Response(
          jsonEncode({
            'session_id': 'sess-1',
            'accounts': [
              {
                'uid': 'acc-uuid',
                'name': 'Einamoji',
                'account_id': {'iban': 'LT123'},
              }
            ],
          }),
          200,
        );
      }),
    );
    final linked = await client.authorizeSession(
      credentials: _credentials,
      code: EnableBankingClient.extractAuthorizationCode(
        'budgetapp://enable-banking/callback?code=auth-code&state=state-1',
      ),
    );
    expect(linked.sessionId, 'sess-1');
    expect(linked.accountId, 'acc-uuid');
    expect(linked.iban, 'LT123');
  });

  test('extractAuthorizationCode keeps a bare code', () {
    expect(EnableBankingClient.extractAuthorizationCode('abc'), 'abc');
  });

  test('HTTPS GitHub Pages callback URL is parsed', () {
    final uri = Uri.parse(
      '${EnableBankingCallback.hostedRedirectUri}?code=auth-code&state=state-1',
    );
    expect(EnableBankingCallback.isCallback(uri), isTrue);
    expect(EnableBankingCallback.authorizationCode(uri), 'auth-code');
    expect(EnableBankingCallback.oauthState(uri), 'state-1');
    expect(
      EnableBankingClient.extractAuthorizationCode(uri.toString()),
      'auth-code',
    );
  });

  test('signs Enable Banking JWT with kid and RS256', () {
    final client = EnableBankingClient(
      now: () => DateTime.utc(2026, 9, 12, 12),
    );
    final token = client.createJwt(_credentials);
    final parts = token.split('.');
    expect(parts, hasLength(3));
    final header = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
    ) as Map<String, dynamic>;
    expect(header['kid'], 'app-123');
    expect(header['alg'], 'RS256');
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    ) as Map<String, dynamic>;
    expect(payload['iss'], 'enablebanking.com');
    expect(payload['aud'], 'api.enablebanking.com');
  });

  test('reads legacy GoCardless account ids from stored JSON', () {
    final account = ConnectedAccount.fromJson({
      'id': 'acc-swed',
      'bank': 'swed',
      'personId': Person.meId,
      'displayName': 'Swed',
      'gocardlessRequisitionId': 'old-req',
      'gocardlessAccountId': 'old-acc',
      'status': 'connected',
    });
    expect(account.enableBankingSessionId, 'old-req');
    expect(account.enableBankingAccountId, 'old-acc');
  });

  test('deduper keeps a single copy of bank transactions', () {
    const deduper = Deduper();
    final a = MoneyTx(
      id: '1',
      bookedAt: DateTime(2026, 9, 1),
      amount: -10,
      currency: 'EUR',
      description: 'Maxima',
      merchant: 'Maxima',
      bank: BankId.swed,
      personId: Person.meId,
      categoryId: 'groceries',
      tag: SpendTag.essential,
      externalId: 'ext-1',
    );
    final copy = a.copyWith(description: 'duplicate pull');
    final merged = deduper.merge([a], [copy, a.copyWith()]);
    expect(merged, hasLength(1));
  });

  test('HTTPS callback completes the pending Enable Banking session', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final client = _client(
      MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/sessions')) {
          expect(jsonDecode(request.body), {'code': 'auth-code'});
          return http.Response(
            jsonEncode({
              'session_id': 'sess-1',
              'accounts': [
                {
                  'uid': 'acc-uuid',
                  'name': 'Einamoji',
                  'account_id': {'iban': 'LT123'},
                }
              ],
            }),
            200,
          );
        }
        if (request.url.path.contains('/sessions/sess-1')) {
          return http.Response(
            jsonEncode({
              'accounts': ['acc-uuid'],
            }),
            200,
          );
        }
        if (request.url.path.contains('/transactions')) {
          return http.Response(jsonEncode({'transactions': []}), 200);
        }
        return http.Response('unexpected ${request.url}', 404);
      }),
    );
    final controller = BudgetController(
      store: BudgetStore(),
      syncService: BankSyncService(enableBanking: client),
      scheduler: const _NoopScheduler(),
      now: () => DateTime(2026, 9, 12, 12),
    );
    controller.credentials = _credentials;
    controller.state = controller.state.copyWith(
      accounts: const [
        ConnectedAccount(
          id: 'acc-swed',
          bank: BankId.swed,
          personId: Person.meId,
          displayName: 'Swedbank',
          enableBankingState: 'state-1',
          status: AccountLinkStatus.pending,
        ),
      ],
    );

    await controller.handleEnableBankingCallback(
      Uri.parse(
        '${EnableBankingCallback.hostedRedirectUri}?code=auth-code&state=state-1',
      ),
    );

    final account = controller.state.accounts.single;
    expect(account.status, AccountLinkStatus.connected);
    expect(account.enableBankingSessionId, 'sess-1');
    expect(account.enableBankingAccountId, 'acc-uuid');
  });
}

class _NoopScheduler extends SyncScheduler {
  const _NoopScheduler();

  @override
  Future<void> registerDailySync() async {}

  @override
  Future<void> cancel() async {}
}
