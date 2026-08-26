part of '../../main.dart';

class Works extends StatefulWidget {
  const Works({super.key});
  @override
  State<Works> createState() => _WorksState();
}

class _WorksState extends State<Works> {
  _ImportedWork? importedWork;
  _ImportedWork? savedWork;
  bool pendingImport = false;
  bool importing = false;

  @override
  void initState() {
    super.initState();
    _loadImportedWork();
  }

  Future<void> _loadImportedWork() async {
    final works = await ImportedWorkStore.loadAll();
    if (!mounted) return;
    setState(() {
      savedWork = works.isEmpty ? null : works.first;
      importedWork = savedWork;
    });
  }

  Future<void> _pickFile() async {
    if (importing) return;
    setState(() => importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'json'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) {
        if (mounted) setState(() => importing = false);
        return;
      }

      final pickedFile = result.files.single;
      final extension = pickedFile.extension?.toLowerCase();
      if (extension == 'json') {
        throw const FormatException('暂不支持直接导入 JSON 作品，请选择 TXT 或 MD 文件');
      }
      final text = _decodeText(pickedFile.bytes!);
      final chapters = _parseChapters(text);
      final title = _titleFromFileName(pickedFile.name);
      final work = _ImportedWork(
        id: title,
        fileName: pickedFile.name,
        title: title,
        chapters: chapters,
        sourceUri: pickedFile.identifier ?? '',
      );
      if (work.sourceUri.isNotEmpty)
        await SourceFileService.retain(work.sourceUri);
      if (!mounted) return;
      setState(() {
        importedWork = work;
        pendingImport = true;
        importing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1200),
          content: Text('已选择《$title》，请点击下方“导入作品”确认'),
        ),
      );
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            content: Text(error.message),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            content: Text('导入失败：$error'),
          ),
        );
      }
    }
  }

  Future<void> _confirmImport() async {
    if (importing) return;
    if (!pendingImport || importedWork == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先点击上方“选择本地文件”'),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }
    setState(() => importing = true);
    await ImportedWorkStore.save(importedWork!);
    if (!mounted) return;
    setState(() {
      savedWork = importedWork;
      pendingImport = false;
      importing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1200),
        content: Text(
          '已导入《${importedWork!.title}》，解析出 ${importedWork!.chapters.length} 章',
        ),
      ),
    );
  }

  Future<void> _cancelImport() async {
    if (!mounted) return;
    setState(() {
      // 只取消本次待确认的文件选择，保留已经导入并持久化的作品。
      importedWork = savedWork;
      pendingImport = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已取消导入，可重新选择文件'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  String _decodeText(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  String _titleFromFileName(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  List<_ParsedChapter> _parseChapters(String text) {
    final chapterPattern = RegExp(
      r'^\s*(?:#+\s*)?((?:第[0-9零一二三四五六七八九十百千万两]+[章节回卷集].{0,60})|(?:Chapter|chapter)\s+\d+.{0,60})\s*$',
      multiLine: true,
    );
    final matches = chapterPattern.allMatches(text).toList();
    if (matches.isEmpty) {
      final content = text.trim();
      if (content.isEmpty) {
        throw const FormatException('文件内容为空，无法解析作品');
      }
      return [_ParsedChapter('正文', content)];
    }

    final chapters = <_ParsedChapter>[];
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final nextStart = i + 1 < matches.length
          ? matches[i + 1].start
          : text.length;
      final title = match.group(1)?.trim() ?? '未命名章节';
      final content = text.substring(match.end, nextStart).trim();
      chapters.add(_ParsedChapter(title, content));
    }
    return chapters;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: const Text(
        '导入本地作品',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '支持 TXT / MD 格式，角色、世界观、封面等设定可为空',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 18),
        InkWell(
          onTap: importing ? null : _pickFile,
          borderRadius: BorderRadius.circular(16),
          child: card(
            const SizedBox(
              height: 150,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.create_new_folder_outlined, color: gold, size: 38),
                  SizedBox(height: 8),
                  Text(
                    '选择本地文件',
                    style: TextStyle(color: gold, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '点击此处选择 TXT / MD 文件',
                    style: TextStyle(color: Colors.black45, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (importedWork != null) ...[
          card(
            Row(
              children: [
                const Icon(Icons.description_outlined, color: gold),
                const SizedBox(width: 10),
                Expanded(child: Text(importedWork!.fileName)),
                const Icon(Icons.check_circle, color: gold),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '解析结果 · 共 ${importedWork!.chapters.length} 章',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          card(
            Column(
              children: importedWork!.chapters
                  .take(5)
                  .toList()
                  .asMap()
                  .entries
                  .map(
                    (entry) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(color: gold),
                      ),
                      title: Text(entry.value.title),
                      trailing: const Icon(
                        Icons.check_circle_outline,
                        color: gold,
                        size: 18,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: importing ? null : _confirmImport,
            style: FilledButton.styleFrom(backgroundColor: gold),
            child: Text(importing ? '正在解析作品…' : '导入作品'),
          ),
        ),
        if (importedWork != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: importing ? null : _cancelImport,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('取消导入'),
            ),
          ),
        ],
      ],
    ),
  );
}
