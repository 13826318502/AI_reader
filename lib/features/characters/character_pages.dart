part of '../../main.dart';

class CharacterListPage extends StatefulWidget {
  final String? workTitle;
  const CharacterListPage({this.workTitle, super.key});

  @override
  State<CharacterListPage> createState() => _CharacterListPageState();
}

class _CharacterListPageState extends State<CharacterListPage> {
  List<_WorkCharacter> characters = const [];

  @override
  void initState() {
    super.initState();
    if (widget.workTitle != null) {
      CharacterStore.load(widget.workTitle!).then((items) {
        if (mounted) setState(() => characters = items);
      });
    }
  }

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
              return CharacterCard(
                name: c.name,
                role: c.role,
                intro: c.intro,
                image: c.image,
                workTitle: widget.workTitle,
                characterId: c.id,
                appearance: c.appearance,
                personality: c.personality,
                background: c.background,
                goal: c.goal,
                firstAppearance: c.firstAppearance,
              );
            },
          ),
  );
}
