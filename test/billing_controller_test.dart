import 'dart:async';
import 'package:arc_reader/features/billing/billing_controller.dart';
import 'package:arc_reader/features/billing/billing_credentials_store.dart';
import 'package:arc_reader/features/billing/billing_credentials_page.dart';
import 'package:arc_reader/features/billing/billing_models.dart';
import 'package:arc_reader/features/billing/billing_monitor_page.dart';
import 'package:arc_reader/features/billing/billing_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryCredentials extends BillingCredentialsStore {
  BillingCredentials? value = const BillingCredentials('fake-ak', 'fake-sk');
  @override
  Future<BillingCredentials?> load() async => value;
  @override
  Future<void> save(BillingCredentials credentials) async {
    value = credentials;
  }
}

class FakeBillingService extends BillingService {
  Future<BillingPage> Function(String, int)? onBills;
  bool denyBalance = false;
  int calls = 0;
  @override
  Future<BillingBalance> balance(BillingCredentials credentials) async {
    calls++;
    if (denyBalance) throw const BillingException('没有余额查询权限');
    return BillingBalance.fromJson({
      'AvailableBalance': '12.3',
      'CashBalance': '12.3',
      'ArrearsBalance': '0',
      'Currency': 'CNY',
    });
  }

  @override
  Future<BillingPage> bills(
    BillingCredentials credentials,
    String month, {
    int offset = 0,
  }) async {
    calls++;
    return onBills?.call(month, offset) ?? _page('0.1');
  }
}

BillingPage _page(
  String amount, {
  int total = 1,
  int offset = 0,
  String currency = 'CNY',
}) => BillingPage(
  rows: [
    BillingRow.fromJson({
      'ProductZh': '火山方舟',
      'PayableAmount': amount,
      'PaidAmount': amount,
      'UnpaidAmount': '0',
      'Currency': currency,
    }),
  ],
  total: total,
  offset: offset,
  limit: 1,
);

void main() {
  testWidgets(
    'credentials are masked, saved independently and the route returns',
    (tester) async {
      final store = MemoryCredentials();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BillingCredentialsPage(store: store),
                  ),
                ),
                child: const Text('打开凭据'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开凭据'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      expect(tester.widget<TextField>(fields.at(1)).obscureText, isTrue);
      await tester.enterText(fields.first, 'new-ak');
      await tester.enterText(fields.at(1), 'new-sk');
      await tester.ensureVisible(find.text('加密保存'));
      await tester.tap(find.text('加密保存'));
      await tester.pumpAndSettle();
      expect(store.value!.accessKey, 'new-ak');
      expect(store.value!.secretKey, 'new-sk');
      expect(find.text('打开凭据'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('no credentials means no billing network requests', () async {
    final store = MemoryCredentials()..value = null;
    final service = FakeBillingService();
    final controller = BillingController(store: store, service: service);
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.configured, isFalse);
    expect(service.calls, 0);
    expect(controller.loading, isFalse);
  });

  test('balance permission failure leaves successful bills visible', () async {
    final service = FakeBillingService()..denyBalance = true;
    final controller = BillingController(
      store: MemoryCredentials(),
      service: service,
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.balanceError, contains('权限'));
    expect(controller.billError, isNull);
    expect(controller.rows, hasLength(1));
  });

  test('month switch and dispose ignore late results', () async {
    final oldResponse = Completer<BillingPage>();
    final service = FakeBillingService()
      ..onBills = (month, _) =>
          month == '2026-08' ? oldResponse.future : Future.value(_page('2'));
    final controller = BillingController(
      store: MemoryCredentials(),
      service: service,
      now: DateTime(2026, 8),
    );
    final first = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    await controller.refresh(selectedMonth: '2026-07');
    oldResponse.complete(_page('99'));
    await first;
    expect(controller.month, '2026-07');
    expect(controller.rows.single.payable.toString(), '2.00');
    final late = Completer<BillingPage>();
    service.onBills = (_, __) => late.future;
    final last = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    late.complete(_page('100'));
    await last;
  });

  test(
    'pagination failure preserves rows; retry keeps currency subtotals separate',
    () async {
      var fail = true;
      final offsets = <int>[];
      final service = FakeBillingService()
        ..onBills = (_, offset) async {
          offsets.add(offset);
          if (offset == 0) return _page('0.1', total: 2);
          if (fail) throw const BillingException('网络错误');
          return _page('0.2', total: 2, offset: 1, currency: 'USD');
        };
      final controller = BillingController(
        store: MemoryCredentials(),
        service: service,
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      await controller.loadMore();
      expect(controller.rows, hasLength(1));
      expect(controller.page!.hasMore, isTrue);
      expect(controller.billError, isNotNull);
      fail = false;
      await controller.loadMore();
      expect(offsets, [0, 1, 1]);
      expect(
        controller.payableByCurrency.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
        {'CNY': '0.10', 'USD': '0.20'},
      );
      expect(controller.page!.hasMore, isFalse);
    },
  );

  testWidgets(
    'billing page fits narrow screen with enlarged text and keeps estimate separate',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = BillingController(
        store: MemoryCredentials(),
        service: FakeBillingService(),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: BillingMonitorPage(
            controller: controller,
            localEstimateBuilder: (_) => const Scaffold(body: Text('这是本地估算')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('账户可用余额'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('本机生图费用估算'), 400);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('本机生图费用估算'));
      await tester.pumpAndSettle();
      expect(find.text('这是本地估算'), findsOneWidget);
    },
  );
}
