part of '../../main.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key});
  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  bool openingFolder = false;
  bool clearingCache = false;
  int cacheBytes = 0;

  @override
  void initState() {
    super.initState();
    _refreshCacheSize();
  }

  Future<void> _refreshCacheSize() async {
    final size = await AiImageStorage.sizeBytes();
    if (mounted) setState(() => cacheBytes = size);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _clearImageCache() async {
    if (clearingCache || cacheBytes == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理 AI 图片缓存？'),
        content: const Text('这会删除本机保存的 AI 生成图片和导入图片。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => clearingCache = true);
    await AiImageStorage.clear();
    await AiGalleryStore.clear();
    await _refreshCacheSize();
    if (mounted) {
      setState(() => clearingCache = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI 图片缓存已清理'),
          duration: Duration(milliseconds: 1200),
        ),
      );
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清理历史？'),
        content: const Text('将一起清理阅读记录、API 请求历史和错误日志历史。'),
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
    if (confirmed != true) return;
    final p = await SharedPreferences.getInstance();
    for (final key in p.getKeys().where(
      (key) => key.startsWith('bookmark_') || key.startsWith('reading_'),
    )) {
      await p.remove(key);
    }
    await Future.wait([ApiRequestLogStore.clear(), AppErrorLogStore.clear()]);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('阅读记录、API 请求历史和错误日志历史已清理'),
          duration: Duration(milliseconds: 1200),
        ),
      );
  }

  Future<void> _openAiImageFolder() async {
    if (openingFolder) return;
    setState(() => openingFolder = true);
    try {
      final folder = await AiImageStorage.openDirectory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            content: Text('已打开 AI 图片文件夹：${folder.path}'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            content: Text('打开文件夹失败：$error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => openingFolder = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: const Text('数据管理', style: TextStyle(fontWeight: FontWeight.w900)),
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        card(
          Column(
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined, color: gold),
                title: const Text('AI 图片缓存'),
                subtitle: Text(
                  '已占用 ${_formatBytes(cacheBytes)}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: TextButton(
                  onPressed: clearingCache || cacheBytes == 0
                      ? null
                      : _clearImageCache,
                  child: Text(
                    clearingCache ? '清理中…' : '清理',
                    style: const TextStyle(color: gold),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined, color: gold),
                title: const Text('AI 生成图片文件夹'),
                subtitle: const Text(
                  '打开本机存放 AI 生成图片的目录',
                  style: TextStyle(fontSize: 11),
                ),
                onTap: openingFolder ? null : _openAiImageFolder,
                trailing: TextButton(
                  onPressed: openingFolder ? null : _openAiImageFolder,
                  child: Text(
                    openingFolder ? '打开中…' : '打开',
                    style: const TextStyle(color: gold),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: gold),
                title: const Text('清理历史'),
                subtitle: const Text(
                  '阅读记录、API 请求历史、错误日志历史',
                  style: TextStyle(fontSize: 11),
                ),
                trailing: TextButton(
                  onPressed: _clearHistory,
                  child: const Text('清理', style: TextStyle(color: gold)),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
