part of '../../main.dart';

class BookDetail extends StatefulWidget {
  final String title;
  const BookDetail({required this.title, super.key});

  @override
  State<BookDetail> createState() => _BookDetailState();
}

class _BookDetailState extends State<BookDetail> {
  _ImportedWork? importedWork;
  List<_WorkCharacter> characters = const [];
  int lastChapter = 1;
  bool loading = true;

  String get title => widget.title;

  @override
  void initState() {
    super.initState();
    _loadImportedWork();
  }

  Future<void> _loadImportedWork() async {
    final results = await Future.wait([
      ImportedWorkStore.find(title),
      SharedPreferences.getInstance(),
      CharacterStore.load(title),
    ]);
    final work = results[0] as _ImportedWork?;
    final p = results[1] as SharedPreferences;
    final loadedCharacters = results[2] as List<_WorkCharacter>;
    final savedChapter = p.getInt('reading_chapter_${title.trim()}') ?? 1;
    if (!mounted) return;
    setState(() {
      importedWork = work;
      characters = loadedCharacters;
      lastChapter = savedChapter;
      loading = false;
    });
  }

  Future<void> _addCharacter() async {
    final character = await showAddCharacterDialog(context);
    if (character == null || !mounted) return;
    final updated = [character, ...characters];
    await CharacterStore.save(title, updated);
    if (!mounted) return;
    setState(() => characters = updated);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已新增角色：${character.name}')));
  }

  String get asset => importedWork?.cover ?? '';

  Future<void> _deleteBook(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这本小说？'),
        content: Text('确定从书架删除《$title》吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ImportedWorkStore.delete(title);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('作品已删除'),
        duration: Duration(milliseconds: 1200),
      ),
    );
    Navigator.pop(context, true);
  }

  void _showChapters(BuildContext context) {
    final importedChapters = importedWork?.title == title
        ? importedWork!.chapters
        : const <_ParsedChapter>[];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: background,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              '目录',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...(importedChapters.isNotEmpty
                ? importedChapters.asMap().entries.map(
                    (entry) => ListTile(
                      leading: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(color: gold),
                      ),
                      title: Text(entry.value.title),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReaderPage(
                              chapter: entry.key + 1,
                              bookTitle: title,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : const [ListTile(title: Text('暂无章节'))]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(backgroundColor: background, title: const Text('作品详情')),
        body: const Center(child: CircularProgressIndicator(color: gold)),
      );
    }
    final isImported = importedWork?.title == title;
    if (!isImported) {
      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(backgroundColor: background, title: const Text('作品详情')),
        body: const Center(child: Text('作品不存在或已删除')),
      );
    }
    final chapterCount = importedWork!.chapters.length;
    final characterCount = importedWork!.chapters.fold<int>(
      0,
      (total, chapter) => total + chapter.content.length,
    );
    final preview = StringBuffer();
    for (final chapter in importedWork!.chapters) {
      if (preview.length >= 220) break;
      if (preview.isNotEmpty) preview.write('\n');
      preview.write(
        chapter.content.characters.take(220 - preview.length).join(),
      );
    }
    final importedText = preview.toString();
    final progress = chapterCount == 0
        ? 0.0
        : (lastChapter / chapterCount).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        title: const Text('作品详情'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              if (value == 'delete') _deleteBook(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('删除这本小说')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          card(
            Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  cover(asset, width: 108, height: 148),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '本地导入作品',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '共$chapterCount章 · ${importedText.length}字',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '阅读进度',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '${(progress * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          color: gold,
                          backgroundColor: Color(0xFFE5D8C2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '上次阅读：第${lastChapter}章',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('作品简介', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 10),
                Text(
                  importedText.isEmpty
                      ? '暂无简介'
                      : importedText.substring(
                          0,
                          importedText.length.clamp(0, 220),
                        ),
                  style: TextStyle(
                    color: Colors.black54,
                    height: 1.55,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookAiGalleryPage(title: title),
                ),
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text(
                '进入 AI 图片集合',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16283A),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _BookCharactersSection(
            title: title,
            characters: characters,
            onAdd: _addCharacter,
          ),
          const SizedBox(height: 14),
          _BookSourceFile(
            work: importedWork!,
            onChanged: (work) => setState(() => importedWork = work),
          ),
          const SizedBox(height: 14),
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '作品信息',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                SizedBox(height: 10),
                _InfoLine('字数统计', '$characterCount 字'),
                _InfoLine('章节数量', '$chapterCount 章'),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: background,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showChapters(context),
                  icon: const Icon(Icons.list),
                  label: const Text('目录'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReaderPage(
                        chapter: lastChapter < 1
                            ? 1
                            : (lastChapter > chapterCount
                                  ? chapterCount
                                  : lastChapter),
                        bookTitle: title,
                      ),
                    ),
                  ),
                  style: FilledButton.styleFrom(backgroundColor: gold),
                  child: const Text('继续阅读'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
