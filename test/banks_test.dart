import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:budget_app/banks/gocardless_client.dart';
import 'package:budget_app/banks/sync_service.dart';
import 'package:budget_app/models/bank.dart';
import 'package:budget_app/models/person.dart';
import 'package:budget_app/models/spend_tag.dart';
import 'package:budget_app/models/transaction.dart';

void main() {
  test('GoCardless maps booked PSD2 transactions', () async {
    final client = GoCardlessClient(
      httpClient: MockClient((request) async {
        expect(request.url.path, contains('/accounts/acc-1/transactions/'));
        return http.Response(
          jsonEncode({
            'transactions': {
              'booked': [
                {
                  'transactionId': 't1',
                  'bookingDate': '2026-09-10',
                  'transactionAmount': {'amount': '-15.20', 'currency': 'EUR'},
                  'creditorName': 'Maxima',
                  'remittanceInformationUnstructured': 'Pirkimas',
                }
              ],
            },
          }),
          200,
        );
      }),
    );

    final result = await client.fetchTransactions(
      accessToken: 'token',
      accountId: 'acc-1',
      bank: BankId.swed,
      personId: Person.meId,
    );
    expect(result.transactions, hasLength(1));
    expect(result.transactions.first.merchant, 'Maxima');
    expect(result.transactions.first.categoryId, 'groceries');
    expect(result.transactions.first.tag, SpendTag.essential);
  });

  test('GoCardless looks up Lithuanian institution by BIC', () async {
    final client = GoCardlessClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode([
            {'id': 'SWEDBANK_HABALT22', 'bic': 'HABALT22', 'name': 'Swedbank'},
            {'id': 'ARTEA_CBSBLT26', 'bic': 'CBSBLT26', 'name': 'Artea'},
          ]),
          200,
        );
      }),
    );
    final id = await client.lookupInstitutionId(
      accessToken: 't',
      bank: BankId.artea,
    );
    expect(id, 'ARTEA_CBSBLT26');
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
}
