part of '../../main.dart';

class BookAiGeneratePage extends StatefulWidget {
  final String title;
  final bool insertMode;
  const BookAiGeneratePage({
    required this.title,
    this.insertMode = false,
    super.key,
  });
  @override
  State<BookAiGeneratePage> createState() => _BookAiGeneratePageState();
}

class _BookAiGeneratePageState extends State<BookAiGeneratePage> {
  int mode = 0;
  int category = 0;
  bool generating = false;
  final prompt = TextEditingController();
  final List<_ReferenceImage> references = [];

  @override
  void dispose() {
    prompt.dispose();
    super.dispose();
  }

  Future<void> _pickReference() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final List<_ReferenceImage> picked = [];
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      final bytes = await File(path).readAsBytes();
      final lowerPath = path.toLowerCase();
      final mime = lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')
          ? 'jpeg'
          : lowerPath.endsWith('.webp')
          ? 'webp'
          : 'png';
      picked.add(
        _ReferenceImage(
          name: file.name,
          base64: 'data:image/$mime;base64,${base64Encode(bytes)}',
        ),
      );
    }
    if (picked.isEmpty) return;
    setState(() => references.addAll(picked));
  }

  Future<void> _pickReferenceFromGallery() async {
    final image = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => BookAiGalleryPage(title: widget.title, pickMode: true),
      ),
    );
    if (!mounted || image == null || image.isEmpty) return;
    try {
      final bytes = await File(image).readAsBytes();
      final lowerPath = image.toLowerCase();
      final mime = lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')
          ? 'jpeg'
          : lowerPath.endsWith('.webp')
          ? 'webp'
          : 'png';
      setState(() {
        references.add(
          _ReferenceImage(
            name: 'AI生成图',
            base64: 'data:image/$mime;base64,${base64Encode(bytes)}',
          ),
        );
      });
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法读取这张 AI 生成图片')));
    }
  }

  void _removeReference(int index) {
    setState(() => references.removeAt(index));
  }

  Future<void> _generate() async {
    if (generating) return;
    setState(() => generating = true);
    try {
      final categoryName = ['场景', '人物', '物品', '其他'][category];
      final result = await AiImageService.generate(
        prompt:
            '${prompt.text.trim()}，${categoryName}类小说插画，${mode == 0 ? '参考图风格' : '高质量原创构图'}',
        size: category == 1 ? '1024x1536' : '1536x1024',
        referenceImages: mode == 0 && references.isNotEmpty
            ? [for (final r in references) r.base64]
            : null,
      );
      final localImage = await AiImageStorage.save(result, prefix: 'gallery');
      await AiGalleryStore.add(
        bookTitle: widget.title,
        category: category,
        prompt: prompt.text.trim(),
        image: localImage ?? result,
        label: 'AI生成图片',
      );
      if (!mounted) return;
      if (widget.insertMode) {
        Navigator.pop(context, localImage ?? result);
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              BookAiGalleryPage(title: widget.title, initialCategory: category),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Bad state: ', '')),
            duration: const Duration(milliseconds: 1200),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: const Text(
        'AI 生成图片',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      children: [
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择生图方式',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _GenerateChoice(
                      label: '根据参考图生成',
                      selected: mode == 0,
                      onTap: () => setState(() => mode = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _GenerateChoice(
                      label: '从零生成',
                      selected: mode == 1,
                      onTap: () => setState(() => mode = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text('图片归类', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(
                  4,
                  (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 3 ? 0 : 8),
                      child: _GenerateChoice(
                        label: ['场景', '人物', '物品', '其他'][i],
                        selected: category == i,
                        onTap: () => setState(() => category = i),
                      ),
                    ),
                  ),
                ),
              ),
              if (mode == 0) ...[
                const SizedBox(height: 18),
                const Text(
                  '参考图片（可多张，按导入顺序编号）',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (references.isNotEmpty) ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < references.length; i++)
                        _ReferenceThumb(
                          index: i,
                          image: references[i],
                          onRemove: () => _removeReference(i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickReference,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(references.isEmpty ? '上传手机图片' : '继续上传'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickReferenceFromGallery,
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('从 AI 生图导入'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '提示：可一次导入多张参考图，模型会按导入顺序编号区分图片，例如“第一张图片的人物按照第二张图片的姿势”。',
                  style: TextStyle(color: Colors.black45, fontSize: 11),
                ),
              ],
              const SizedBox(height: 18),
              const Text('画面描述', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              TextField(
                controller: prompt,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '描述你想生成的画面……',
                  counterText: '0/300',
                  filled: true,
                  fillColor: Color(0xFFFCF7ED),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE5D8C2)),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    generating ? '生成中…' : '生成图片',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: FilledButton.styleFrom(backgroundColor: gold),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReferenceThumb extends StatelessWidget {
  final int index;
  final _ReferenceImage image;
  final VoidCallback onRemove;
  const _ReferenceThumb({
    required this.index,
    required this.image,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = base64Decode(image.base64.split(',').last);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5D8C2)),
            color: const Color(0xFFFCF7ED),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.memory(
              bytes,
              width: 92,
              height: 92,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.black38,
                size: 30,
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: gold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _GenerateChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GenerateChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      decoration: BoxDecoration(
        color: selected ? gold : const Color(0xFFFCF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? gold : const Color(0xFFE5D8C2)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
          ),
        ),
      ),
    ),
  );
}
