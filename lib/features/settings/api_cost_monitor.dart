part of '../../main.dart';

class ApiCostMonitorPage extends StatefulWidget {
  const ApiCostMonitorPage({super.key});

  @override
  State<ApiCostMonitorPage> createState() => _ApiCostMonitorPageState();
}

class _ApiCostMonitorPageState extends State<ApiCostMonitorPage> {
  final unitPrice = TextEditingController();
  List<ApiRequestLog> logs = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getDouble('ai_cost_unit_usd') ?? 0.04;
    final loaded = await ApiRequestLogStore.load();
    if (!mounted) return;
    setState(() {
      unitPrice.text = saved.toStringAsFixed(4);
      logs = loaded;
      loading = false;
    });
  }

  double get price => double.tryParse(unitPrice.text.trim()) ?? 0;
  List<ApiRequestLog> get successful =>
      logs.where((entry) => entry.success).toList();
  double get estimatedUsd => successful.length * price;

  Future<void> _savePrice() async {
    final value = price;
    if (value < 0) return;
    final p = await SharedPreferences.getInstance();
    await p.setDouble('ai_cost_unit_usd', value);
    if (mounted) setState(() {});
  }

  String _money(double value) => '\$${value.toStringAsFixed(4)}';

  @override
  void dispose() {
    unitPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        title: const Text('费用监控'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '本机 API 使用估算',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  _money(estimatedUsd),
                  style: const TextStyle(
                    color: gold,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '成功请求 ${successful.length} 次 · 全部记录 ${logs.length} 条',
                  style: const TextStyle(color: Colors.black54),
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
                  '估算单价',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: unitPrice,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    prefixText: '\$',
                    suffixText: ' / 次',
                    border: OutlineInputBorder(),
                    hintText: '按服务商控制台价格填写',
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _savePrice(),
                ),
                const SizedBox(height: 8),
                const Text(
                  '默认按每次成功生图估算。不同尺寸、模型和服务商价格可能不同，请以火山方舟账单为准。',
                  style: TextStyle(color: Colors.black54, fontSize: 11),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _savePrice,
                  style: FilledButton.styleFrom(backgroundColor: gold),
                  child: const Text('保存估算单价'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('说明', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                  '应用无法仅凭 API Key 直接读取服务商余额或真实账单，因此这里使用本机保存的 API 请求日志做估算，不会伪造实时余额。',
                  style: TextStyle(color: Colors.black54, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
