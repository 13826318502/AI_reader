import 'package:flutter/foundation.dart';
import 'billing_credentials_store.dart';
import 'billing_models.dart';
import 'billing_service.dart';

class BillingController extends ChangeNotifier {
  BillingController({
    BillingCredentialsStore? store,
    BillingService? service,
    DateTime? now,
  }) : store = store ?? BillingCredentialsStore(),
       _service = service ?? BillingService() {
    final date = now ?? DateTime.now();
    months = List.generate(24, (i) {
      final value = DateTime(date.year, date.month - i);
      return '${value.year}-${value.month.toString().padLeft(2, '0')}';
    });
    month = months.first;
  }
  final BillingCredentialsStore store;
  final BillingService _service;
  late final List<String> months;
  late String month;
  BillingCredentials? _credentials;
  BillingBalance? balance;
  List<BillingRow> rows = [];
  BillingPage? page;
  String? credentialError;
  String? balanceError;
  String? billError;
  DateTime? balanceUpdated;
  DateTime? billsUpdated;
  bool loading = false;
  bool loadingMore = false;
  bool hasWarning = false;
  bool get configured => _credentials?.isComplete == true;
  int _generation = 0;
  bool _disposed = false;

  Map<String, BillingAmount> get payableByCurrency {
    final totals = <String, BillingAmount>{};
    for (final row in rows) {
      totals[row.currency] =
          (totals[row.currency] ?? BillingAmount.zero) + row.payable;
    }
    return totals;
  }

  Future<void> refresh({String? selectedMonth}) async {
    if (_disposed) return;
    if (selectedMonth != null && !months.contains(selectedMonth)) return;
    final generation = ++_generation;
    month = selectedMonth ?? month;
    final requestedMonth = month;
    loading = true;
    loadingMore = false;
    balance = null;
    rows = [];
    page = null;
    balanceUpdated = billsUpdated = null;
    credentialError = balanceError = billError = null;
    hasWarning = false;
    _credentials = null;
    notifyListeners();
    try {
      final credentials = await store.load();
      if (!_active(generation)) return;
      _credentials = credentials;
      if (credentials?.isComplete != true) return;
      await Future.wait([
        _fetchBalance(credentials!, generation),
        _fetchBills(credentials, requestedMonth, generation, 0),
      ]);
    } catch (error) {
      if (_active(generation)) credentialError = _message(error);
    } finally {
      if (_active(generation)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed ||
        loading ||
        loadingMore ||
        page?.hasMore != true ||
        !configured) {
      return;
    }
    final generation = _generation;
    loadingMore = true;
    billError = null;
    notifyListeners();
    await _fetchBills(_credentials!, month, generation, page!.nextOffset);
    if (_active(generation)) {
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _fetchBalance(
    BillingCredentials credentials,
    int generation,
  ) async {
    try {
      final value = await _service.balance(credentials);
      if (_active(generation)) {
        balance = value;
        balanceUpdated = DateTime.now();
      }
    } catch (error) {
      if (_active(generation)) balanceError = _message(error);
    }
  }

  Future<void> _fetchBills(
    BillingCredentials credentials,
    String month,
    int generation,
    int offset,
  ) async {
    try {
      final value = await _service.bills(credentials, month, offset: offset);
      if (_active(generation)) {
        rows = [...rows, ...value.rows];
        page = value;
        hasWarning = hasWarning || value.hasWarning;
        billsUpdated = DateTime.now();
      }
    } catch (error) {
      if (_active(generation)) billError = _message(error);
    }
  }

  String _message(Object error) =>
      error is BillingException ? error.message : '查询未完成，请稍后重试。';
  bool _active(int generation) => !_disposed && _generation == generation;

  @override
  void dispose() {
    _disposed = true;
    _credentials = null;
    _service.close();
    super.dispose();
  }
}
