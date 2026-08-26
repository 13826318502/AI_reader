part of '../main.dart';

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

class ReadingPreferencesStore {
  static double fontSize = 18;
  static bool immersive = true;
  static bool pageTurn = true;
  static bool eyeCare = false;
  static String theme = 'paper';
  static String pageMode = 'curl';
  static double lineHeight = 2.05;
  static double horizontalPadding = 22;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    fontSize = p.getDouble('reading_font_size') ?? 18;
    immersive = p.getBool('reading_immersive') ?? true;
    pageTurn = p.getBool('reading_page_turn') ?? true;
    eyeCare = p.getBool('reading_eye_care') ?? false;
    theme = p.getString('reading_theme') ?? 'paper';
    pageMode = p.getString('reading_page_mode') ?? 'curl';
    lineHeight = p.getDouble('reading_line_height') ?? 2.05;
    horizontalPadding = p.getDouble('reading_horizontal_padding') ?? 22;
  }

  static Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('reading_font_size', fontSize);
    await p.setBool('reading_immersive', immersive);
    await p.setBool('reading_page_turn', pageTurn);
    await p.setBool('reading_eye_care', eyeCare);
    await p.setString('reading_theme', theme);
    await p.setString('reading_page_mode', pageMode);
    await p.setDouble('reading_line_height', lineHeight);
    await p.setDouble('reading_horizontal_padding', horizontalPadding);
  }
}

class AiImageStorage {
  static const _folderName = 'AI生成图片';

  static Future<Directory> directory() async {
    final base =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final folder = Directory('${base.path}/$_folderName');
    if (!await folder.exists()) await folder.create(recursive: true);
    return folder;
  }

  static Future<String?> save(
    String image, {
    String prefix = 'ai_image',
  }) async {
    try {
      final bytes = image.startsWith('data:image/')
          ? base64Decode(image.substring(image.indexOf(',') + 1))
          : (await http.get(Uri.parse(image))).bodyBytes;
      final folder = await directory();
      final stamp = DateTime.now().toIso8601String().replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      final file = File('${folder.path}/${prefix}_$stamp.png');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static Future<int> sizeBytes() async {
    final folder = await directory();
    var total = 0;
    await for (final entity in folder.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  static Future<List<File>> imageFiles() async {
    final folder = await directory();
    final files = <File>[];
    await for (final entity in folder.list(
      recursive: false,
      followLinks: false,
    )) {
      if (entity is File &&
          RegExp(
            r'\.(png|jpg|jpeg|webp)$',
            caseSensitive: false,
          ).hasMatch(entity.path)) {
        files.add(entity);
      }
    }
    return files;
  }

  static Future<void> clear() async {
    final folder = await directory();
    await for (final entity in folder.list(
      recursive: false,
      followLinks: false,
    )) {
      await entity.delete(recursive: true);
    }
  }

  static Future<Directory> openDirectory() async {
    final folder = await directory();
    try {
      await const MethodChannel(
        'arc_reader/file_manager',
      ).invokeMethod<void>('openFolder', {'path': folder.path});
    } catch (_) {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [folder.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [folder.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [folder.path]);
      }
    }
    return folder;
  }
}
