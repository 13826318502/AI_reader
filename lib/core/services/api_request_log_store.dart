part of '../../main.dart';

class ApiRequestLog {
  final DateTime timestamp;
  final String provider;
  final String model;
  final String url;
  final int? statusCode;
  final int durationMs;
  final bool success;
  final String? error;

  const ApiRequestLog({
    required this.timestamp,
    required this.provider,
    required this.model,
    required this.url,
    required this.statusCode,
    required this.durationMs,
    required this.success,
    required this.error,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'provider': provider,
    'model': model,
    'url': url,
    'status_code': statusCode,
    'duration_ms': durationMs,
    'success': success,
    'error': error,
  };

  factory ApiRequestLog.fromJson(Map<String, dynamic> json) => ApiRequestLog(
    timestamp:
        DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
        DateTime.now(),
    provider: json['provider']?.toString() ?? '',
    model: json['model']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
    statusCode: json['status_code'] is num
        ? (json['status_code'] as num).toInt()
        : null,
    durationMs: json['duration_ms'] is num
        ? (json['duration_ms'] as num).toInt()
        : 0,
    success: json['success'] == true,
    error: json['error']?.toString(),
  );
}

class ApiRequestLogStore {
  static const key = 'ai_api_request_logs';
  static const maxEntries = 100;

  static Future<List<ApiRequestLog>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(key) ?? const [];
    return raw
        .map((item) {
          try {
            final decoded = jsonDecode(item);
            return decoded is Map
                ? ApiRequestLog.fromJson(Map<String, dynamic>.from(decoded))
                : null;
          } catch (_) {
            return null;
          }
        })
        .whereType<ApiRequestLog>()
        .toList();
  }

  static Future<void> append(ApiRequestLog entry) async {
    final entries = await load();
    entries.insert(0, entry);
    final limited = entries
        .take(maxEntries)
        .map((item) => jsonEncode(item.toJson()))
        .toList();
    final p = await SharedPreferences.getInstance();
    await p.setStringList(key, limited);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(key);
  }
}
