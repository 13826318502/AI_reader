part of '../../main.dart';

extension _ReaderLoading on _ReaderPageState {
  Future<void> _init() async {
    final generation = ++_paginationGeneration;
    _readerError = null;
    _persistPendingLocation = false;
    _ready = false;
    _paginationSize = null;
    try {
      final results = await Future.wait([
        ReadingPreferencesStore.load(),
        ImportedWorkStore.find(widget.bookTitle),
      ]);
      if (!mounted || generation != _paginationGeneration) return;
      importedWork = results[1] as _ImportedWork?;
      readerFontSize = ReadingPreferencesStore.fontSize;
      readerImmersive = ReadingPreferencesStore.immersive;
      readerPageTurn = ReadingPreferencesStore.pageTurn;
      readerEyeCare = ReadingPreferencesStore.eyeCare;
      readerTheme = ReadingPreferencesStore.theme;
      readerPageMode = ReadingPreferencesStore.pageMode;
      _chapterPages = List.generate(
        _chapterCount,
        (_) => const [TextRange(start: 0, end: 0)],
      );
      _completedChapters.clear();
      _flatCache = null;
      await Future.wait([_loadImagePages(), _loadBookmarks()]);
      if (!mounted || generation != _paginationGeneration) return;
      _update(() {
        _ready = true;
        currentPage = _initialGlobalPage();
        _pendingLocation = (
          chapter: (widget.chapter - 1).clamp(
            0,
            (_chapterCount - 1).clamp(0, 1 << 30),
          ),
          page: _savedChapterPage,
          offset: _savedTextOffset,
          imageId: null,
        );
      });
    } catch (error, stack) {
      if (!mounted || generation != _paginationGeneration) return;
      _update(() => _readerError = '作品加载失败，请重试。原有作品和阅读记录未删除。');
      unawaited(
        AppErrorLogStore.append(
          error: error,
          stack: stack,
          source: 'reader_load',
        ),
      );
    }
  }

  Future<void> _loadImagePages() async {
    final loaded = await AiImagePageStore.load(widget.bookTitle);
    if (!mounted) return;
    _imagePages = loaded;
    _flatCache = null;
  }

  ({int chapter, int page, int? offset, String? imageId})? _captureLocation() {
    if (_pendingLocation != null) return _pendingLocation;
    if (_totalPages == 0) return null;
    final location = _locationOf(currentPage.clamp(0, _totalPages - 1));
    return (
      chapter: location.chapterIndex,
      page: location.pageInChapter,
      offset:
          location.isImage ||
              !_completedChapters.contains(location.chapterIndex)
          ? null
          : _chapterPages[location.chapterIndex][location.pageInChapter].start,
      imageId: location.imageId,
    );
  }

  void _recalculatePageCapacity([Size? viewport]) {
    if (!_ready || _chapterCount == 0) return;
    final size = viewport ?? _paginationSize ?? MediaQuery.sizeOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    final textSize = Size(
      (size.width - ReadingPreferencesStore.horizontalPadding * 2).clamp(
        1.0,
        double.infinity,
      ),
      (size.height - 40).clamp(1.0, double.infinity),
    );
    final style = TextStyle(
      fontSize: readerFontSize,
      height: ReadingPreferencesStore.lineHeight,
    );
    if (_paginationSize == size &&
        _paginationScaler == scaler &&
        _paginationStyle == style &&
        _paginationTextSize == textSize) {
      return;
    }
    final location = _captureLocation();
    _paginationSize = size;
    _paginationTextSize = textSize;
    _paginationScaler = scaler;
    _paginationStyle = style;
    _paginationGeneration++;
    _runningGeneration = null;
    _paginationQueue.clear();
    _completedChapters.clear();
    _chapterPages = List.generate(
      _chapterCount,
      (_) => const [TextRange(start: 0, end: 0)],
    );
    _flatCache = null;
    _pendingLocation = location;
    currentPage = _flatIndexOfTextPage(location?.chapter ?? 0, 0);
    _queueReadingWindow(location?.chapter ?? 0);
    if (_imagePages.any((image) => image.chapterIndex == null)) {
      for (var chapter = 0; chapter < _chapterCount; chapter++) {
        if (!_paginationQueue.contains(chapter)) _paginationQueue.add(chapter);
      }
    }
  }

  void _queueReadingWindow(int chapter) {
    for (final index in [chapter, chapter + 1, chapter - 1]) {
      if (index >= 0 &&
          index < _chapterCount &&
          !_completedChapters.contains(index) &&
          !_paginationQueue.contains(index)) {
        _paginationQueue.add(index);
      }
    }
    if (_paginationQueue.remove(chapter)) _paginationQueue.insert(0, chapter);
    if (_runningGeneration == _paginationGeneration ||
        _paginationTextSize == null) {
      return;
    }
    final generation = _paginationGeneration;
    _runningGeneration = generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _paginationGeneration) {
        unawaited(_runPagination(generation));
      }
    });
  }

  Future<void> _runPagination(int generation) async {
    final paginator = ReaderTextPaginator(
      size: _paginationTextSize!,
      style: _paginationStyle!,
      textScaler: _paginationScaler!,
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
    );
    bool cancelled() => !mounted || generation != _paginationGeneration;
    try {
      while (!cancelled() && _paginationQueue.isNotEmpty) {
        final chapter = _paginationQueue.removeAt(0);
        if (_completedChapters.contains(chapter)) continue;
        final source = importedWork!.chapters[chapter];
        final pages = await paginator.paginateAsync(
          source.content.trim(),
          title: _chapterHeaderText(chapter + 1, source.title),
          cancelled: cancelled,
        );
        if (pages == null || cancelled()) return;
        final location = _captureLocation();
        _update(() {
          _chapterPages[chapter] = pages;
          _completedChapters.add(chapter);
          _flatCache = null;
          if (_completedChapters.length == _chapterCount &&
              _imagePages.any((image) => image.chapterIndex == null)) {
            final flat = _flatPages;
            _imagePages = [
              for (final image in _imagePages)
                image.chapterIndex == null ? _anchorImage(image, flat) : image,
            ];
            _flatCache = null;
          }
          _projectBookmarks();
          if (location != null) {
            final complete = _completedChapters.contains(location.chapter);
            final page = complete
                ? location.offset != null
                      ? _pageForOffset(location.chapter, location.offset!)
                      : location.page.clamp(
                          0,
                          _chapterPages[location.chapter].length - 1,
                        )
                : 0;
            currentPage = location.imageId == null
                ? _flatIndexOfTextPage(location.chapter, page)
                : _flatIndexOfImagePage(location.imageId!);
            _pendingLocation = complete ? null : location;
          }
          bookmarked = bookmarkedPages.contains(currentPage);
        });
        if (_persistPendingLocation &&
            _completedChapters.contains(_currentChapterIndex)) {
          _persistPendingLocation = false;
          _persistReadingPosition();
        }
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    } catch (error, stack) {
      if (!cancelled()) {
        _update(() => _readerError = '章节排版失败，请重试或调整阅读字号。');
        unawaited(
          AppErrorLogStore.append(
            error: error,
            stack: stack,
            source: 'reader_pagination',
          ),
        );
      }
    } finally {
      if (_runningGeneration == generation) _runningGeneration = null;
    }
  }

  void _onReaderPageChanged(int page) {
    if (!_ready || _totalPages == 0 || currentPage == page) return;
    _update(() {
      currentPage = page.clamp(0, _totalPages - 1);
      _pendingLocation = null;
      _persistPendingLocation = !_completedChapters.contains(
        _currentChapterIndex,
      );
      bookmarked = bookmarkedPages.contains(currentPage);
      _queueReadingWindow(_currentChapterIndex);
    });
    _persistReadingPosition();
  }

  void _goToBookmark(_ReaderBookmark bookmark) {
    _update(() {
      final chapter = bookmark.chapter - 1;
      _pendingLocation = (
        chapter: chapter,
        page: bookmark.page,
        offset: bookmark.textOffset < 0 ? null : bookmark.textOffset,
        imageId: null,
      );
      currentPage = _flatIndexOfTextPage(
        chapter,
        _completedChapters.contains(chapter) ? bookmark.page : 0,
      );
      _queueReadingWindow(chapter);
      _persistPendingLocation = !_completedChapters.contains(chapter);
      if (_completedChapters.contains(chapter)) _pendingLocation = null;
    });
    _persistReadingPosition();
  }

  double get _readingProgress {
    final chapters = importedWork?.chapters;
    if (chapters == null || chapters.isEmpty || _totalPages == 0) return 0;
    var before = 0;
    var total = 0;
    for (var i = 0; i < chapters.length; i++) {
      total += chapters[i].content.length;
      if (i < _currentChapterIndex) before += chapters[i].content.length;
    }
    final location = _locationOf(currentPage);
    final offset = location.isImage
        ? 0
        : _chapterPages[location.chapterIndex][location.pageInChapter].end;
    return total == 0 ? 0 : ((before + offset) / total).clamp(0.0, 1.0);
  }
}
