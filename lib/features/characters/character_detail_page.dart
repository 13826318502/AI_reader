part of '../../main.dart';

class CharacterDetailPage extends StatelessWidget {
  final String name;
  final String role;
  final String image;
  final String intro;
  final String appearance;
  final String personality;
  final String characterBackground;
  final String goal;
  final String firstAppearance;
  final String? workTitle;
  final String? characterId;
  const CharacterDetailPage({
    required this.name,
    required this.role,
    required this.image,
    this.intro = '',
    this.appearance = '',
    this.personality = '',
    this.characterBackground = '',
    this.goal = '',
    this.firstAppearance = '',
    this.workTitle,
    this.characterId,
    super.key,
  });

  String get fullBodyImage => image;

  void _showImages(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: background,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$name · 人物形象',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AspectRatio(
                              aspectRatio: 3 / 4,
                              child: AiImagePreview(
                                image: image,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '头像',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AspectRatio(
                              aspectRatio: 3 / 4,
                              child: AiImagePreview(
                                image: fullBodyImage,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '全身图',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '点击下方“AI 生成人物形象”，可以根据描述重新生成头像和全身图。',
                  style: TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: const Text('角色详情', style: TextStyle(fontWeight: FontWeight.w900)),
      actions: [
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CharacterEditorPage(
                initial: _WorkCharacter(
                  id:
                      characterId ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  name: name,
                  role: role,
                  intro: intro,
                  appearance: appearance,
                  personality: personality,
                  background: characterBackground,
                  goal: goal,
                  firstAppearance: firstAppearance,
                  image: image,
                ),
                workTitle: workTitle,
              ),
            ),
          ),
          tooltip: '编辑角色卡',
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CharacterCardPage(
                name: name,
                role: role,
                image: image,
                intro: intro,
                workTitle: workTitle,
                characterId: characterId,
                appearance: appearance,
                personality: personality,
                background: characterBackground,
                goal: goal,
                firstAppearance: firstAppearance,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          child: card(
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFBF3), Color(0xFFF1E4CD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE1B461)),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _showImages(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 88,
                        height: 120,
                        child: AiImagePreview(image: image, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '角色档案',
                          style: TextStyle(
                            color: gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            color: Color(0xFF2C2925),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          role,
                          style: const TextStyle(
                            color: gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          '出场章节  1—8章',
                          style: TextStyle(color: Colors.black54, fontSize: 11),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          '与主角同行',
                          style: TextStyle(color: Colors.black54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
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
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(backgroundColor: gold),
          ),
        ),
        const SizedBox(height: 10),
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
              '查看角色关系图',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: gold,
              side: const BorderSide(color: gold),
            ),
          ),
        ),
        const SizedBox(height: 14),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('角色详情', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              Text(
                intro.isEmpty ? '暂无角色详情，请点击编辑补充资料。' : intro,
                style: const TextStyle(
                  color: Colors.black54,
                  height: 1.6,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('角色信息', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              _InfoLine(
                '首次出现',
                firstAppearance.isEmpty ? '暂无' : firstAppearance,
              ),
              _InfoLine('相关章节', '暂无'),
              _InfoLine('人物关系', '请在关系页面维护'),
            ],
          ),
        ),
      ],
    ),
  );
}
