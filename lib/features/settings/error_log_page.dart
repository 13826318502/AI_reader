part of '../../main.dart';

class AppErrorLogPage extends StatefulWidget {
  const AppErrorLogPage({super.key});

  @override
  State<AppErrorLogPage> createState() => _AppErrorLogPageState();
}

class _AppErrorLogPageState extends State<AppErrorLogPage> {
  List<AppErrorLog> logs = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await AppErrorLogStore.load();
    if (!mounted) return;
    setState(() {
      logs = loaded;
      loading = false;
    });
  }

  String _diagnosticText() => logs
      .map(
        (log) => [
          '时间：${log.timestamp.toLocal().toIso8601String()}',
          '来源：${log.source}',
          '上下文：${log.context}',
          '错误：${log.error}',
          '堆栈：\n${log.stack}',
        ].join('\n'),
      )
      .join('\n\n==============================\n\n');

  Future<void> _copy() async {
    if (logs.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _diagnosticText()));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('错误诊断信息已复制，可直接粘贴给 agent')));
    }
  }

  Future<void> _export() async {
    if (logs.isEmpty) return;
    final folder = await AiImageStorage.directory();
    final file = File('${folder.path}/error_diagnostics.txt');
    await file.writeAsString(_diagnosticText(), flush: true);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('诊断日志已导出：${file.path}')));
    }
  }

  Future<void> _clear() async {
    await AppErrorLogStore.clear();
    if (mounted) setState(() => logs = const []);
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
        title: const Text('错误日志'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: logs.isEmpty ? null : _copy,
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            onPressed: logs.isEmpty ? null : _export,
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(child: Text('暂无错误记录'))
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: logs.length + 1,
              itemBuilder: (_, index) {
                if (index == logs.length) {
                  return OutlinedButton(
                    onPressed: _clear,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('清空错误日志'),
                  );
                }
                final log = logs[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    leading: const Icon(Icons.error_outline, color: Colors.red),
                    title: Text(
                      log.error,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${log.timestamp.toLocal()} · ${log.source}',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText(
                          '上下文：${log.context}\n\n${log.stack.isEmpty ? '无堆栈信息' : log.stack}',
                          style: const TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
