import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'billing_models.dart';

class VolcengineSigner {
  static const host = 'open.volcengineapi.com';
  static const region = 'cn-beijing';

  Map<String, String> sign({
    required String method,
    required Uri uri,
    required String body,
    required BillingCredentials credentials,
    required DateTime time,
  }) {
    if (uri.scheme != 'https' || uri.host != host || uri.path != '/') {
      throw ArgumentError('Only the official billing endpoint is allowed');
    }
    final utc = time.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    final date = '${utc.year}${two(utc.month)}${two(utc.day)}';
    final timestamp =
        '${date}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
    final hash = sha256.convert(utf8.encode(body)).toString();
    final headers = <String, String>{
      'content-type': 'application/json',
      'host': host,
      'x-content-sha256': hash,
      'x-date': timestamp,
    };
    final names = headers.keys.join(';');
    final queryKeys = uri.queryParameters.keys.toList()..sort();
    final query = queryKeys
        .map(
          (key) =>
              '${Uri.encodeComponent(key)}=${Uri.encodeComponent(uri.queryParameters[key]!)}',
        )
        .join('&');
    final canonical = [
      method,
      '/',
      query,
      headers.entries.map((e) => '${e.key}:${e.value}\n').join(),
      names,
      hash,
    ].join('\n');
    final scope = '$date/$region/billing/request';
    final stringToSign = [
      'HMAC-SHA256',
      timestamp,
      scope,
      sha256.convert(utf8.encode(canonical)).toString(),
    ].join('\n');
    List<int> hmac(List<int> key, String value) =>
        Hmac(sha256, key).convert(utf8.encode(value)).bytes;
    var key = hmac(utf8.encode(credentials.secretKey), date);
    for (final value in [region, 'billing', 'request']) {
      key = hmac(key, value);
    }
    final signature = Hmac(
      sha256,
      key,
    ).convert(utf8.encode(stringToSign)).toString();
    headers['authorization'] =
        'HMAC-SHA256 Credential=${credentials.accessKey}/$scope, SignedHeaders=$names, Signature=$signature';
    return headers;
  }
}
