part of '../../main.dart';

class Shelf extends StatefulWidget {
  const Shelf({super.key});
  @override
  State<Shelf> createState() => _ShelfState();
}

class _ShelfState extends State<Shelf> {
  bool grid = false;
  String query = '';
  final books = <List<String>>[];

  @override
  void initState() {
    super.initState();
    _loadImportedBook();
  }

  Future<void> _loadImportedBook() async {
    final works = await ImportedWorkStore.loadAll();
    if (!mounted) return;
    setState(() {
      books
        ..clear()
        ..addAll(
          works.map(
            (work) => [
              work.cover,
              work.title,
              '本地导入 · ${work.chapters.length} 章 · 可阅读',
            ],
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = books.where((b) => b[1].contains(query)).toList();
    final body = visible.isEmpty
        ? const Padding(
            padding: EdgeInsets.only(top: 72),
            child: Center(child: Text('书架为空，请从“作品”导入小说')),
          )
        : grid
        ? GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: visible.map((b) => _gridBook(context, b)).toList(),
          )
        : Column(children: visible.map((b) => _listBook(context, b)).toList());
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 90),
          children: [
            const Text(
              'ARC READER',
              style: TextStyle(
                color: gold,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '我的书架',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(onPressed: _search, icon: const Icon(Icons.search)),
                IconButton(
                  onPressed: () => setState(() => grid = !grid),
                  icon: Icon(grid ? Icons.view_list : Icons.grid_view),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text(
                  '本地作品',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 5),
                Text(
                  '(${visible.length})',
                  style: const TextStyle(color: Colors.black45),
                ),
              ],
            ),
            const SizedBox(height: 10),
            body,
          ],
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: FloatingActionButton.extended(
            backgroundColor: gold,
            foregroundColor: Colors.white,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Works()),
              );
              _loadImportedBook();
            },
            icon: const Icon(Icons.add),
            label: const Text('导入作品'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteFromShelf(
    BuildContext context,
    String title,
  ) async {
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
    if (confirmed != true || !mounted) return;
    await ImportedWorkStore.delete(title);
    if (!mounted) return;
    setState(() => books.removeWhere((book) => book[1] == title));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('作品已删除'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  Future<void> _showBookActions(BuildContext context, String title) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除小说'),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: gold),
              title: const Text('从 AI 生图导入小说封面'),
              onTap: () => Navigator.pop(sheetContext, 'cover'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'delete') {
      await _confirmDeleteFromShelf(context, title);
      return;
    }
    if (action != 'cover') return;
    final image = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => BookAiGalleryPage(title: title, pickMode: true),
      ),
    );
    if (image == null || image.isEmpty) return;
    final work = await ImportedWorkStore.find(title);
    if (work == null) return;
    await ImportedWorkStore.save(work.copyWith(cover: image));
    await _loadImportedBook();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('小说封面已更新，所有页面已同步')));
    }
  }

  Widget _listBook(BuildContext context, List<String> b) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: () => _openBook(context, b[1]),
      onLongPress: () => _showBookActions(context, b[1]),
      child: card(
        Row(
          children: [
            cover(b[0]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b[1],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    b[2],
                    style: const TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: gold),
          ],
        ),
      ),
    ),
  );
  Widget _gridBook(BuildContext context, List<String> b) => InkWell(
    onTap: () => _openBook(context, b[1]),
    onLongPress: () => _showBookActions(context, b[1]),
    child: card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: b[0].isEmpty
                ? const ColoredBox(
                    color: Color(0xFFE8DED0),
                    child: Center(child: Icon(Icons.menu_book_outlined)),
                  )
                : AiImagePreview(image: b[0], fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          Text(
            b[1],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            b[2],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 10),
          ),
        ],
      ),
    ),
  );
  Future<void> _search() async {
    final c = TextEditingController(text: query);
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('搜索书架'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入书名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('清空'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('搜索'),
          ),
        ],
      ),
    );
    if (value != null) setState(() => query = value.trim());
  }

  Future<void> _openBook(BuildContext context, String title) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookDetail(title: title)),
    );
    await _loadImportedBook();
  }
}
