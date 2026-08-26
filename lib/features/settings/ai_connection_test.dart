part of '../../main.dart';

extension _AiConnectionTest on _AiServiceConfigPageState {
  Future<void> _testConnection() async {
    // 兼容用户粘贴完整的“Bearer xxx”或只粘贴 Key 两种形式。
    final key = apiKey.text.trim().replaceFirst(
      RegExp(r'^(Bearer\s+)+', caseSensitive: false),
      '',
    );
    final selected = model.text.trim();
    var url = baseUrl.text.trim();
    if (key.isEmpty || selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先填写 API Base URL、API Key 和模型名称'),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }
    if (selected.startsWith('doubao-seedream')) {
      // Seedream 始终请求火山方舟，避免旧的 Base URL 导致请求发错服务。
      url = _AiServiceConfigPageState.arkBaseUrl;
    } else if (provider == '火山方舟') {
      url = url.isEmpty ? _AiServiceConfigPageState.arkBaseUrl : url;
    } else {
      if (url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('当前模型需要填写 API Base URL'),
            duration: Duration(milliseconds: 1200),
          ),
        );
        return;
      }
      if (!url.endsWith('/images/generations')) {
        url = '${url.replaceFirst(RegExp(r'/+$'), '')}/images/generations';
      }
    }
    if (testing) return;
    _mutate(() => testing = true);
    try {
      final isArk =
          provider == '火山方舟' || selected.startsWith('doubao-seedream');
      final body = isArk
          ? <String, dynamic>{
              'model': selected,
              'prompt': '生成一张简单的测试图片，只用于检查 API 是否连通。',
              'size': '2K',
              'sequential_image_generation': 'disabled',
              'stream': false,
              'response_format': 'url',
              'watermark': true,
            }
          : <String, dynamic>{
              'model': selected,
              'prompt': '生成一张简单的测试图片，只用于检查 API 是否连通。',
              'size': '1024x1024',
              'response_format': 'url',
            };
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
            .timeout(const Duration(seconds: 90));
      } catch (error) {
        stopwatch.stop();
        await ApiRequestLogStore.append(
          ApiRequestLog(
            timestamp: DateTime.now(),
            provider: provider,
            model: selected,
            url: url,
            statusCode: null,
            durationMs: stopwatch.elapsedMilliseconds,
            success: false,
            error: error.toString(),
          ),
        );
        if (mounted) {
          final logs = await ApiRequestLogStore.load();
          _mutate(() => requestLogs = logs);
        }
        rethrow;
      }
      stopwatch.stop();

      Map<String, dynamic> responseBody = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) responseBody = decoded;
      } catch (_) {}

      final requestSucceeded =
          response.statusCode >= 200 && response.statusCode < 300;
      await ApiRequestLogStore.append(
        ApiRequestLog(
          timestamp: DateTime.now(),
          provider: provider,
          model: selected,
          url: url,
          statusCode: response.statusCode,
          durationMs: stopwatch.elapsedMilliseconds,
          success: requestSucceeded,
          error: requestSucceeded ? null : 'HTTP ${response.statusCode}',
        ),
      );
      if (mounted) {
        final logs = await ApiRequestLogStore.load();
        _mutate(() => requestLogs = logs);
      }

      if (!mounted) return;
      if (requestSucceeded) {
        final hasImage =
            responseBody['data'] is List &&
            (responseBody['data'] as List).isNotEmpty;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            content: Text(
              hasImage ? 'API 连接成功，已返回测试图片' : 'API 请求成功，但响应中没有图片数据',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        final error = responseBody['error'];
        final message = error is Map
            ? (error['message'] ?? error['code'] ?? '接口返回错误').toString()
            : (responseBody['message'] ?? response.body).toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            content: Text('API 连接失败（${response.statusCode}）：$message'),
          ),
        );
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API 返回格式无法解析，请检查 Base URL 是否正确'),
            duration: Duration(milliseconds: 1200),
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API 请求超时，请检查网络或服务地址'),
            duration: Duration(milliseconds: 1200),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            content: Text('API 连接失败：$error'),
          ),
        );
      }
    } finally {
      if (mounted) _mutate(() => testing = false);
    }
  }
}
