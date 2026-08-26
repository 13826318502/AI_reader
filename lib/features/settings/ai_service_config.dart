part of '../../main.dart';

class AiServiceConfigPage extends StatefulWidget {
  const AiServiceConfigPage({super.key});
  @override
  State<AiServiceConfigPage> createState() => _AiServiceConfigPageState();
}

class _AiServiceConfigPageState extends State<AiServiceConfigPage> {
  final baseUrl = TextEditingController();
  final textBaseUrl = TextEditingController();
  final textApiKey = TextEditingController();
  final apiKey = TextEditingController();
  final model = TextEditingController(text: 'doubao-seedream-4-5-251128');
  final textModel = TextEditingController();
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
    if (!mounted) return;
    final savedBaseUrl = p.getString('ai_base_url') ?? '';
    baseUrl.text =
        savedBaseUrl.isEmpty &&
            (p.getString('ai_model') == null ||
                (p.getString('ai_model') ?? '').startsWith('doubao-seedream'))
        ? arkBaseUrl
        : savedBaseUrl;
    apiKey.text = p.getString('ai_api_key') ?? '';
    textBaseUrl.text = p.getString('ai_text_base_url') ?? '';
    textApiKey.text = p.getString('ai_text_api_key') ?? '';
    textModel.text = p.getString('ai_text_model') ?? '';
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
      if (!mounted) return;
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
          'text_base_url': textBaseUrl.text,
          'text_model': textModel.text,
          'text_api_key': textApiKey.text,
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

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    // 保存覆盖前的配置，供“恢复之前配置”使用。
    final oldValues = <String, String>{
      'provider': p.getString('ai_provider') ?? '',
      'base_url': p.getString('ai_base_url') ?? '',
      'api_key': p.getString('ai_api_key') ?? '',
      'model': p.getString('ai_model') ?? '',
      'text_base_url': p.getString('ai_text_base_url') ?? '',
      'text_model': p.getString('ai_text_model') ?? '',
      'text_api_key': p.getString('ai_text_api_key') ?? '',
    };
    for (final entry in oldValues.entries) {
      await p.setString('ai_previous_${entry.key}', entry.value);
    }
    await p.setString('ai_provider', provider);
    await p.setString('ai_base_url', baseUrl.text.trim());
    await p.setString('ai_api_key', apiKey.text.trim());
    await p.setString('ai_model', model.text.trim());
    await p.setString('ai_text_base_url', textBaseUrl.text.trim());
    await p.setString('ai_text_model', textModel.text.trim());
    await p.setString('ai_text_api_key', textApiKey.text.trim());
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
    if (!mounted) return;
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
        textBaseUrl.text = initialConfiguration['text_base_url'] ?? '';
        textModel.text = initialConfiguration['text_model'] ?? '';
        textApiKey.text = initialConfiguration['text_api_key'] ?? '';
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
      textBaseUrl.text = p.getString('ai_previous_text_base_url') ?? '';
      textModel.text = p.getString('ai_previous_text_model') ?? '';
      textApiKey.text = p.getString('ai_previous_text_api_key') ?? '';
      selectedModel = modelOptions.containsKey(previousModel)
          ? previousModel
          : '自定义模型';
    });
    await p.setString('ai_provider', provider);
    await p.setString('ai_base_url', baseUrl.text);
    await p.setString('ai_api_key', apiKey.text);
    await p.setString('ai_model', model.text);
    await p.setString('ai_text_base_url', textBaseUrl.text);
    await p.setString('ai_text_model', textModel.text);
    await p.setString('ai_text_api_key', textApiKey.text);
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

  void _mutate(VoidCallback update) {
    if (mounted) setState(update);
  }

  @override
  void dispose() {
    baseUrl.dispose();
    textBaseUrl.dispose();
    textApiKey.dispose();
    apiKey.dispose();
    model.dispose();
    textModel.dispose();
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
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                      title: const Text('费用查询 AK / SK'),
                      subtitle: const Text('独立加密保存，用于官方余额与账单查询'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BillingCredentialsPage(),
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
              card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '普通大模型服务',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '用于人物关系自动布局、设定整理等文本任务，与上方 API Key 共用。',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textBaseUrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: '普通模型 API Base URL',
                        hintText: '例如：https://api.openai.com/v1',
                        helperText:
                            '可填写 OpenAI 兼容接口地址，程序会自动补全 /chat/completions',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textModel,
                      decoration: const InputDecoration(
                        labelText: '普通模型名称',
                        hintText: '例如：gpt-4o-mini / doubao-seed-1-6',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textApiKey,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: '普通大模型 API Key',
                        hintText: '可与生图 API Key 不同',
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
                    const SizedBox(height: 10),
                    const Text(
                      '留空时，关系图使用本地稳定布局；配置后可点击“AI 自动布局”。',
                      style: TextStyle(color: Colors.black54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ApiRequestLogsCard(
                requestLogs: requestLogs,
                onClear: _clearRequestLogs,
              ),
              const SizedBox(height: 12),
              const Text(
                '提示：Seedream 4.5 为默认模型。生图 API Key 保存在本机。费用 AK / SK 请在独立的费用查询凭据页管理，恢复生图配置不会改动费用凭据。',
                style: TextStyle(color: Colors.black54, fontSize: 11),
              ),
            ],
          ),
  );
}
