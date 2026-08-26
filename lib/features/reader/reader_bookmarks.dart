part of '../../main.dart';

extension _ReaderBookmarks on _ReaderPageState {
  String get _bookmarksKey => 'bookmarks_${widget.bookTitle}';

  Future<void> _loadBookmarks() async {
    final p = await SharedPreferences.getInstance();
    final loaded = <_ReaderBookmark>[];
    for (final item in p.getStringList(_bookmarksKey) ?? const <String>[]) {
      final parts = item.split(':');
      if (parts.length < 2) continue;
      final chapter = int.tryParse(parts[0]);
      final page = int.tryParse(parts[1]);
      if (chapter == null ||
          page == null ||
          chapter < 1 ||
          chapter > _chapterCount ||
          page < 0)
        continue;
      loaded.add(
        _ReaderBookmark(
          chapter,
          page,
          '第$chapter章',
          parts.length > 2 ? int.tryParse(parts[2]) ?? -1 : -1,
        ),
      );
    }
    for (var chapter = 1; chapter <= _chapterCount; chapter++) {
      final page = p.getInt('bookmark_page_${widget.bookTitle}_$chapter');
      if (p.getBool('bookmark_${widget.bookTitle}_$chapter') == true &&
          page != null &&
          page >= 0 &&
          !loaded.any((b) => b.chapter == chapter && b.page == page)) {
        loaded.add(_ReaderBookmark(chapter, page, '第$chapter章', -1));
      }
    }
    _savedTextOffset = p.getInt(
      'reading_offset_${widget.bookTitle}_${widget.chapter}',
    );
    _savedChapterPage =
        p.getInt('reading_page_${widget.bookTitle}_${widget.chapter}') ?? 0;
    if (!mounted) return;
    bookmarks
      ..clear()
      ..addAll(loaded);
    _projectBookmarks();
  }

  void _projectBookmarks() {
    bookmarkedPages.clear();
    for (var i = 0; i < bookmarks.length; i++) {
      final mark = bookmarks[i];
      final chapter = mark.chapter - 1;
      if (!_completedChapters.contains(chapter)) continue;
      final page = mark.textOffset >= 0
          ? _pageForOffset(chapter, mark.textOffset)
          : mark.page.clamp(0, _chapterPages[chapter].length - 1);
      bookmarks[i] = _ReaderBookmark(
        mark.chapter,
        page,
        mark.preview,
        mark.textOffset >= 0
            ? mark.textOffset
            : _chapterPages[chapter][page].start,
      );
      bookmarkedPages.add(_flatIndexOfTextPage(chapter, page));
    }
  }

  Future<void> _persistBookmarks() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _bookmarksKey,
      bookmarks.map((b) => '${b.chapter}:${b.page}:${b.textOffset}').toList(),
    );
  }

  void _persistReadingPosition() {
    if (!_ready ||
        _totalPages == 0 ||
        !_completedChapters.contains(_currentChapterIndex))
      return;
    final flat = _locationOf(currentPage);
    if (flat.isImage) return;
    final offset = _chapterPages[flat.chapterIndex][flat.pageInChapter].start;
    SharedPreferences.getInstance().then((p) {
      p.setInt(
        'reading_offset_${widget.bookTitle}_${flat.chapterIndex + 1}',
        offset,
      );
      p.setInt(
        'reading_page_${widget.bookTitle}_${flat.chapterIndex + 1}',
        flat.pageInChapter,
      );
      p.setInt('reading_chapter_${widget.bookTitle}', flat.chapterIndex + 1);
    });
  }

  Future<void> _markBookmark() async {
    if (_totalPages == 0 || !_completedChapters.contains(_currentChapterIndex))
      return;
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
      _update(() {
        bookmarked = true;
        bookmarkedPages.add(currentPage);
      });
    }
    if (!bookmarks.any(
      (b) => b.chapter == chapter && b.page == pageInChapter,
    )) {
      _update(
        () => bookmarks.add(
          _ReaderBookmark(
            chapter,
            pageInChapter,
            '第$chapter章',
            _chapterPages[flat.chapterIndex][pageInChapter].start,
          ),
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
    _update(() {});
  }

  Future<void> _toggleBookmark() async {
    if (_totalPages == 0 || !_completedChapters.contains(_currentChapterIndex))
      return;
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
    _update(() {
      bookmarked = false;
      bookmarkedPages.remove(currentPage);
      bookmarks.removeWhere(
        (b) =>
            b.chapter == flat.chapterIndex + 1 && b.page == flat.pageInChapter,
      );
    });
    await _persistBookmarks();
    if (!mounted) return;
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
    _update(() {
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
}
