part of '../../main.dart';

class AppErrorLogPage extends StatefulWidget {
  const AppErrorLogPage({super.key});

  @override
  State<AppErrorLogPage> createState() => _AppErrorLogPageState();
}

class _AppErrorLogPageState extends State<AppErrorLogPage> {
  List<AppErrorLog> logs = const [];
  bool loading = true;
  bool showHistory = true;

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
          '类型：${log.kind}',
          '会话：${log.sessionId}',
          '上下文：${log.context}',
          '错误：${log.error}',
          '堆栈：\n${log.stack}',
          if (log.diagnostics.isNotEmpty) '诊断：\n${log.diagnostics}',
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

  Future<void> _confirmClear() async {
    if (logs.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清理错误日志？'),
        content: Text('将删除当前保存的 ${logs.length} 条记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _clear();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final visibleLogs = showHistory
        ? logs
        : logs
              .where((log) => log.sessionId == AppErrorLogStore.sessionId)
              .toList();
    final hasVisibleLogs = visibleLogs.isNotEmpty;
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
          IconButton(
            tooltip: showHistory ? '仅看本次启动' : '查看全部历史',
            onPressed: logs.isEmpty
                ? null
                : () => setState(() => showHistory = !showHistory),
            icon: Icon(showHistory ? Icons.history : Icons.bug_report_outlined),
          ),
          IconButton(
            tooltip: '清理错误日志',
            onPressed: logs.isEmpty ? null : _confirmClear,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: logs.isEmpty || !hasVisibleLogs
          ? Center(child: Text(logs.isEmpty ? '暂无错误记录' : '本次启动暂无错误记录'))
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: visibleLogs.length + 1,
              itemBuilder: (_, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      showHistory
                          ? '显示全部 ${logs.length} 条记录；其中旧记录可能来自之前版本。'
                          : '仅显示本次启动产生的 ${visibleLogs.length} 条记录。',
                      style: TextStyle(color: mutedText, fontSize: 12),
                    ),
                  );
                }
                final log = visibleLogs[index - 1];
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
                      if (log.diagnostics.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SelectableText(
                            '\n诊断信息：\n${log.diagnostics}',
                            style: const TextStyle(fontSize: 11, height: 1.3),
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
