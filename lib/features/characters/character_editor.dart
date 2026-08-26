part of '../../main.dart';

class CharacterEditorPage extends StatefulWidget {
  final _WorkCharacter initial;
  final String? workTitle;

  const CharacterEditorPage({required this.initial, this.workTitle, super.key});

  @override
  State<CharacterEditorPage> createState() => _CharacterEditorPageState();
}

class _CharacterEditorPageState extends State<CharacterEditorPage> {
  late final TextEditingController name;
  late final TextEditingController role;
  late final TextEditingController intro;
  late final TextEditingController appearance;
  late final TextEditingController personality;
  late final TextEditingController backgroundText;
  late final TextEditingController goal;
  late final TextEditingController firstAppearance;
  late String image;
  bool saving = false;
  bool picking = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    name = TextEditingController(text: c.name);
    role = TextEditingController(text: c.role);
    intro = TextEditingController(text: c.intro);
    appearance = TextEditingController(text: c.appearance);
    personality = TextEditingController(text: c.personality);
    backgroundText = TextEditingController(text: c.background);
    goal = TextEditingController(text: c.goal);
    firstAppearance = TextEditingController(text: c.firstAppearance);
    image = c.image;
  }

  @override
  void dispose() {
    name.dispose();
    role.dispose();
    intro.dispose();
    appearance.dispose();
    personality.dispose();
    backgroundText.dispose();
    goal.dispose();
    firstAppearance.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => picking = true);
    try {
      final selected = await CharacterStore.pickAndCopyImage();
      if (mounted && selected != null) setState(() => image = selected);
    } catch (error, stack) {
      await AppErrorLogStore.append(
        error: error,
        stack: stack,
        source: 'CharacterEditorImagePicker',
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('图片读取失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> _save() async {
    final trimmedName = name.text.trim();
    if (trimmedName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('角色姓名不能为空')));
      return;
    }
    if (saving) return;
    setState(() => saving = true);
    final updated = _WorkCharacter(
      id: widget.initial.id,
      name: trimmedName,
      role: role.text.trim().isEmpty ? '角色' : role.text.trim(),
      intro: intro.text.trim(),
      appearance: appearance.text.trim(),
      personality: personality.text.trim(),
      background: backgroundText.text.trim(),
      goal: goal.text.trim(),
      firstAppearance: firstAppearance.text.trim(),
      image: image,
    );
    if (widget.workTitle != null) {
      final characters = await CharacterStore.load(widget.workTitle!);
      final index = characters.indexWhere((item) => item.id == updated.id);
      if (index >= 0) {
        characters[index] = updated;
      } else {
        characters.insert(0, updated);
      }
      await CharacterStore.save(widget.workTitle!, characters);
    }
    if (!mounted) return;
    Navigator.pop(context, updated);
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 3 : 1,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: const Text('编辑角色卡'),
      actions: [
        TextButton(
          onPressed: saving ? null : _save,
          child: const Text('保存', style: TextStyle(color: gold)),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
      children: [
        Center(
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 120,
                  height: 150,
                  child: AiImagePreview(image: image, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: picking ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(picking ? '正在读取图片…' : '更换角色图片'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '基础信息',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              _field(name, '角色姓名 *'),
              _field(role, '角色定位', hint: '例如：女主、反派、师父'),
              _field(intro, '角色简介', maxLines: 4),
            ],
          ),
        ),
        const SizedBox(height: 12),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '详细资料',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              _field(appearance, '外貌特征', maxLines: 4),
              _field(personality, '性格特点', maxLines: 4),
              _field(backgroundText, '人物背景', maxLines: 4),
              _field(goal, '目标与动机', maxLines: 4),
              _field(firstAppearance, '首次出场', hint: '例如：第 1 章'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: gold),
            child: Text(saving ? '正在保存…' : '保存角色卡'),
          ),
        ),
      ],
    ),
  );
}
