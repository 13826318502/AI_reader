part of '../../main.dart';

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
    if (!requestSucceeded) {
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
