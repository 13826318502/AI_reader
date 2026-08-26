part of '../../main.dart';

class AiServiceConfigPage extends StatefulWidget {
  const AiServiceConfigPage({super.key});
  @override
  State<AiServiceConfigPage> createState() => _AiServiceConfigPageState();
}

class _AiServiceConfigPageState extends State<AiServiceConfigPage> {
  final baseUrl = TextEditingController();
  final apiKey = TextEditingController();
  final model = TextEditingController(text: 'doubao-seedream-4-5-251128');
  String provider = '火山方舟';
  String selectedModel = 'doubao-seedream-4-5-251128';
  bool obscure = true;
  bool loading = true;
  bool testing = false;
  List<ApiRequestLog> requestLogs = const [];
  Map<String, String> initialConfiguration = const {};

  static const arkBaseUrl =
      'https://ark.cn-beijing.volces.com/api/v3/images/generations';
  static const modelOptions = <String, String>{
    'doubao-seedream-4-5-251128': 'Seedream 4.5（推荐）',
    'doubao-seedream-4-0-250828': 'Seedream 4.0',
    '自定义模型': '自定义模型',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final logs = await ApiRequestLogStore.load();
    final savedBaseUrl = p.getString('ai_base_url') ?? '';
    baseUrl.text =
        savedBaseUrl.isEmpty &&
            (p.getString('ai_model') == null ||
                (p.getString('ai_model') ?? '').startsWith('doubao-seedream'))
        ? arkBaseUrl
        : savedBaseUrl;
    apiKey.text = p.getString('ai_api_key') ?? '';
    final rawModel = p.getString('ai_model') ?? '';
    final savedModel =
        rawModel.isEmpty ||
            rawModel == 'image-generation' ||
            rawModel == 'Doubao-Seedream-4.5' ||
            rawModel == 'doubao-seedream-4.5'
        ? 'doubao-seedream-4-5-251128'
        : rawModel;
    model.text = savedModel;
    if (savedModel != rawModel) {
      await p.setString('ai_model', savedModel);
      await p.setString('ai_provider', '火山方舟');
      await p.setString('ai_base_url', arkBaseUrl);
      baseUrl.text = arkBaseUrl;
    }
    if (mounted) {
      setState(() {
        provider = p.getString('ai_provider') ?? '火山方舟';
        selectedModel = modelOptions.containsKey(savedModel)
            ? savedModel
            : '自定义模型';
        initialConfiguration = {
          'provider': provider,
          'base_url': baseUrl.text,
          'api_key': apiKey.text,
          'model': model.text,
        };
        requestLogs = logs;
        loading = false;
      });
    }
  }

  Future<void> _clearRequestLogs() async {
    if (requestLogs.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除 API 请求日志？'),
        content: const Text('删除后将无法恢复历史请求记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ApiRequestLogStore.clear();
    if (!mounted) return;
    setState(() => requestLogs = const []);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('API 请求日志已删除'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  String _formatLogTime(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  Widget _requestLogsCard() => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'API 请求日志',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
            TextButton.icon(
              onPressed: requestLogs.isEmpty ? null : _clearRequestLogs,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('删除日志'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
        Text(
          requestLogs.isEmpty
              ? '暂无请求记录'
              : '最近 ${requestLogs.length} 条记录（最多保留 ${ApiRequestLogStore.maxEntries} 条）',
          style: TextStyle(color: mutedText, fontSize: 12),
        ),
        if (requestLogs.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...requestLogs
              .take(10)
              .map(
                (log) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    log.success
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    color: log.success ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    '${log.provider.isEmpty ? 'API' : log.provider} · ${log.model}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_formatLogTime(log.timestamp)} · ${log.statusCode == null ? '无响应' : 'HTTP ${log.statusCode}'} · ${log.durationMs} ms\n'
                    '${log.error ?? log.url}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: mutedText, fontSize: 11),
                  ),
                ),
              ),
        ],
      ],
    ),
  );

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    // 保存覆盖前的配置，供“恢复之前配置”使用。
    final oldValues = <String, String>{
      'provider': p.getString('ai_provider') ?? '',
      'base_url': p.getString('ai_base_url') ?? '',
      'api_key': p.getString('ai_api_key') ?? '',
      'model': p.getString('ai_model') ?? '',
    };
    for (final entry in oldValues.entries) {
      await p.setString('ai_previous_${entry.key}', entry.value);
    }
    await p.setString('ai_provider', provider);
    await p.setString('ai_base_url', baseUrl.text.trim());
    await p.setString('ai_api_key', apiKey.text.trim());
    await p.setString('ai_model', model.text.trim());
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI 服务配置已保存'),
          duration: Duration(milliseconds: 1200),
        ),
      );
  }

  Future<void> _restorePrevious() async {
    final p = await SharedPreferences.getInstance();
    final previousModel = p.getString('ai_previous_model');
    if (previousModel == null) {
      if (initialConfiguration.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('还没有可恢复的历史配置'),
              duration: Duration(milliseconds: 1200),
            ),
          );
        }
        return;
      }
      setState(() {
        provider = initialConfiguration['provider'] ?? '火山方舟';
        baseUrl.text = initialConfiguration['base_url'] ?? '';
        apiKey.text = initialConfiguration['api_key'] ?? '';
        model.text = initialConfiguration['model'] ?? '';
        selectedModel = modelOptions.containsKey(model.text)
            ? model.text
            : '自定义模型';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已恢复本次打开页面前的配置'),
            duration: Duration(milliseconds: 1200),
          ),
        );
      }
      return;
    }
    setState(() {
      provider = p.getString('ai_previous_provider') ?? '火山方舟';
      baseUrl.text = p.getString('ai_previous_base_url') ?? '';
      apiKey.text = p.getString('ai_previous_api_key') ?? '';
      model.text = previousModel;
      selectedModel = modelOptions.containsKey(previousModel)
          ? previousModel
          : '自定义模型';
    });
    await p.setString('ai_provider', provider);
    await p.setString('ai_base_url', baseUrl.text);
    await p.setString('ai_api_key', apiKey.text);
    await p.setString('ai_model', model.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已恢复之前保存的 AI 配置'),
          duration: Duration(milliseconds: 1200),
        ),
      );
    }
  }

  void _selectModel(String? value) {
    if (value == null) return;
    setState(() {
      selectedModel = value;
      if (value != '自定义模型') {
        model.text = value;
        provider = '火山方舟';
        baseUrl.text = arkBaseUrl;
      }
    });
  }

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
      url = arkBaseUrl;
    } else if (provider == '火山方舟') {
      url = url.isEmpty ? arkBaseUrl : url;
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
    setState(() => testing = true);
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
          setState(() => requestLogs = logs);
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
        setState(() => requestLogs = logs);
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
      if (mounted) setState(() => testing = false);
    }
  }

  @override
  void dispose() {
    baseUrl.dispose();
    apiKey.dispose();
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: const Text(
        'AI 服务配置',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: gold))
        : ListView(
            padding: const EdgeInsets.all(18),
            children: [
              card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '生图服务',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '用于 AI 生图、角色头像和全身图生成',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: provider,
                      decoration: const InputDecoration(
                        labelText: '服务类型',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '火山方舟',
                          child: Text('火山方舟（Seedream）'),
                        ),
                        DropdownMenuItem(
                          value: 'OpenAI 兼容接口',
                          child: Text('OpenAI 兼容接口'),
                        ),
                        DropdownMenuItem(value: '自定义服务', child: Text('自定义服务')),
                      ],
                      onChanged: (v) =>
                          setState(() => provider = v ?? provider),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: baseUrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'API Base URL',
                        hintText: 'https://api.example.com/v1',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: apiKey,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'API Key',
                        hintText: '输入你的 API Key',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: model,
                      decoration: const InputDecoration(
                        labelText: '模型名称',
                        hintText: '例如：doubao-seedream-4-5-251128',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedModel,
                      decoration: const InputDecoration(
                        labelText: '快速选择模型',
                        border: OutlineInputBorder(),
                      ),
                      items: modelOptions.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: _selectModel,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: testing ? null : _testConnection,
                            icon: const Icon(Icons.wifi_tethering),
                            label: Text(testing ? '正在请求 API…' : '真实测试 API'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: gold,
                            ),
                            child: const Text('保存配置'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _restorePrevious,
                        icon: const Icon(Icons.restore),
                        label: const Text('恢复之前的配置'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _requestLogsCard(),
              const SizedBox(height: 12),
              const Text(
                '提示：Seedream 4.5 为默认模型。API Key 仅保存在本机，正式版建议迁移到安全存储。',
                style: TextStyle(color: Colors.black54, fontSize: 11),
              ),
            ],
          ),
  );
}
