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

class AiImageService {
  static Future<String> generate({
    required String prompt,
    String size = '1024x1024',
    List<String>? referenceImages,
  }) async {
    final p = await SharedPreferences.getInstance();
    final key = (p.getString('ai_api_key') ?? '').trim().replaceFirst(
      RegExp(r'^(Bearer\s+)+', caseSensitive: false),
      '',
    );
    final model = (p.getString('ai_model') ?? '').trim();
    final provider = p.getString('ai_provider') ?? '';
    var url = (p.getString('ai_base_url') ?? '').trim();
    if (key.isEmpty || model.isEmpty) {
      throw StateError('请先在“我的 · AI服务配置”中填写 API Key 和模型');
    }
    final isArk = provider == '火山方舟' || model.startsWith('doubao-seedream');
    if (model.startsWith('doubao-seedream')) {
      // Seedream 不使用旧配置中的 OpenAI/自定义地址，始终走火山方舟图片接口。
      url = 'https://ark.cn-beijing.volces.com/api/v3/images/generations';
    } else if (url.isEmpty && isArk) {
      url = 'https://ark.cn-beijing.volces.com/api/v3/images/generations';
    }
    if (url.isEmpty) throw StateError('请先配置 API Base URL');
    if (!url.endsWith('/images/generations')) {
      url = '${url.replaceFirst(RegExp(r'/+$'), '')}/images/generations';
    }
    final body = <String, dynamic>{
      'model': model,
      'prompt': prompt.trim().isEmpty ? '生成一张高质量小说插画' : prompt.trim(),
      'size': isArk ? '2K' : size,
      'response_format': 'url',
    };
    if (referenceImages != null && referenceImages.isNotEmpty) {
      // 单张参考图沿用字符串格式；多张时火山方舟 Seedream 仅接受字符串数组，
      // 不接受 {"image","text"} 对象数组（会返回 400 image not valid）。
      body['image'] = referenceImages.length == 1
          ? referenceImages.first
          : referenceImages;
    }
    if (isArk) {
      body.addAll({
        'sequential_image_generation': 'disabled',
        'stream': false,
        'watermark': true,
      });
    }
    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120));
    } catch (error) {
      stopwatch.stop();
      await ApiRequestLogStore.append(
        ApiRequestLog(
          timestamp: DateTime.now(),
          provider: provider,
          model: model,
          url: url,
          statusCode: null,
          durationMs: stopwatch.elapsedMilliseconds,
          success: false,
          error: error.toString(),
        ),
      );
      rethrow;
    }
    stopwatch.stop();
    final requestSucceeded =
        response.statusCode >= 200 && response.statusCode < 300;
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }
    String? errorDetail;
    if (!requestSucceeded) {
      final error = decoded is Map ? decoded['error'] : null;
      errorDetail = error is Map
          ? (error['message'] ?? error['code'] ?? '接口返回错误').toString()
          : (decoded is Map
                    ? (decoded['message'] ?? response.body)
                    : response.body)
                .toString();
    }
    await ApiRequestLogStore.append(
      ApiRequestLog(
        timestamp: DateTime.now(),
        provider: provider,
        model: model,
        url: url,
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        success: requestSucceeded,
        error: requestSucceeded
            ? null
            : 'HTTP ${response.statusCode}：$errorDetail',
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('API 请求失败（${response.statusCode}）：$errorDetail');
    }
    final list = decoded is Map && decoded['data'] is List
        ? decoded['data'] as List
        : decoded is Map && decoded['images'] is List
        ? decoded['images'] as List
        : const [];
    if (list.isEmpty || list.first is! Map) {
      throw StateError('API 请求成功，但没有返回图片数据');
    }
    final item = list.first as Map;
    final imageUrl = item['url']?.toString();
    if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
    final b64 = item['b64_json']?.toString();
    if (b64 != null && b64.isNotEmpty) return 'data:image/png;base64,$b64';
    throw StateError('API 返回中没有可显示的图片地址');
  }
}

class AiImagePreview extends StatelessWidget {
  final String image;
  final BoxFit fit;
  const AiImagePreview({
    required this.image,
    this.fit = BoxFit.cover,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (image.startsWith('assets/')) return Image.asset(image, fit: fit);
    if (image.startsWith('data:image/')) {
      final comma = image.indexOf(',');
      return Image.memory(base64Decode(image.substring(comma + 1)), fit: fit);
    }
    if (!image.startsWith('http://') && !image.startsWith('https://')) {
      return Image.file(
        File(image),
        fit: fit,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: Color(0xFFE8DED0),
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );
    }
    return Image.network(
      image,
      fit: fit,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: Color(0xFFE8DED0),
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        AppErrorLogStore.append(
          error: details.exception,
          stack: details.stack,
          source: 'FlutterError',
          context: details.library ?? '',
          diagnostics: details.toString(),
        );
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        AppErrorLogStore.append(
          error: error,
          stack: stack,
          source: 'PlatformDispatcher',
        );
        return true;
      };
      await ThemePreferenceStore.load();
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      runApp(const ArcReaderApp());
    },
    (error, stack) {
      AppErrorLogStore.append(
        error: error,
        stack: stack,
        source: 'runZonedGuarded',
      );
    },
  );
}
