part of '../../main.dart';

class ReaderPage extends StatefulWidget {
  final int chapter;
  final String bookTitle;
  const ReaderPage({required this.chapter, required this.bookTitle, super.key});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderBookmark {
  final int chapter;
  final int page;
  final String preview;
  const _ReaderBookmark(this.chapter, this.page, this.preview);
}

class _ReaderFlatPage {
  final int chapterIndex;
  final int pageInChapter;
  final int textGlobal;
  final String? imagePath;
  final String? imageId;
  const _ReaderFlatPage.text(
    this.chapterIndex,
    this.pageInChapter,
    this.textGlobal,
  ) : imagePath = null,
      imageId = null;
  const _ReaderFlatPage.image(
    this.chapterIndex,
    this.textGlobal,
    this.imagePath,
    this.imageId,
  ) : pageInChapter = -1;
  bool get isImage => imagePath != null;
}

class _ReaderPageState extends State<ReaderPage> {
  _ImportedWork? importedWork;
  bool focused = false;
  bool bookmarked = false;
  bool pullBookmarkBadge = false;
  String pullBookmarkLabel = '书签';
  double pullOffset = 0;
  double brightness = .55;
  double readerFontSize = 18;
  bool readerImmersive = true;
  bool readerPageTurn = true;
  final PageController readingPages = PageController();
  int currentPage = 0;
  final List<_ReaderBookmark> bookmarks = [];
  final Set<int> bookmarkedPages = {};
  List<_AiImagePageEntry> _imagePages = [];
  bool _ready = false;
  int _savedChapterPage = 0;
  // Keep each logical page comfortably below the viewport. The page itself
  // remains scrollable so larger accessibility font sizes never overflow.
  static const int _charsPerPage = 240;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await ReadingPreferencesStore.load();
    final work = await ImportedWorkStore.find(widget.bookTitle);
    if (!mounted) return;
    setState(() {
      importedWork = work?.title == widget.bookTitle ? work : null;
      readerFontSize = ReadingPreferencesStore.fontSize;
      readerImmersive = ReadingPreferencesStore.immersive;
      readerPageTurn = ReadingPreferencesStore.pageTurn;
      _ready = true;
      _flatCache = null;
    });
    await _loadImagePages();
    await _loadBookmarks();
    if (!mounted) return;
    setState(() {
      currentPage = _initialGlobalPage();
      bookmarked = bookmarkedPages.contains(currentPage);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && readingPages.hasClients) {
        readingPages.jumpToPage(currentPage);
      }
    });
  }

  Future<void> _loadImagePages() async {
    final loaded = await AiImagePageStore.load(widget.bookTitle);
    if (!mounted) return;
    setState(() {
      _imagePages = loaded;
      _flatCache = null;
    });
  }

  List<int> get _chapterPageCounts {
    final chapters = importedWork?.chapters;
    if (chapters == null) return const [];
    return [
      for (final c in chapters)
        c.content.trim().isEmpty
            ? 1
            : (c.content.trim().length / _charsPerPage).ceil(),
    ];
  }

  int get _chapterCount => importedWork?.chapters.length ?? 0;

  int _clampInt(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  List<_ReaderFlatPage>? _flatCache;

  List<_ReaderFlatPage> _computeFlatPages() {
    final counts = _chapterPageCounts;
    final imageMap = <int, List<_AiImagePageEntry>>{};
    for (final e in _imagePages) {
      imageMap.putIfAbsent(e.afterTextPage, () => []).add(e);
    }
    final flat = <_ReaderFlatPage>[];
    var textGlobal = 0;
    for (var c = 0; c < counts.length; c++) {
      for (var p = 0; p < counts[c]; p++) {
        flat.add(_ReaderFlatPage.text(c, p, textGlobal));
        for (final e in imageMap[textGlobal] ?? const <_AiImagePageEntry>[]) {
          flat.add(_ReaderFlatPage.image(c, textGlobal, e.image, e.id));
        }
        textGlobal++;
      }
    }
    return flat;
  }

  List<_ReaderFlatPage> get _flatPages => _flatCache ??= _computeFlatPages();

  int get _totalPages => _flatPages.length;

  _ReaderFlatPage _locationOf(int globalPage) => _flatPages[globalPage];

  int _flatIndexOfTextPage(int chapterIndex, int pageInChapter) {
    final flat = _flatPages;
    for (var i = 0; i < flat.length; i++) {
      if (!flat[i].isImage &&
          flat[i].chapterIndex == chapterIndex &&
          flat[i].pageInChapter == pageInChapter) {
        return i;
      }
    }
    return 0;
  }

  int _flatIndexOfTextGlobal(int textGlobal) {
    final flat = _flatPages;
    for (var i = 0; i < flat.length; i++) {
      if (!flat[i].isImage && flat[i].textGlobal == textGlobal) return i;
    }
    return 0;
  }

  int get _currentChapterIndex => _locationOf(currentPage).chapterIndex;
  int get _currentChapterNumber => _currentChapterIndex + 1;
  int get _currentPageInChapter => _locationOf(currentPage).pageInChapter;

  int _initialGlobalPage() {
    if (_totalPages == 0) return 0;
    final counts = _chapterPageCounts;
    final chapterIndex = _clampInt(widget.chapter - 1, 0, _chapterCount - 1);
    final saved = _clampInt(_savedChapterPage, 0, counts[chapterIndex] - 1);
    final flatIndex = _flatIndexOfTextPage(chapterIndex, saved);
    return _clampInt(flatIndex, 0, _totalPages - 1);
  }

  String _chapterHeaderText(int chapterNumber, String title) {
    final numbered =
        RegExp(r'^第[0-9零一二三四五六七八九十百千万两]+[章节回卷集]').hasMatch(title) ||
        RegExp(r'^Chapter\s+\d+', caseSensitive: false).hasMatch(title);
    return numbered ? title : '第$chapterNumber章 · $title';
  }

  Widget _buildChapterHeader(int chapterIndex) {
    final title = importedWork?.chapters[chapterIndex].title ?? '未命名章节';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _chapterHeaderText(chapterIndex + 1, title),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: gold,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPage(int globalPage) {
    final flat = _locationOf(globalPage);
    if (flat.isImage) {
      return _ReadingPageContent(
        children: [
          Row(
            children: [
              const Text(
                'AI 生成图片',
                style: TextStyle(
                  color: gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _confirmRemoveImagePage(flat),
                child: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: AiImagePreview(
                image: flat.imagePath!,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '此图片已插入当前小说，点击右上角删除图标可移除',
            style: TextStyle(color: Colors.black38, fontSize: 11),
          ),
        ],
      );
    }
    final chapterIndex = flat.chapterIndex;
    final pageInChapter = flat.pageInChapter;
    final chapters = importedWork?.chapters;
    if (chapters == null) {
      return const _ReadingPageContent(
        children: [Text('暂无可阅读内容', style: TextStyle(fontSize: 18))],
      );
    }
    if (chapterIndex < 0 || chapterIndex >= chapters.length) {
      return const _ReadingPageContent(
        children: [Text('找不到该章节内容', style: TextStyle(fontSize: 18))],
      );
    }
    final content = chapters[chapterIndex].content.trim();
    if (content.isEmpty) {
      return const _ReadingPageContent(
        children: [Text('本章节暂无正文内容', style: TextStyle(fontSize: 18))],
      );
    }
    final start = pageInChapter * _charsPerPage;
    final end = start + _charsPerPage > content.length
        ? content.length
        : start + _charsPerPage;
    return _ReadingPageContent(
      children: [
        if (pageInChapter == 0) _buildChapterHeader(chapterIndex),
        Text(
          content.substring(start, end),
          style: TextStyle(fontSize: readerFontSize, height: 2.05),
        ),
      ],
    );
  }

  Future<void> _insertImagePage(
    String imagePath, {
    String label = 'AI 生成图片',
  }) async {
    if (_totalPages == 0) return;
    final anchor = _flatPages[currentPage].textGlobal;
    final entry = _AiImagePageEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      image: imagePath,
      label: label,
      afterTextPage: anchor,
    );
    _imagePages.add(entry);
    await AiImagePageStore.save(widget.bookTitle, _imagePages);
    if (!mounted) return;
    setState(() => _flatCache = null);
    final newIndex = _flatIndexOfImagePage(entry.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && readingPages.hasClients) {
        readingPages.jumpToPage(newIndex);
        setState(() => currentPage = newIndex);
      }
    });
  }

  int _flatIndexOfImagePage(String id) {
    final flat = _flatPages;
    for (var i = 0; i < flat.length; i++) {
      if (flat[i].imageId == id) return i;
    }
    return 0;
  }

  Future<void> _confirmRemoveImagePage(_ReaderFlatPage flat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这张图片页？'),
        content: const Text('从当前小说中移除这张 AI 图片页。'),
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
    if (confirmed != true || !mounted) return;
    _imagePages.removeWhere((e) => e.id == flat.imageId);
    await AiImagePageStore.save(widget.bookTitle, _imagePages);
    if (!mounted) return;
    setState(() => _flatCache = null);
    final target = _flatIndexOfTextGlobal(
      flat.textGlobal,
    ).clamp(0, _totalPages - 1).toInt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && readingPages.hasClients) {
        readingPages.jumpToPage(target);
      }
    });
  }

  void _showAiImageActions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: background,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: Text(
                '插入 AI 图片页',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: gold),
              title: const Text('生成新图片并插入本书'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final path = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookAiGeneratePage(
                      title: widget.bookTitle,
                      insertMode: true,
                    ),
                  ),
                );
                if (path != null && mounted) {
                  await _insertImagePage(path);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: gold),
              title: const Text('从 AI 图片库导入'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final path = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookAiGalleryPage(
                      title: widget.bookTitle,
                      pickMode: true,
                    ),
                  ),
                );
                if (path != null && mounted) {
                  await _insertImagePage(path);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    readingPages.dispose();
    super.dispose();
  }

  String get _bookmarksKey => 'bookmarks_${widget.bookTitle}';

  Future<void> _loadBookmarks() async {
    final p = await SharedPreferences.getInstance();
    final loaded = <_ReaderBookmark>[];
    final pages = <int>{};
    final raw = p.getStringList(_bookmarksKey) ?? const <String>[];
    for (final item in raw) {
      final parts = item.split(':');
      if (parts.length != 2) continue;
      final c = int.tryParse(parts[0]);
      final pg = int.tryParse(parts[1]);
      if (c == null || pg == null || c < 1 || c > _chapterCount) continue;
      if (pg < 0 || pg >= _chapterPageCounts[c - 1]) continue;
      loaded.add(_ReaderBookmark(c, pg, '红烛摇曳，簌字高悬。'));
      final global = _flatIndexOfTextPage(c - 1, pg);
      if (global >= 0 && global < _totalPages) pages.add(global);
    }
    for (var i = 1; i <= _chapterCount; i++) {
      final legacy = p.getBool('bookmark_${widget.bookTitle}_$i') ?? false;
      final pg = p.getInt('bookmark_page_${widget.bookTitle}_$i');
      if (legacy &&
          pg != null &&
          pg >= 0 &&
          pg < _chapterPageCounts[i - 1] &&
          !loaded.any((b) => b.chapter == i && b.page == pg)) {
        loaded.add(_ReaderBookmark(i, pg, '红烛摇曳，簌字高悬。'));
        final global = _flatIndexOfTextPage(i - 1, pg);
        if (global >= 0 && global < _totalPages) pages.add(global);
      }
    }
    _savedChapterPage =
        p.getInt('reading_page_${widget.bookTitle}_${widget.chapter}') ?? 0;
    if (mounted) {
      setState(() {
        bookmarks
          ..clear()
          ..addAll(loaded);
        bookmarkedPages
          ..clear()
          ..addAll(pages);
      });
    }
  }

  Future<void> _persistBookmarks() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _bookmarksKey,
      bookmarks.map((b) => '${b.chapter}:${b.page}').toList(),
    );
  }

  void _persistReadingPosition() {
    final flat = _locationOf(currentPage);
    if (flat.isImage) return;
    SharedPreferences.getInstance().then((p) {
      p.setInt(
        'reading_page_${widget.bookTitle}_${flat.chapterIndex + 1}',
        flat.pageInChapter,
      );
      p.setInt('reading_chapter_${widget.bookTitle}', flat.chapterIndex + 1);
    });
  }

  Future<void> _markBookmark() async {
    final flat = _locationOf(currentPage);
    if (flat.isImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1200),
          content: Text('图片页不支持添加书签'),
        ),
      );
      return;
    }
    final chapter = flat.chapterIndex + 1;
    final pageInChapter = flat.pageInChapter;
    if (!bookmarked) {
      setState(() {
        bookmarked = true;
        bookmarkedPages.add(currentPage);
      });
    }
    if (!bookmarks.any(
      (b) => b.chapter == chapter && b.page == pageInChapter,
    )) {
      setState(
        () => bookmarks.add(
          _ReaderBookmark(chapter, pageInChapter, '红烛摇曳，簌字高悬。'),
        ),
      );
    }
    await _persistBookmarks();
  }

  Future<void> _addBookmark() async {
    await _markBookmark();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: gold,
          duration: const Duration(milliseconds: 1200),
          content: Row(
            children: [
              const Icon(Icons.bookmark, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                '书签已添加 · 第$_currentChapterNumber章 · 第${_currentPageInChapter + 1}页',
              ),
            ],
          ),
        ),
      );
    setState(() {});
  }

  Future<void> _toggleBookmark() async {
    if (bookmarked) {
      await _unmarkCurrentBookmark();
    } else {
      await _addBookmark();
    }
  }

  Future<void> _unmarkCurrentBookmark() async {
    final flat = _locationOf(currentPage);
    if (flat.isImage) return;
    if (!mounted) return;
    setState(() {
      bookmarked = false;
      bookmarkedPages.remove(currentPage);
      bookmarks.removeWhere(
        (b) =>
            b.chapter == flat.chapterIndex + 1 && b.page == flat.pageInChapter,
      );
    });
    await _persistBookmarks();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1200),
          content: Text('书签已删除'),
        ),
      );
  }

  Future<void> _deleteBookmark(
    _ReaderBookmark bookmark, [
    VoidCallback? refreshSheet,
  ]) async {
    setState(() {
      bookmarks.removeWhere(
        (b) => b.chapter == bookmark.chapter && b.page == bookmark.page,
      );
      if (bookmark.chapter >= 1 && bookmark.chapter <= _chapterCount) {
        final global = _flatIndexOfTextPage(
          bookmark.chapter - 1,
          bookmark.page,
        );
        bookmarkedPages.remove(global);
        if (bookmark.chapter == _currentChapterNumber &&
            bookmark.page == _currentPageInChapter) {
          bookmarked = false;
        }
      }
    });
    await _persistBookmarks();
    refreshSheet?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1200),
        content: Text('书签已删除'),
      ),
    );
  }

  Future<void> _confirmDeleteBookmark(
    _ReaderBookmark bookmark, [
    VoidCallback? refreshSheet,
  ]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除书签？'),
        content: Text('确定删除第${bookmark.chapter}章第${bookmark.page + 1}页的书签吗？'),
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
    if (confirmed == true && mounted) {
      await _deleteBookmark(bookmark, refreshSheet);
    }
  }

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
    setState(() => pullOffset = 0);
    if (!shouldBookmark) return;
    final adding = !bookmarked;
    await _toggleBookmark();
    if (!mounted) return;
    setState(() {
      pullBookmarkLabel = '书签';
      pullBookmarkBadge = adding;
    });
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => pullBookmarkBadge = false);
    });
  }

  void _toggleTheme() {
    appDarkMode.value = !appDarkMode.value;
    ThemePreferenceStore.save();
    if (mounted) setState(() {});
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
                                            _confirmDeleteBookmark(
                                              b,
                                              () => setSheetState(() {}),
                                            ),
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
                                            readingPages.jumpToPage(
                                              _flatIndexOfTextPage(
                                                b.chapter - 1,
                                                b.page,
                                              ),
                                            );
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

  @override
  Widget build(BuildContext context) {
    final readerProgress = _totalPages == 0
        ? 0.0
        : (currentPage + 1) / _totalPages;
    if (_ready && importedWork == null) {
      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(backgroundColor: background, title: const Text('阅读器')),
        body: const Center(child: Text('没有找到这本作品，请先导入小说')),
      );
    }
    final controlsVisible = focused || !readerImmersive;
    return Scaffold(
      backgroundColor: background,
      appBar: controlsVisible
          ? AppBar(
              backgroundColor: background,
              title: Text(
                '第$_currentChapterNumber章、$chapterName',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: controlsVisible
                  ? [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz),
                        onSelected: (value) {
                          if (value == 'bookmark') _toggleBookmark();
                          if (value == 'search') _showGlobalSearch();
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'bookmark',
                            child: Text(bookmarked ? '删除书签' : '添加书签'),
                          ),
                          const PopupMenuItem(
                            value: 'search',
                            child: Text('全局搜索'),
                          ),
                        ],
                      ),
                    ]
                  : [],
            )
          : null,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            setState(() => focused = readerImmersive ? !focused : true),
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 0 || pullOffset > 0) {
            setState(
              () => pullOffset = (pullOffset + details.delta.dy).clamp(0, 110),
            );
          }
        },
        onVerticalDragEnd: (_) => _finishPullDown(),
        child: Stack(
          children: [
            Transform.translate(
              offset: Offset(0, pullOffset),
              child: Column(
                children: [
                  Expanded(
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity((1 - brightness) * .35),
                        BlendMode.darken,
                      ),
                      child: PageView.builder(
                        controller: readingPages,
                        pageSnapping: readerPageTurn,
                        onPageChanged: (page) {
                          setState(() {
                            currentPage = page;
                            bookmarked = bookmarkedPages.contains(page);
                          });
                          _persistReadingPosition();
                        },
                        itemCount: _ready ? _totalPages : 1,
                        itemBuilder: (_, page) => _ready
                            ? _buildPage(page)
                            : const _ReadingPageContent(
                                children: [
                                  SizedBox(height: 24),
                                  Text(
                                    '加载中…',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  if (controlsVisible)
                    Container(
                      decoration: BoxDecoration(
                        color: surface,
                        border: Border(
                          top: BorderSide(color: Color(0xFFE5D8C2)),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$_currentChapterNumber/$_chapterCount',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: LinearProgressIndicator(
                                    value: readerProgress,
                                    minHeight: 3,
                                    color: gold,
                                    backgroundColor: Color(0xFFE5D8C2),
                                  ),
                                ),
                              ),
                              Text(
                                '${(readerProgress * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _ReaderTool(
                                icon: Icons.list,
                                label: '目录',
                                onTap: _showChapters,
                              ),
                              _ReaderTool(
                                icon: Icons.wb_sunny_outlined,
                                label: '主题',
                                onTap: _toggleTheme,
                              ),
                              _ReaderTool(
                                icon: Icons.image_outlined,
                                label: 'AI图片',
                                onTap: _showAiImageActions,
                              ),
                              _ReaderTool(
                                icon: Icons.cloud_outlined,
                                label: '设定集',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => Scaffold(
                                      backgroundColor: background,
                                      appBar: AppBar(
                                        backgroundColor: background,
                                        title: Text(
                                          '${widget.bookTitle} · 设定集',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      body: Worlds(
                                        initialTitle: widget.bookTitle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _ReaderTool(
                                icon: Icons.settings_outlined,
                                label: '设置',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ReadingPreferencesPage(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.wb_sunny_outlined, size: 18),
                              Expanded(
                                child: Slider(
                                  value: brightness,
                                  min: .2,
                                  max: 1,
                                  divisions: 8,
                                  label: '${(brightness * 100).round()}%',
                                  onChanged: (v) =>
                                      setState(() => brightness = v),
                                  activeColor: const Color(0xFF665F56),
                                ),
                              ),
                              const Icon(Icons.add, size: 18),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              top: (bookmarked || pullBookmarkBadge) ? 0 : -54,
              right: 18,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFD94040),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark, color: Colors.white, size: 18),
                    SizedBox(width: 5),
                    Text(
                      pullBookmarkLabel,
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
