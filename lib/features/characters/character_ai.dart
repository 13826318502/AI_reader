part of '../../main.dart';

class CharacterAiPage extends StatefulWidget {
  final String name;
  final String image;
  const CharacterAiPage({required this.name, required this.image, super.key});
  @override
  State<CharacterAiPage> createState() => _CharacterAiPageState();
}

class _CharacterAiPageState extends State<CharacterAiPage> {
  int mode = 0;
  bool generating = false;
  String? generatedImage;
  late final TextEditingController prompt = TextEditingController(
    text: '东方幻想风格，温柔坚韧，红色古典服饰，烛光氛围',
  );

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
            '${prompt.text.trim()}，${mode == 0 ? '人物头像，半身构图' : '人物全身立绘，全身构图'}',
        size: mode == 0 ? '1024x1024' : '1024x1536',
      );
      if (!mounted) return;
      setState(() => generatedImage = result);
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
      title: Text(
        '${widget.name} · AI 形象',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF112235),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '根据描述生成',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '为角色生成专属头像或全身形象',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _AiTab(
                      label: '头像',
                      selected: mode == 0,
                      onTap: () => setState(() => mode = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AiTab(
                      label: '全身图',
                      selected: mode == 1,
                      onTap: () => setState(() => mode = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: prompt,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '描述人物外貌、服饰、动作和氛围……',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: generatedImage == null
                    ? Image.asset(
                        widget.image,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
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
                    generating ? '生成中…' : '生成形象',
                    style: TextStyle(fontWeight: FontWeight.w800),
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
