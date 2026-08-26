import 'dart:async';
import 'dart:convert';
import 'package:arc_reader/features/billing/billing_models.dart';
import 'package:arc_reader/features/billing/billing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const credentials = BillingCredentials(
  'test-ak',
  'test-secret-not-for-production',
);

void main() {
  test('decimal amounts remain exact, including refunds and small charges', () {
    expect(
      (BillingAmount.parse('0.1') + BillingAmount.parse('0.2')).toString(),
      '0.30',
    );
    expect(
      (BillingAmount.parse('1000000000000000000.000001') +
              BillingAmount.parse('-0.000002'))
          .toString(),
      '999999999999999999.999999',
    );
    expect(BillingAmount.parse('-0.000001').toString(), '-0.000001');
    expect(() => BillingAmount.parse(null), throwsFormatException);
    expect(() => BillingAmount.parse('NaN'), throwsFormatException);
  });

  test(
    'balance is signed GET to fixed official endpoint, with no SK transmitted',
    () async {
      final service = BillingService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'https://open.volcengineapi.com/?Action=QueryBalanceAcct&Version=2022-01-01',
          );
          expect(request.followRedirects, isFalse);
          expect(request.body, isEmpty);
          expect(
            request.headers['authorization'],
            startsWith('HMAC-SHA256 Credential=test-ak/'),
          );
          expect(
            request.headers.toString(),
            isNot(contains(credentials.secretKey)),
          );
          return http.Response(
            jsonEncode({
              'Result': {
                'AvailableBalance': '12.30',
                'CashBalance': '10.30',
                'ArrearsBalance': '0.00',
                'Currency': 'CNY',
              },
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);
      final balance = await service.balance(credentials);
      expect(balance.available.toString(), '12.30');
      expect(balance.currency, 'CNY');
    },
  );

  test(
    'monthly bills POST with product/month grouping and record offset',
    () async {
      http.Request? captured;
      final service = BillingService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'Result': {
                'List': [
                  {
                    'ProductZh': '火山方舟',
                    'PayableAmount': '1.01',
                    'PaidAmount': '1.00',
                    'UnpaidAmount': '0.01',
                    'Currency': 'CNY',
                  },
                ],
                'Total': 101,
                'Limit': 100,
                'Offset': 100,
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.close);
      final page = await service.bills(credentials, '2026-08', offset: 100);
      expect(captured!.method, 'POST');
      expect(captured!.url.queryParameters['Action'], 'ListBillDetail');
      expect(jsonDecode(captured!.body), {
        'BillPeriod': '2026-08',
        'Limit': 100,
        'Offset': 100,
        'NeedRecordNum': 1,
        'IgnoreZero': 0,
        'GroupTerm': 2,
        'GroupPeriod': 0,
      });
      expect(page.rows.single.product, '火山方舟');
      expect(page.rows.single.unpaid.toString(), '0.01');
      expect(page.hasMore, isFalse);
    },
  );

  test(
    'empty official bill result is distinct from malformed/missing amounts',
    () async {
      var invalid = false;
      final service = BillingService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'Result': invalid
                  ? {
                      'List': [
                        {'PayableAmount': null},
                      ],
                      'Total': 1,
                    }
                  : {'List': [], 'Total': 0},
            }),
            200,
          ),
        ),
      );
      addTearDown(service.close);
      expect((await service.bills(credentials, '2026-08')).rows, isEmpty);
      invalid = true;
      await expectLater(
        service.bills(credentials, '2026-08'),
        throwsA(isA<BillingException>()),
      );
    },
  );

  test('missing balance is an error, never a displayed zero', () async {
    final service = BillingService(
      client: MockClient((_) async => http.Response('{"Result":{}}', 200)),
    );
    addTearDown(service.close);
    await expectLater(
      service.balance(credentials),
      throwsA(
        isA<BillingException>().having(
          (e) => e.message,
          'message',
          contains('未将缺失金额当作零'),
        ),
      ),
    );
  });

  for (final status in [200, 403]) {
    test(
      'IAM error in HTTP $status stays actionable without exposing response',
      () async {
        final service = BillingService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'ResponseMetadata': {
                  'Error': {
                    'Code': 'AccessDenied',
                    'Message': credentials.secretKey,
                  },
                },
              }),
              status,
            ),
          ),
        );
        addTearDown(service.close);
        await expectLater(
          service.balance(credentials),
          throwsA(
            isA<BillingException>()
                .having(
                  (e) => e.message,
                  'permission',
                  contains('BillingCenterReadOnlyAccess'),
                )
                .having(
                  (e) => e.message,
                  'redacted',
                  isNot(contains(credentials.secretKey)),
                ),
          ),
        );
      },
    );
  }

  test(
    'redirect, malformed JSON and timeout cannot leak raw secrets',
    () async {
      for (final response in [
        http.Response(
          credentials.secretKey,
          302,
          headers: {'location': 'https://example.com'},
        ),
        http.Response(credentials.secretKey, 200),
      ]) {
        final service = BillingService(
          client: MockClient((_) async => response),
        );
        addTearDown(service.close);
        await expectLater(
          service.balance(credentials),
          throwsA(
            isA<BillingException>().having(
              (e) => e.message,
              'redacted',
              isNot(contains(credentials.secretKey)),
            ),
          ),
        );
      }
      final service = BillingService(
        client: MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 1),
      );
      addTearDown(service.close);
      await expectLater(
        service.balance(credentials),
        throwsA(
          isA<BillingException>().having(
            (e) => e.message,
            'timeout',
            contains('超时'),
          ),
        ),
      );
    },
  );

  test(
    'unknown total still permits next page; inconsistent offset rejected',
    () async {
      var invalid = false;
      final service = BillingService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'Result': {
                'List': List.generate(
                  100,
                  (_) => {
                    'PayableAmount': '0.00',
                    'PaidAmount': '0.00',
                    'UnpaidAmount': '0.00',
                    'Currency': 'CNY',
                  },
                ),
                'Total': -1,
                'Offset': invalid ? 100 : 0,
                'Limit': 100,
              },
            }),
            200,
          ),
        ),
      );
      addTearDown(service.close);
      final page = await service.bills(credentials, '2026-08');
      expect(page.hasMore, isTrue);
      expect(page.nextOffset, 100);
      invalid = true;
      await expectLater(
        service.bills(credentials, '2026-08'),
        throwsA(isA<BillingException>()),
      );
    },
  );
}
