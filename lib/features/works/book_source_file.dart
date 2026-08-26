part of '../../main.dart';

class _BookSourceFile extends StatefulWidget {
  const _BookSourceFile({required this.work, required this.onChanged});
  final _ImportedWork work;
  final ValueChanged<_ImportedWork> onChanged;
  @override
  State<_BookSourceFile> createState() => _BookSourceFileState();
}

class _BookSourceFileState extends State<_BookSourceFile> {
  bool busy = false;

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _open() async {
    if (busy) return;
    if (widget.work.sourceUri.isEmpty) {
      await _link();
      return;
    }
    setState(() => busy = true);
    try {
      await SourceFileService.openLocation(widget.work.sourceUri);
    } on PlatformException catch (error) {
      _message(error.message ?? '无法定位原文件，请重新关联。');
    } catch (_) {
      _message('无法打开文件位置，请确认已安装支持此功能的 Android 版本。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _link() async {
    if (busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关联原文件'),
        content: Text(
          '请选择 ${widget.work.fileName} 的原文件。旧版本没有保存来源位置，无法自动恢复。关联只记录位置，不会替换正文、删除文件或重置阅读进度。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('选择原文件'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md'],
        withData: false,
      );
      if (result == null || !mounted) return;
      final file = result.files.single;
      if (file.name != widget.work.fileName) {
        _message('文件名不一致，请选择 ${widget.work.fileName}。');
        return;
      }
      final uri = file.identifier ?? '';
      if (!uri.startsWith('content://')) {
        _message('此来源没有可定位的文档地址，请从系统文件浏览器选择原文件。');
        return;
      }
      final retained = await SourceFileService.retain(uri);
      if (!retained) {
        _message('未能保存原文件的长期访问权限，请重新从系统文件浏览器选择。');
        return;
      }
      final updated = widget.work.copyWith(sourceUri: uri);
      await ImportedWorkStore.save(updated);
      if (!mounted) return;
      widget.onChanged(updated);
      _message('已关联原文件，可点击“打开所在文件夹”。');
    } catch (_) {
      _message('关联失败，请重试。正文和阅读进度未改动。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '本地文件',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: busy ? null : _open,
          leading: const Icon(Icons.description_outlined),
          title: Text(
            widget.work.fileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            widget.work.sourceUri.isEmpty
                ? '未记录来源位置，请关联原文件'
                : '已关联原文件 · 使用系统文件浏览器定位',
          ),
          trailing: const Icon(Icons.folder_open_outlined),
        ),
        if (busy) const LinearProgressIndicator(),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: busy ? null : _open,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(widget.work.sourceUri.isEmpty ? '关联原文件' : '打开所在文件夹'),
            ),
            if (widget.work.sourceUri.isNotEmpty)
              TextButton(
                onPressed: busy ? null : _link,
                child: const Text('重新关联'),
              ),
          ],
        ),
      ],
    ),
  );
}
