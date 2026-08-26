part of '../../main.dart';

class _ApiRequestLogsCard extends StatelessWidget {
  const _ApiRequestLogsCard({required this.requestLogs, required this.onClear});
  final List<ApiRequestLog> requestLogs;
  final VoidCallback onClear;

  String _formatLogTime(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  @override
  Widget build(BuildContext context) => card(
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
              onPressed: requestLogs.isEmpty ? null : onClear,
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
}
