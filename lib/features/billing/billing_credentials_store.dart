import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'billing_models.dart';

class BillingCredentialsStore {
  static const channel = MethodChannel('arc_reader/billing_credentials');
  static Future<void> _pending = Future.value();
  static const _legacyKeys = [
    'ai_access_key_id',
    'ai_secret_access_key',
    'ai_previous_access_key_id',
    'ai_previous_secret_access_key',
  ];

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<BillingCredentials?> load() => _serial(() async {
    final data = await _migrate();
    return _credentials(data?['current']);
  });

  Future<void> save(BillingCredentials credentials) => _serial(() async {
    if (!credentials.isComplete) throw const BillingException('请完整填写 AK 和 SK。');
    final old = await _migrate();
    await _write({'current': _map(credentials), 'previous': old?['current']});
  });

  Future<BillingCredentials> restorePrevious() => _serial(() async {
    final old = await _migrate();
    final previous = _credentials(old?['previous']);
    if (previous == null || !previous.isComplete) {
      throw const BillingException('没有可恢复的费用查询凭据。');
    }
    await _write({'current': _map(previous), 'previous': old?['current']});
    return previous;
  });

  Future<void> clear() => _serial(() async {
    await _removeLegacy(await SharedPreferences.getInstance());
    try {
      await channel.invokeMethod<void>('clear');
    } catch (_) {
      throw const BillingException('无法清除本机加密凭据，请重试。');
    }
  });

  Future<Map<String, dynamic>?> _migrate() async {
    try {
      final encoded = await channel.invokeMethod<String>('read');
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic>? data;
      if (encoded != null) {
        data = jsonDecode(encoded) as Map<String, dynamic>;
      } else if (_legacyKeys.any(prefs.containsKey)) {
        data = {
          'current': {
            'ak': prefs.getString(_legacyKeys[0]) ?? '',
            'sk': prefs.getString(_legacyKeys[1]) ?? '',
          },
          'previous': {
            'ak': prefs.getString(_legacyKeys[2]) ?? '',
            'sk': prefs.getString(_legacyKeys[3]) ?? '',
          },
        };
        await _write(data);
      }
      if (data != null) await _removeLegacy(prefs);
      return data;
    } on BillingException {
      rethrow;
    } catch (_) {
      throw const BillingException(
        '无法读取加密凭据。此功能需要 Android 安装版；若密钥已失效，请清除后重新填写。',
      );
    }
  }

  Future<void> _write(Map<String, dynamic> data) async {
    try {
      final encoded = jsonEncode(data);
      await channel.invokeMethod<void>('write', {'value': encoded});
      if (await channel.invokeMethod<String>('read') != encoded) {
        throw const FormatException();
      }
    } catch (_) {
      throw const BillingException('无法确认凭据已安全保存。请检查设备存储并重新打开此页核对后重试。');
    }
  }

  Future<void> _removeLegacy(SharedPreferences prefs) async {
    for (final key in _legacyKeys) {
      if (prefs.containsKey(key) && !await prefs.remove(key)) {
        throw const BillingException('凭据已加密，但旧配置清理失败。请重试以完成迁移。');
      }
    }
  }

  Map<String, String> _map(BillingCredentials value) => {
    'ak': value.accessKey,
    'sk': value.secretKey,
  };
  BillingCredentials? _credentials(dynamic value) {
    if (value == null) return null;
    if (value is! Map || value['ak'] is! String || value['sk'] is! String) {
      throw const BillingException('加密凭据格式异常，请清除后重新填写。');
    }
    return BillingCredentials(value['ak'] as String, value['sk'] as String);
  }
}
