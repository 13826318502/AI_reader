part of '../../main.dart';

class CharacterCard extends StatelessWidget {
  final String name;
  final String role;
  final String intro;
  final String image;
  const CharacterCard({
    required this.name,
    required this.role,
    required this.image,
    this.intro = '故事中的重要角色。',
    super.key,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CharacterDetailPage(name: name, role: role, image: image),
      ),
    ),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 214,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF6EC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5D8C2)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              image,
              width: 76,
              height: 102,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  intro,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class CharacterListPage extends StatelessWidget {
  const CharacterListPage({super.key});
  static const characters = <(String, String, String)>[];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: const Text('全部角色', style: TextStyle(fontWeight: FontWeight.w900)),
    ),
    body: characters.isEmpty
        ? const Center(child: Text('暂无角色资料'))
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: characters.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final c = characters[index];
              return CharacterCard(name: c.$1, role: c.$2, image: c.$3);
            },
          ),
  );
}

class CharacterDetailPage extends StatelessWidget {
  final String name;
  final String role;
  final String image;
  const CharacterDetailPage({
    required this.name,
    required this.role,
    required this.image,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$name · 人物形象',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
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
                          child: Image.asset(
                            image,
                            height: 230,
                            width: double.infinity,
                            fit: BoxFit.cover,
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
                          child: Image.asset(
                            fullBodyImage,
                            height: 230,
                            width: double.infinity,
                            fit: BoxFit.cover,
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
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: const Text('角色详情', style: TextStyle(fontWeight: FontWeight.w900)),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CharacterCardPage(name: name, role: role, image: image),
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
                      child: Image.asset(
                        image,
                        width: 116,
                        height: 156,
                        fit: BoxFit.cover,
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('角色详情', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              Text(
                '暂无角色详情，请先补充角色资料。',
                style: TextStyle(
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('角色信息', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              _InfoLine('首次出现', '暂无'),
              _InfoLine('相关章节', '暂无'),
              _InfoLine('人物关系', '暂无'),
            ],
          ),
        ),
      ],
    ),
  );
}

class CharacterCardPage extends StatelessWidget {
  final String name;
  final String role;
  final String image;
  const CharacterCardPage({
    required this.name,
    required this.role,
    required this.image,
    super.key,
  });

  String get fullBodyImage => image;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: const Text('角色卡', style: TextStyle(fontWeight: FontWeight.w900)),
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
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            image,
            height: 280,
            width: double.infinity,
            fit: BoxFit.cover,
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
                const Text(
                  '出身书香门第，自幼聪慧善良。外表温婉柔和，内心坚韧执着，重情重义。历经风雨，始终坚守本心，以柔克刚，守护所爱之人。',
                  style: TextStyle(
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
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '人物关系',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: const [Text('暂无人物关系')]),
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
