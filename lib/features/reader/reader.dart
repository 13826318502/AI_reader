part of '../../main.dart';

class ReaderPage extends StatefulWidget {
  final int chapter;
  final String bookTitle;
  const ReaderPage({required this.chapter, required this.bookTitle, super.key});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  _ImportedWork? importedWork;
  bool focused = false;
  bool bookmarked = false;
  bool pullBookmarkBadge = false;
  String pullBookmarkLabel = '书签';
  double pullOffset = 0;
  double brightness = .86;
  double readerFontSize = 18;
  bool readerImmersive = true;
  bool readerPageTurn = true;
  bool readerEyeCare = false;
  String readerTheme = 'paper';
  String readerPageMode = 'curl';
  final GlobalKey<_BookReaderViewportState> readerViewportKey =
      GlobalKey<_BookReaderViewportState>();
  int currentPage = 0;
  final List<_ReaderBookmark> bookmarks = [];
  final Set<int> bookmarkedPages = {};
  List<_AiImagePageEntry> _imagePages = [];
  bool _ready = false;
  int _savedChapterPage = 0;
  List<List<TextRange>> _chapterPages = [];
  Size? _paginationSize;
  TextScaler? _paginationScaler;
  TextStyle? _paginationStyle;
  int? _savedTextOffset;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Size? _paginationTextSize;
  int _paginationGeneration = 0;
  int? _runningGeneration;
  final Set<int> _completedChapters = {};
  final List<int> _paginationQueue = [];
  String? _readerError;
  bool _persistPendingLocation = false;
  ({int chapter, int page, int? offset, String? imageId})? _pendingLocation;

  int _pageForOffset(int chapter, int offset) {
    if (chapter < 0 || chapter >= _chapterPages.length) return 0;
    final pages = _chapterPages[chapter];
    final index = pages.indexWhere((page) => page.end > offset);
    return index < 0 ? pages.length - 1 : index;
  }

  _AiImagePageEntry _anchorImage(
    _AiImagePageEntry image,
    List<_ReaderFlatPage> flat,
  ) {
    final page = flat.firstWhere(
      (page) => !page.isImage && page.textGlobal == image.afterTextPage,
      orElse: () => flat.lastWhere((page) => !page.isImage),
    );
    return _AiImagePageEntry(
      id: image.id,
      image: image.image,
      label: image.label,
      afterTextPage: image.afterTextPage,
      chapterIndex: page.chapterIndex,
      textOffset: _chapterPages[page.chapterIndex][page.pageInChapter].start,
    );
  }

  List<int> get _chapterPageCounts => [
    for (final pages in _chapterPages) pages.length,
  ];

  int get _chapterCount => importedWork?.chapters.length ?? 0;

  int _clampInt(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  List<_ReaderFlatPage>? _flatCache;

  List<_ReaderFlatPage> _computeFlatPages() {
    final counts = _chapterPageCounts;
    final imageMap = <int, List<_AiImagePageEntry>>{};
    for (final e in _imagePages) {
      if (e.chapterIndex == null && _completedChapters.length < _chapterCount) {
        continue;
      }
      if (e.chapterIndex != null &&
          !_completedChapters.contains(e.chapterIndex)) {
        continue;
      }
      var anchor = e.afterTextPage;
      final chapter = e.chapterIndex;
      if (chapter != null &&
          chapter >= 0 &&
          chapter < counts.length &&
          e.textOffset != null) {
        anchor =
            counts.take(chapter).fold<int>(0, (sum, count) => sum + count) +
            _pageForOffset(chapter, e.textOffset!);
      }
      imageMap.putIfAbsent(anchor, () => []).add(e);
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

  int get _currentChapterIndex =>
      _totalPages == 0 ? 0 : _locationOf(currentPage).chapterIndex;
  int get _currentChapterNumber => _currentChapterIndex + 1;
  int get _currentPageInChapter =>
      _totalPages == 0 ? 0 : _locationOf(currentPage).pageInChapter;

  int _initialGlobalPage() {
    if (_totalPages == 0) return 0;
    final counts = _chapterPageCounts;
    final chapterIndex = _clampInt(widget.chapter - 1, 0, _chapterCount - 1);
    final saved = _savedTextOffset != null
        ? _pageForOffset(chapterIndex, _savedTextOffset!)
        : _clampInt(_savedChapterPage, 0, counts[chapterIndex] - 1);
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
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: ReaderTextPaginator.headerStyle.copyWith(color: gold),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPage(int globalPage) {
    final flat = _locationOf(globalPage);
    if (!_completedChapters.contains(flat.chapterIndex)) {
      return const _ReadingPageContent(
        children: [
          SizedBox(height: 24),
          Text('正在排版本章…'),
          SizedBox(height: 12),
          LinearProgressIndicator(),
        ],
      );
    }
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
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: AiImagePreview(
                  image: flat.imagePath!,
                  fit: BoxFit.contain,
                ),
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
    final range = _chapterPages[chapterIndex][pageInChapter];
    return _ReadingPageContent(
      children: [
        if (pageInChapter == 0) _buildChapterHeader(chapterIndex),
        if (!range.isCollapsed)
          Text(
            content.substring(range.start, range.end).trimRight(),
            style: TextStyle(
              fontSize: readerFontSize,
              height: ReadingPreferencesStore.lineHeight,
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _paginationGeneration++;
    super.dispose();
  }

  void _update(VoidCallback action) {
    if (mounted) setState(action);
  }

  @override
  Widget build(BuildContext context) => _buildReader(context);
}
