import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'billing_models.dart';
import 'volcengine_signer.dart';

class BillingService {
  BillingService({
    http.Client? client,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;
  final http.Client _client;
  final DateTime Function() _clock;
  final Duration timeout;

  Future<BillingBalance> balance(BillingCredentials credentials) async {
    final data = await _request('QueryBalanceAcct', credentials);
    try {
      return BillingBalance.fromJson(data);
    } on FormatException {
      throw const BillingException('余额数据不完整，未将缺失金额当作零。请稍后重试。');
    }
  }

  Future<BillingPage> bills(
    BillingCredentials credentials,
    String month, {
    int offset = 0,
  }) async {
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month) || offset < 0) {
      throw const BillingException('账期或分页参数无效。');
    }
    const limit = 100;
    final data = await _request(
      'ListBillDetail',
      credentials,
      body: {
        'BillPeriod': month,
        'Limit': limit,
        'Offset': offset,
        'NeedRecordNum': 1,
        'IgnoreZero': 0,
        'GroupTerm': 2,
        'GroupPeriod': 0,
      },
    );
    try {
      final list = data['List'];
      final total = data['Total'];
      if (list is! List ||
          total is! int ||
          total < -1 ||
          (data['Offset'] != null && data['Offset'] != offset) ||
          (data['Limit'] != null && data['Limit'] != limit) ||
          list.length > limit) {
        throw const FormatException();
      }
      if (list.isEmpty && total > offset) throw const FormatException();
      if (total >= 0 &&
          (offset + list.length > total ||
              (list.length < limit && offset + list.length < total))) {
        throw const FormatException();
      }
      final rows = list
          .map((entry) {
            if (entry is! Map<String, dynamic>) throw const FormatException();
            return BillingRow.fromJson(entry);
          })
          .toList(growable: false);
      return BillingPage(
        rows: rows,
        total: total,
        offset: offset,
        limit: limit,
        hasWarning: (data['Warning'] ?? '').toString().isNotEmpty,
      );
    } on FormatException {
      throw const BillingException('账单数据格式不完整，请稍后重试或在费用中心核对。');
    }
  }

  Future<Map<String, dynamic>> _request(
    String action,
    BillingCredentials credentials, {
    Map<String, dynamic>? body,
  }) async {
    if (!credentials.isComplete) {
      throw const BillingException('请先配置费用查询 AK / SK。');
    }
    final uri = Uri.https(VolcengineSigner.host, '/', {
      'Action': action,
      'Version': '2022-01-01',
    });
    final method = body == null ? 'GET' : 'POST';
    final payload = body == null ? '' : jsonEncode(body);
    final request = http.Request(method, uri)..followRedirects = false;
    request.body = payload;
    request.headers.addAll(
      VolcengineSigner().sign(
        method: method,
        uri: uri,
        body: payload,
        credentials: credentials,
        time: _clock(),
      ),
    );
    try {
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(timeout);
      Map<String, dynamic>? decoded;
      try {
        final value = jsonDecode(utf8.decode(response.bodyBytes));
        if (value is Map<String, dynamic>) decoded = value;
      } on FormatException {
        /* Never surface raw responses or credentials. */
      }
      final metadata = decoded?['ResponseMetadata'];
      final error = metadata is Map ? metadata['Error'] : null;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          error != null) {
        final code = error is Map
            ? (error['Code'] ?? '').toString().toLowerCase()
            : '';
        throw BillingException(_errorMessage(response.statusCode, code));
      }
      final result = decoded?['Result'];
      if (result is! Map<String, dynamic>) {
        throw const BillingException('官方接口返回格式异常，请稍后重试。');
      }
      return result;
    } on BillingException {
      rethrow;
    } on TimeoutException {
      throw const BillingException('费用查询超时，请检查网络后重试。');
    } catch (_) {
      throw const BillingException('无法连接火山引擎费用接口，请检查网络后重试。');
    }
  }

  String _errorMessage(int status, String code) {
    if (code.contains('signature') ||
        code.contains('accesskey') ||
        status == 401) {
      return 'AK / SK 或签名校验失败，请核对密钥，并开启手机自动日期与时间。';
    }
    if (code.contains('expired') || code.contains('time')) {
      return '请求时间校验失败，请开启手机自动日期与时间后重试。';
    }
    if (status == 403 ||
        code.contains('denied') ||
        code.contains('forbidden')) {
      return '没有费用查询权限。请为 IAM 子用户授予 BillingCenterReadOnlyAccess；仅账单权限无法查询余额。';
    }
    if (status == 429 ||
        code.contains('throttl') ||
        code.contains('limitexceeded')) {
      return '查询过于频繁，请稍后重试。';
    }
    if (status >= 500) return '火山引擎费用服务暂不可用，请稍后重试。';
    if (code.contains('recordnofound')) return '官方接口未返回记录，请在费用中心核对账户状态。';
    return '费用查询未成功（HTTP $status），请核对账期、权限及账户状态。';
  }

  void close() => _client.close();
}
