part of '../../main.dart';

class _BookCharactersSection extends StatelessWidget {
  final String title;
  final List<_WorkCharacter> characters;
  final VoidCallback onAdd;
  const _BookCharactersSection({
    required this.title,
    required this.characters,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '角色 · ${characters.length}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CharacterListPage(workTitle: title),
                ),
              ),
              child: const Text(
                '全部角色',
                style: TextStyle(color: gold, fontSize: 12),
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('新增角色', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: gold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (characters.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('暂无角色资料，点击“新增角色”添加')),
          )
        else
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: characters.take(4).length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final character = characters[index];
                return SizedBox(
                  width: 270,
                  child: CharacterCard(
                    name: character.name,
                    role: character.role,
                    intro: character.intro,
                    image: character.image,
                    workTitle: title,
                    characterId: character.id,
                    appearance: character.appearance,
                    personality: character.personality,
                    background: character.background,
                    goal: character.goal,
                    firstAppearance: character.firstAppearance,
                  ),
                );
              },
            ),
          ),
        if (characters.length > 4)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '另有 ${characters.length - 4} 位角色，可在“全部角色”中查看',
              style: TextStyle(color: mutedText, fontSize: 12),
            ),
          ),
      ],
    ),
  );
}
