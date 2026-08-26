part of '../../main.dart';

extension _ReaderLayout on _ReaderPageState {
  Widget _buildReader(BuildContext context) {
    final readerProgress = _readingProgress;
    if (_readerError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('阅读器')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_readerError!),
              FilledButton(
                onPressed: () {
                  _update(() {});
                  _init();
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (_ready && (importedWork == null || _chapterCount == 0)) {
      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(backgroundColor: background, title: const Text('阅读器')),
        body: const Center(child: Text('没有找到这本作品，请先导入小说')),
      );
    }
    final controlsVisible = focused || !readerImmersive;
    final readerBackground = readerTheme == 'dark'
        ? const Color(0xFF17212B)
        : readerTheme == 'green'
        ? const Color(0xFFE7F0E4)
        : background;
    final readerInk = readerTheme == 'dark'
        ? Colors.white.withOpacity(.92)
        : const Color(0xFF2B2926);
    return Scaffold(
      extendBodyBehindAppBar: readerImmersive,
      backgroundColor: readerBackground,
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
        onTap: () => _update(() {
          focused = readerImmersive ? !focused : true;
        }),
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 0 || pullOffset > 0) {
            _update(
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
                        readerEyeCare
                            ? const Color(0x18D99A3D)
                            : Colors.black.withOpacity((1 - brightness) * .35),
                        BlendMode.darken,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: readerBackground,
                          gradient: readerTheme == 'dark'
                              ? null
                              : const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFF7EFE2),
                                    Color(0xFFF1E4D1),
                                    Color(0xFFF8EEDD),
                                  ],
                                ),
                        ),
                        child: DefaultTextStyle(
                          style: TextStyle(color: readerInk),
                          child: SafeArea(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                if (_ready)
                                  _recalculatePageCapacity(constraints.biggest);
                                return _BookReaderViewport(
                                  key: readerViewportKey,
                                  pageCount: _ready ? _totalPages : 1,
                                  initialPage: currentPage,
                                  mode: readerPageTurn
                                      ? readerPageMode
                                      : 'none',
                                  onPageChanged: _onReaderPageChanged,
                                  pageBuilder: (page) => _ready
                                      ? _buildPage(page)
                                      : const _ReadingPageContent(
                                          children: [
                                            SizedBox(height: 24),
                                            Text(
                                              '加载中…',
                                              style: TextStyle(
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!readerImmersive) _buildControls(readerProgress),
                ],
              ),
            ),
            if (controlsVisible && readerImmersive)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: _buildControls(readerProgress),
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

  Widget _buildControls(double readerProgress) => Container(
    decoration: BoxDecoration(
      color: surface,
      border: Border(top: BorderSide(color: Color(0xFFE5D8C2))),
    ),
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_currentChapterNumber/$_chapterCount',
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
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
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        body: Worlds(initialTitle: widget.bookTitle),
                      ),
                    ),
                  ),
                ),
                _ReaderTool(
                  icon: Icons.settings_outlined,
                  label: '设置',
                  onTap: _openReadingPreferences,
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
                    onChanged: (v) => _update(() => brightness = v),
                    activeColor: const Color(0xFF665F56),
                  ),
                ),
                const Icon(Icons.add, size: 18),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
