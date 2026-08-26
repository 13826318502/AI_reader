part of '../../main.dart';

class AiImagePage extends StatefulWidget {
  const AiImagePage({super.key});
  @override
  State<AiImagePage> createState() => _AiImagePageState();
}

class _AiImagePageState extends State<AiImagePage> {
  int tab = 0;
  bool generating = false;
  String? generatedImage;
  String ratio = '横图 16:9';
  String style = '电影感';
  late final TextEditingController prompt = TextEditingController();

  @override
  void dispose() {
    prompt.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (generating) return;
    setState(() => generating = true);
    try {
      final result = await AiImageService.generate(
        prompt:
            '${prompt.text.trim().isEmpty ? (tab == 0 ? '小说人物' : '小说场景') : prompt.text.trim()}，$style，${ratio == '横图 16:9' ? '横构图' : '竖构图'}',
        size: ratio == '横图 16:9' ? '1536x1024' : '1024x1536',
      );
      final localImage = await AiImageStorage.save(result, prefix: 'character');
      if (!mounted) return;
      setState(() => generatedImage = localImage ?? result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('图片生成成功'),
          duration: Duration(milliseconds: 1200),
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
        'AI 生图（阅读中）',
        style: TextStyle(fontWeight: FontWeight.w900),
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
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            color: const Color(0xFF112235),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AI 生图',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _AiTab(
                      label: '角色',
                      selected: tab == 0,
                      onTap: () => setState(() => tab = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AiTab(
                      label: '场景',
                      selected: tab == 1,
                      onTap: () => setState(() => tab = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: prompt,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '描述你想生成的画面……',
                  hintStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '风格与比例',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...['横图 16:9', '竖图 3:4'].map(
                    (x) => _AiChoice(
                      label: x,
                      selected: ratio == x,
                      onTap: () => setState(() => ratio = x),
                    ),
                  ),
                  ...['电影感', '国风', '水墨'].map(
                    (x) => _AiChoice(
                      label: x,
                      selected: style == x,
                      onTap: () => setState(() => style = x),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                '生成预览',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: generatedImage == null
                    ? const SizedBox(
                        width: double.infinity,
                        height: 158,
                        child: ColoredBox(
                          color: Color(0xFF1B2E42),
                          child: Center(
                            child: Text(
                              '生成结果将在这里显示',
                              style: TextStyle(color: Colors.white60),
                            ),
                          ),
                        ),
                      )
                    : AiImagePreview(image: generatedImage!, fit: BoxFit.cover),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    generating ? '生成中…' : '生成图片',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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

class _AiTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AiTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF283A50) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    ),
  );
}

class _AiChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AiChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: selected ? gold : Colors.white12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? gold : Colors.white60,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    ),
  );
}
