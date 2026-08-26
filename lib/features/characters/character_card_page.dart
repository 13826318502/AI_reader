part of '../../main.dart';

class CharacterCardPage extends StatefulWidget {
  final String name;
  final String role;
  final String image;
  final String intro;
  final String appearance;
  final String personality;
  final String background;
  final String goal;
  final String firstAppearance;
  final String? workTitle;
  final String? characterId;
  const CharacterCardPage({
    required this.name,
    required this.role,
    required this.image,
    this.intro = '',
    this.appearance = '',
    this.personality = '',
    this.background = '',
    this.goal = '',
    this.firstAppearance = '',
    this.workTitle,
    this.characterId,
    super.key,
  });

  @override
  State<CharacterCardPage> createState() => _CharacterCardPageState();
}

class _CharacterCardPageState extends State<CharacterCardPage> {
  late _WorkCharacter current;

  @override
  void initState() {
    super.initState();
    current = _WorkCharacter(
      id:
          widget.characterId ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: widget.name,
      role: widget.role,
      intro: widget.intro,
      appearance: widget.appearance,
      personality: widget.personality,
      background: widget.background,
      goal: widget.goal,
      firstAppearance: widget.firstAppearance,
      image: widget.image,
    );
  }

  String get name => current.name;
  String get role => current.role;
  String get image => current.image;
  String get intro => current.intro;
  String get appearance => current.appearance;
  String get personality => current.personality;
  String get characterBackground => current.background;
  String get goal => current.goal;
  String get firstAppearance => current.firstAppearance;
  String get fullBodyImage => image;

  Future<void> _editCharacter() async {
    final updated = await Navigator.push<_WorkCharacter>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CharacterEditorPage(initial: current, workTitle: widget.workTitle),
      ),
    );
    if (updated != null && mounted) setState(() => current = updated);
  }

  Widget _detailSection() {
    final details = <MapEntry<String, String>>[
      MapEntry('外貌特征', appearance),
      MapEntry('性格特点', personality),
      MapEntry('人物背景', characterBackground),
      MapEntry('目标与动机', goal),
    ].where((entry) => entry.value.isNotEmpty).toList();
    if (details.isEmpty) {
      return card(
        const Text(
          '暂无详细资料，请点击右上角“编辑角色卡”补充。',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      );
    }
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '详细资料',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (final detail in details) ...[
            Text(
              detail.key,
              style: const TextStyle(
                color: gold,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              detail.value,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.55,
                fontSize: 13,
              ),
            ),
            if (detail != details.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: const Text('角色卡', style: TextStyle(fontWeight: FontWeight.w900)),
      actions: [
        IconButton(
          onPressed: _editCharacter,
          tooltip: '编辑角色卡',
          icon: const Icon(Icons.edit_outlined),
        ),
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
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: AiImagePreview(image: image, fit: BoxFit.cover),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -28),
          child: card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: gold,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '角色详情',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  intro.isEmpty ? '暂无角色简介，请点击右上角编辑。' : intro,
                  style: const TextStyle(
                    color: Colors.black54,
                    height: 1.65,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 0),
        _detailSection(),
        const SizedBox(height: 14),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '人物关系',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [Text('请在人物关系页面维护角色关系')],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    RelationMapPage(selectedName: name, selectedImage: image),
              ),
            ),
            icon: const Icon(Icons.hub_outlined),
            label: const Text(
              '查看人物关系图',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: gold,
              side: const BorderSide(color: gold),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _CharacterImageTile(title: '头像', image: image),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CharacterImageTile(title: '全身图', image: fullBodyImage),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CharacterAiPage(name: name, image: image),
              ),
            ),
            icon: const Icon(Icons.auto_awesome),
            label: const Text(
              'AI 生成人物形象',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: FilledButton.styleFrom(backgroundColor: gold),
          ),
        ),
      ],
    ),
  );
}
