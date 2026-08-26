part of '../../main.dart';

class AppErrorLog {
  final DateTime timestamp;
  final String source;
  final String error;
  final String stack;
  final String context;
  final String sessionId;
  final String kind;
  final String diagnostics;

  const AppErrorLog({
    required this.timestamp,
    required this.source,
    required this.error,
    required this.stack,
    required this.context,
    required this.sessionId,
    required this.kind,
    required this.diagnostics,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'source': source,
    'error': error,
    'stack': stack,
    'context': context,
    'session_id': sessionId,
    'kind': kind,
    'diagnostics': diagnostics,
  };

  factory AppErrorLog.fromJson(Map<String, dynamic> json) => AppErrorLog(
    timestamp:
        DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
        DateTime.now(),
    source: json['source']?.toString() ?? 'unknown',
    error: json['error']?.toString() ?? '',
    stack: json['stack']?.toString() ?? '',
    context: json['context']?.toString() ?? '',
    sessionId: json['session_id']?.toString() ?? 'legacy',
    kind: json['kind']?.toString() ?? 'runtime',
    diagnostics: json['diagnostics']?.toString() ?? '',
  );
}

class AppErrorLogStore {
  static const key = 'app_error_logs';
  static const maxEntries = 100;
  static bool _writing = false;
  static final String sessionId = DateTime.now().toUtc().toIso8601String();

  static Future<List<AppErrorLog>> load() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(key) ?? const [])
        .where((value) => value.trim().isNotEmpty)
        .map((value) {
          try {
            final json = jsonDecode(value);
            return json is Map
                ? AppErrorLog.fromJson(Map<String, dynamic>.from(json))
                : null;
          } catch (_) {
            return null;
          }
        })
        .whereType<AppErrorLog>()
        .toList();
  }

  static Future<void> append({
    required Object error,
    StackTrace? stack,
    String source = 'runtime',
    String context = '',
    String? diagnostics,
  }) async {
    if (_writing || error.toString().trim().isEmpty) return;
    _writing = true;
    try {
      final entries = await load();
      entries.insert(
        0,
        AppErrorLog(
          timestamp: DateTime.now(),
          source: source,
          error: error.toString(),
          stack: stack?.toString() ?? '',
          context: context,
          sessionId: sessionId,
          kind: source == 'FlutterError' ? 'flutter' : 'runtime',
          diagnostics: diagnostics ?? '',
        ),
      );
      final p = await SharedPreferences.getInstance();
      await p.setStringList(
        key,
        entries
            .take(maxEntries)
            .map((entry) => jsonEncode(entry.toJson()))
            .toList(),
      );
    } catch (_) {
      // Logging must never become a second source of runtime errors.
    } finally {
      _writing = false;
    }
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(key);
  }
}
