part of '../../main.dart';

class Gallery extends StatefulWidget {
  const Gallery({super.key});
  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  List<_ImportedWork> works = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await ImportedWorkStore.loadAll();
    await AiGalleryStore.load();
    if (mounted) setState(() => works = loaded);
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      const Text(
        'AI IMAGE LIBRARY',
        style: TextStyle(
          color: gold,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
      const Text(
        'AI 生图',
        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 18),
      const Text(
        '选择作品，进入该作品的 AI 图片集合',
        style: TextStyle(color: Colors.black54),
      ),
      const SizedBox(height: 12),
      if (works.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: Text('暂无作品，请先在“作品”中导入小说')),
        ),
      ...works.map(
        (work) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookAiGalleryPage(title: work.title),
              ),
            ),
            borderRadius: BorderRadius.circular(16),
            child: card(
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 64,
                      height: 76,
                      child: work.cover.isEmpty
                          ? const ColoredBox(
                              color: Color(0xFFE8DED0),
                              child: Icon(Icons.menu_book_outlined),
                            )
                          : AiImagePreview(
                              image: work.cover,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          work.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${AiGalleryStore.items.where((item) => item.bookTitle == work.title).length} 张图片',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '点击查看 AI 图片',
                          style: TextStyle(
                            color: gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: gold),
                ],
              ),
            ),
          ),
        ),
      ),
      if (AiGalleryStore.items.any((item) => item.bookTitle.isEmpty))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const BookAiGalleryPage(title: '', initialCategory: 3),
              ),
            ),
            borderRadius: BorderRadius.circular(16),
            child: card(
              const ListTile(
                leading: Icon(Icons.photo_library_outlined, color: gold),
                title: Text('未归类图片'),
                subtitle: Text('从本机 AI 图片目录恢复的历史图片'),
                trailing: Icon(Icons.chevron_right, color: gold),
              ),
            ),
          ),
        ),
    ],
  );
}
