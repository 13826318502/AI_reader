part of '../../main.dart';

extension _ReaderImageActions on _ReaderPageState {
  Future<void> _insertImagePage(
    String imagePath, {
    String label = 'AI 生成图片',
  }) async {
    if (_totalPages == 0) return;
    final anchor = _flatPages[currentPage].textGlobal;
    final anchorPage = _flatPages.firstWhere(
      (page) => !page.isImage && page.textGlobal == anchor,
    );
    final entry = _AiImagePageEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      image: imagePath,
      label: label,
      afterTextPage: anchor,
      chapterIndex: anchorPage.chapterIndex,
      textOffset:
          _chapterPages[anchorPage.chapterIndex][anchorPage.pageInChapter]
              .start,
    );
    _imagePages.add(entry);
    await AiImagePageStore.save(widget.bookTitle, _imagePages);
    if (!mounted) return;
    _update(() => _flatCache = null);
    final newIndex = _flatIndexOfImagePage(entry.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) readerViewportKey.currentState?.jumpToPage(newIndex);
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
    _update(() => _flatCache = null);
    final target = _flatIndexOfTextGlobal(
      flat.textGlobal,
    ).clamp(0, _totalPages - 1).toInt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) readerViewportKey.currentState?.jumpToPage(target);
    });
  }

  void _showAiImageActions() {
    if (_totalPages == 0 || !_completedChapters.contains(_currentChapterIndex))
      return;
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
}
