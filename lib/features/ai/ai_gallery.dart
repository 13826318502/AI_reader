part of '../../main.dart';

class _AiGalleryItem {
  final String bookTitle;
  final String image;
  final String label;
  final int category;
  const _AiGalleryItem(this.bookTitle, this.image, this.label, this.category);

  Map<String, dynamic> toJson() => {
    'bookTitle': bookTitle,
    'image': image,
    'label': label,
    'category': category,
  };

  factory _AiGalleryItem.fromJson(Map<String, dynamic> json) => _AiGalleryItem(
    json['bookTitle']?.toString() ?? '',
    json['image']?.toString() ?? '',
    json['label']?.toString() ?? 'AI 图片',
    (json['category'] as num?)?.toInt() ?? 0,
  );
}

class AiGalleryStore {
  static final items = <_AiGalleryItem>[];
  static const storageKey = 'ai_gallery_items';

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(storageKey) ?? const [];
    items
      ..clear()
      ..addAll(
        raw.map((value) {
          try {
            final json = jsonDecode(value);
            return json is Map
                ? _AiGalleryItem.fromJson(Map<String, dynamic>.from(json))
                : null;
          } catch (_) {
            return null;
          }
        }).whereType<_AiGalleryItem>(),
      );
    await _recoverUnregisteredFiles();
  }

  static Future<void> _recoverUnregisteredFiles() async {
    final files = await AiImageStorage.imageFiles();
    final registered = items.map((item) => item.image).toSet();
    for (final file in files) {
      if (registered.contains(file.path)) continue;
      items.add(_AiGalleryItem('', file.path, '未归类图片', 3));
    }
    if (items.length != registered.length) await _save();
  }

  static Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      storageKey,
      items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  static Future<void> clear() async {
    items.clear();
    final p = await SharedPreferences.getInstance();
    await p.remove(storageKey);
  }

  static Future<void> add({
    required String bookTitle,
    required int category,
    required String prompt,
    required String image,
    String? label,
  }) async {
    items.insert(
      0,
      _AiGalleryItem(bookTitle, image, label ?? 'AI生成图片', category),
    );
    await _save();
  }

  static Future<void> renameBook(String oldTitle, String newTitle) async {
    var changed = false;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.bookTitle != oldTitle) continue;
      items[i] = _AiGalleryItem(
        newTitle,
        item.image,
        item.label,
        item.category,
      );
      changed = true;
    }
    if (changed) await _save();
  }
}

class BookAiGalleryPage extends StatefulWidget {
  final String title;
  final bool pickMode;
  final int initialCategory;
  const BookAiGalleryPage({
    required this.title,
    this.pickMode = false,
    this.initialCategory = 0,
    super.key,
  });
  @override
  State<BookAiGalleryPage> createState() => _BookAiGalleryPageState();
}

class _BookAiGalleryPageState extends State<BookAiGalleryPage> {
  int category = 0;
  final categories = const ['场景', '人物', '物品', '其他'];

  @override
  void initState() {
    super.initState();
    category = widget.initialCategory.clamp(0, 3).toInt();
    AiGalleryStore.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  List<_AiGalleryItem> get visibleImages => AiGalleryStore.items
      .where(
        (item) =>
            item.bookTitle == widget.title &&
            (widget.pickMode || item.category == category),
      )
      .toList();

  Future<void> _importImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (!mounted) return;
    if (result != null && result.files.single.bytes != null) {
      final folder = await AiImageStorage.directory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${folder.path}/import_$stamp.png');
      await file.writeAsBytes(result.files.single.bytes!, flush: true);
      await AiGalleryStore.add(
        bookTitle: widget.title,
        category: category,
        prompt: result.files.single.name,
        image: file.path,
        label: result.files.single.name,
      );
      if (mounted) setState(() {});
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1200),
        content: Text(
          result == null ? '已取消导入' : '图片已导入到${categories[category]}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0F1E2D),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0F1E2D),
      foregroundColor: Colors.white,
      title: Text(
        '${widget.title} · AI 图片',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'folder') AiImageStorage.openDirectory();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'folder', child: Text('打开 AI 图片文件夹')),
          ],
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: List.generate(
              categories.length,
              (i) => Expanded(
                child: _GalleryTab(
                  label: categories[i],
                  selected: category == i,
                  onTap: () => setState(() => category = i),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: .92,
            ),
            itemCount: visibleImages.length,
            itemBuilder: (_, i) {
              final item = visibleImages[i];
              if (widget.pickMode) {
                return InkWell(
                  onTap: () => Navigator.pop(context, item.image),
                  child: _GalleryImage(image: item.image, label: item.label),
                );
              }
              return _GalleryImage(image: item.image, label: item.label);
            },
          ),
        ),
        if (!widget.pickMode)
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF142A3D),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BookAiGeneratePage(title: widget.title),
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('AI 生成图片'),
                      style: FilledButton.styleFrom(backgroundColor: gold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _importImage,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('导入图片'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _GalleryTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GalleryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? gold : Colors.white12,
            width: selected ? 2 : 1,
          ),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
          ),
        ),
      ),
    ),
  );
}

class _GalleryImage extends StatelessWidget {
  final String image;
  final String label;
  const _GalleryImage({required this.image, required this.label});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Stack(
      fit: StackFit.expand,
      children: [
        AiImagePreview(image: image, fit: BoxFit.cover),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black54,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ReferenceImage {
  final String name;
  final String base64;
  const _ReferenceImage({required this.name, required this.base64});
}
