import 'dart:convert';
import 'package:arc_reader/features/billing/billing_credentials_store.dart';
import 'package:arc_reader/features/billing/billing_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? encrypted;
  bool failWrite = false;
  bool failRead = false;
  setUp(() {
    encrypted = null;
    failWrite = failRead = false;
    SharedPreferences.setMockInitialValues({
      'ai_access_key_id': 'old-ak',
      'ai_secret_access_key': 'old-sk',
      'ai_previous_access_key_id': 'previous-ak',
      'ai_previous_secret_access_key': 'previous-sk',
      'ai_api_key': 'image-key',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BillingCredentialsStore.channel, (
          call,
        ) async {
          switch (call.method) {
            case 'read':
              if (failRead) throw PlatformException(code: 'FAILED');
              return encrypted;
            case 'write':
              if (failWrite) throw PlatformException(code: 'FAILED');
              encrypted = (call.arguments as Map)['value'] as String;
              return null;
            case 'clear':
              encrypted = null;
              return null;
            default:
              throw MissingPluginException();
          }
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BillingCredentialsStore.channel, null),
  );

  test(
    'migrates current and previous AK/SK only after verified secure write',
    () async {
      final store = BillingCredentialsStore();
      expect((await store.load())!.accessKey, 'old-ak');
      final payload = jsonDecode(encrypted!) as Map;
      expect((payload['previous'] as Map)['sk'], 'previous-sk');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'ai_api_key'});
      expect((await store.restorePrevious()).accessKey, 'previous-ak');
      await store.save(const BillingCredentials('new-ak', 'new-sk'));
      expect((await store.load())!.secretKey, 'new-sk');
      expect((await store.restorePrevious()).secretKey, 'previous-sk');
    },
  );

  test(
    'failed migration leaves legacy credentials recoverable, never falls back',
    () async {
      failWrite = true;
      await expectLater(
        BillingCredentialsStore().load(),
        throwsA(isA<BillingException>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ai_secret_access_key'), 'old-sk');
      failWrite = false;
      expect((await BillingCredentialsStore().load())!.secretKey, 'old-sk');
    },
  );

  test(
    'concurrent instances do not overwrite new credentials with legacy keys',
    () async {
      final a = BillingCredentialsStore();
      final b = BillingCredentialsStore();
      await Future.wait([
        a.load(),
        b.save(const BillingCredentials('new-ak', 'new-sk')),
      ]);
      expect((await a.load())!.accessKey, 'new-ak');
    },
  );

  test(
    'clear removes legacy and encrypted credentials even after unreadable storage',
    () async {
      encrypted = 'corrupted';
      failRead = true;
      await BillingCredentialsStore().clear();
      expect(encrypted, isNull);
      expect((await SharedPreferences.getInstance()).getKeys(), {'ai_api_key'});
      failRead = false;
      expect(await BillingCredentialsStore().load(), isNull);
    },
  );
}
