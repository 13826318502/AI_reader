part of '../../main.dart';

extension _ReaderNavigation on _ReaderPageState {
  Future<void> _addTag() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 12,
          decoration: const InputDecoration(hintText: '例如：重点、伏笔、人物线索'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || value == null || value.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1200),
        content: Text('标签已添加：${value.trim()}'),
      ),
    );
  }

  Future<void> _finishPullDown() async {
    final shouldBookmark = pullOffset >= 56;
    _update(() => pullOffset = 0);
    if (!shouldBookmark) return;
    final adding = !bookmarked;
    await _toggleBookmark();
    if (!mounted) return;
    _update(() {
      pullBookmarkLabel = '书签';
      pullBookmarkBadge = adding;
    });
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) _update(() => pullBookmarkBadge = false);
    });
  }

  void _toggleTheme() {
    appDarkMode.value = !appDarkMode.value;
    ThemePreferenceStore.save();
    if (mounted) _update(() {});
  }

  Future<void> _openReadingPreferences() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReadingPreferencesPage()),
    );
    if (!mounted) return;
    await ReadingPreferencesStore.load();
    if (!mounted) return;
    _update(() {
      readerFontSize = ReadingPreferencesStore.fontSize;
      readerImmersive = ReadingPreferencesStore.immersive;
      readerPageTurn = ReadingPreferencesStore.pageTurn;
      readerEyeCare = ReadingPreferencesStore.eyeCare;
      readerTheme = ReadingPreferencesStore.theme;
      readerPageMode = ReadingPreferencesStore.pageMode;
    });
  }

  void _showGlobalSearch() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const GlobalSearchPage()),
  );

  String get chapterName {
    final chapters = importedWork?.chapters ?? const <_ParsedChapter>[];
    if (_currentChapterIndex >= 0 && _currentChapterIndex < chapters.length) {
      return chapters[_currentChapterIndex].title;
    }
    return '未命名章节';
  }

  void _showChapters() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: background,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => DefaultTabController(
          length: 2,
          child: SafeArea(
            child: SizedBox(
              height: 500,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: gold,
                    tabs: [
                      Tab(text: '书签'),
                      Tab(text: '目录'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        bookmarks.isEmpty
                            ? const Center(child: Text('翻页后会自动记录书签'))
                            : ListView(
                                children: bookmarks
                                    .map(
                                      (b) => GestureDetector(
                                        onLongPress: () =>
                                            _confirmDeleteBookmark(b, () {
                                              if (sheetContext.mounted)
                                                setSheetState(() {});
                                            }),
                                        child: ListTile(
                                          leading: const Icon(
                                            Icons.bookmark,
                                            color: gold,
                                          ),
                                          title: Text('第${b.chapter}章'),
                                          subtitle: Text('${b.preview} · 长按删除'),
                                          trailing: Text('第${b.page + 1}页'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _goToBookmark(b);
                                          },
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                        ListView(children: _chapterTiles()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _chapterTiles() {
    final chapters = importedWork?.chapters ?? const <_ParsedChapter>[];
    if (chapters.isNotEmpty) {
      return chapters
          .asMap()
          .entries
          .map(
            (entry) => ListTile(
              leading: Text(
                '${entry.key + 1}',
                style: const TextStyle(color: gold),
              ),
              title: Text(entry.value.title),
              trailing: entry.key + 1 == _currentChapterNumber
                  ? const Icon(Icons.check, color: gold)
                  : null,
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReaderPage(
                      chapter: entry.key + 1,
                      bookTitle: widget.bookTitle,
                    ),
                  ),
                );
              },
            ),
          )
          .toList();
    }
    return const [ListTile(title: Text('暂无章节'))];
  }

  void _showProgress() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: background,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          double value = _currentChapterNumber / _chapterCount;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '阅读进度',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '第$_currentChapterNumber章 / $_chapterCount章',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  Slider(
                    value: value,
                    min: .08,
                    max: 1,
                    activeColor: gold,
                    onChanged: (v) => setSheetState(() => value = v),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(backgroundColor: gold),
                    child: const Text('保存进度'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
