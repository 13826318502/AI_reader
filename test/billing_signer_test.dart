import 'dart:convert';
import 'dart:io';
import 'package:arc_reader/features/billing/billing_models.dart';
import 'package:arc_reader/features/billing/volcengine_signer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GET and POST signatures match official Python SDK 1.0.228', () {
    final fixture =
        jsonDecode(
              File('test/fixtures/billing_signatures.json').readAsStringSync(),
            )
            as Map;
    for (final vector in fixture['vectors'] as List) {
      final headers = VolcengineSigner().sign(
        method: vector['method'] as String,
        uri: Uri.https(VolcengineSigner.host, '/', {
          'Action': vector['action'] as String,
          'Version': '2022-01-01',
        }),
        body: vector['body'] as String,
        credentials: const BillingCredentials(
          'test-ak',
          'test-secret-not-for-production',
        ),
        time: DateTime.utc(2026, 8, 26, 7, 8, 9),
      );
      expect(headers['authorization'], vector['authorization']);
      expect(headers['x-content-sha256'], vector['sha256']);
      expect(headers['x-date'], '20260826T070809Z');
    }
  });
}
