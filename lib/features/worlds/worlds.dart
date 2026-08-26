part of '../../main.dart';

class _WorldDetailItem {
  final String title;
  final String content;

  const _WorldDetailItem({required this.title, required this.content});

  Map<String, String> toJson() => {'title': title, 'content': content};

  factory _WorldDetailItem.fromJson(Map<String, dynamic> json) =>
      _WorldDetailItem(
        title: json['title']?.toString() ?? '未命名设定',
        content: json['content']?.toString() ?? '',
      );
}

class Worlds extends StatefulWidget {
  final String? initialTitle;
  const Worlds({this.initialTitle, super.key});
  @override
  State<Worlds> createState() => _WorldsState();
}

class _WorldsState extends State<Worlds> {
  int tab = 0;
  String? selectedTitle;
  List<_ImportedWork> works = [];
  List<_WorkCharacter> characters = [];
  final Map<String, String> worldSettings = {};
  final Map<String, List<_WorldDetailItem>> worldDetails = {};

  @override
  void initState() {
    super.initState();
    selectedTitle = widget.initialTitle;
    _loadWorks();
    if (selectedTitle != null) {
      _loadWorldSettings();
      _loadCharacters();
    }
  }

  Future<void> _loadWorks() async {
    final loaded = await ImportedWorkStore.loadAll();
    if (mounted) setState(() => works = loaded);
  }

  Future<void> _loadWorldSettings() async {
    final title = selectedTitle;
    if (title == null) return;
    final p = await SharedPreferences.getInstance();
    final loaded = <String, String>{};
    final details = <String, List<_WorldDetailItem>>{};
    for (final key in ['region', 'power', 'era']) {
      final summary = p.getString('world_${title}_$key') ?? '';
      loaded[key] = summary;
      final rawItems = p.getString('world_${title}_${key}_items');
      dynamic decoded;
      try {
        decoded = rawItems == null ? null : jsonDecode(rawItems);
      } catch (_) {
        decoded = null;
      }
      final items = decoded is List
          ? decoded
                .whereType<Map>()
                .map(
                  (item) => _WorldDetailItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((item) => item.content.isNotEmpty)
                .toList()
          : <_WorldDetailItem>[];
      details[key] = items.isEmpty && summary.isNotEmpty
          ? [_WorldDetailItem(title: '概述', content: summary)]
          : items;
    }
    if (mounted)
      setState(() {
        worldSettings
          ..clear()
          ..addAll(loaded);
        worldDetails
          ..clear()
          ..addAll(details);
      });
  }

  Future<void> _loadCharacters() async {
    final title = selectedTitle;
    if (title == null) return;
    final loaded = await CharacterStore.load(title);
    if (mounted && title == selectedTitle) setState(() => characters = loaded);
  }

  Future<void> _openWorldCategory(String key, String title) async {
    final result = await Navigator.push<List<_WorldDetailItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => _WorldCategoryPage(
          bookTitle: selectedTitle!,
          title: title,
          initialItems: worldDetails[key] ?? const [],
        ),
      ),
    );
    if (!mounted || result == null || selectedTitle == null) return;
    final p = await SharedPreferences.getInstance();
    final bookTitle = selectedTitle!;
    final summary = result.isEmpty ? '' : result.first.content;
    await p.setString('world_${bookTitle}_$key', summary);
    await p.setString(
      'world_${bookTitle}_${key}_items',
      jsonEncode(result.map((item) => item.toJson()).toList()),
    );
    setState(() {
      worldSettings[key] = summary;
      worldDetails[key] = result;
    });
  }

  Widget _worldSettingRow(IconData icon, String key, String title) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: gold),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(
      worldSettings[key]?.isNotEmpty == true ? worldSettings[key]! : '点击添加',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11),
    ),
    trailing: const Icon(Icons.edit_outlined, color: Colors.black38),
    onTap: () => _openWorldCategory(key, title),
  );

  @override
  Widget build(BuildContext context) {
    if (selectedTitle == null) {
      return Material(
        color: background,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            const Text(
              'WORLD BIBLE',
              style: TextStyle(
                color: gold,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const Text(
              '设定集',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              '选择作品后进入对应的世界资料库',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 18),
            ...works.map(
              (work) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      selectedTitle = work.title;
                      tab = 0;
                      characters = [];
                    });
                    _loadWorldSettings();
                    _loadCharacters();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: card(
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 70,
                            height: 84,
                            color: const Color(0xFFE8DED0),
                            child: work.cover.isEmpty
                                ? const Icon(Icons.menu_book_outlined)
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
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                '本地导入 · ${work.chapters.length} 章',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '进入设定集',
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
          ],
        ),
      );
    }

    return Material(
      color: background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          const Text(
            'WORLD BIBLE',
            style: TextStyle(
              color: gold,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const Text(
            '设定集',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$selectedTitle · 故事资料库',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  selectedTitle = null;
                  characters = [];
                }),
                child: const Text(
                  '更换作品',
                  style: TextStyle(color: gold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _WorldTab(
                  label: '世界观',
                  selected: tab == 0,
                  onTap: () => setState(() => tab = 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WorldTab(
                  label: '角色',
                  selected: tab == 1,
                  onTap: () => setState(() => tab = 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (tab == 0) ...[
            card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '世界观',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '当前作品尚未填写世界观资料。',
                    style: TextStyle(color: Colors.black54, height: 1.6),
                  ),
                  SizedBox(height: 18),
                  _worldSettingRow(Icons.map_outlined, 'region', '地域设定'),
                  _worldSettingRow(
                    Icons.auto_awesome_outlined,
                    'power',
                    '力量体系',
                  ),
                  _worldSettingRow(Icons.history_edu_outlined, 'era', '时代背景'),
                ],
              ),
            ),
          ] else ...[
            card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '角色档案',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CharacterListPage(workTitle: selectedTitle),
                          ),
                        ),
                        icon: const Icon(Icons.style_outlined, size: 16),
                        label: const Text('角色卡片'),
                        style: TextButton.styleFrom(foregroundColor: gold),
                      ),
                    ],
                  ),
                  if (characters.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('暂无角色资料，请在作品详情中新增角色')),
                    )
                  else
                    ...characters.map(
                      (character) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CharacterCard(
                          name: character.name,
                          role: character.role,
                          intro: character.intro,
                          image: character.image,
                          workTitle: selectedTitle,
                          characterId: character.id,
                          appearance: character.appearance,
                          personality: character.personality,
                          background: character.background,
                          goal: character.goal,
                          firstAppearance: character.firstAppearance,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorldTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _WorldTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF16283A) : surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF16283A) : const Color(0xFFE5D8C2),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

class _WorldCategoryPage extends StatefulWidget {
  final String bookTitle;
  final String title;
  final List<_WorldDetailItem> initialItems;

  const _WorldCategoryPage({
    required this.bookTitle,
    required this.title,
    required this.initialItems,
  });

  @override
  State<_WorldCategoryPage> createState() => _WorldCategoryPageState();
}

class _WorldCategoryPageState extends State<_WorldCategoryPage> {
  late final List<_WorldDetailItem> items = [...widget.initialItems];
  final titleController = TextEditingController();
  final contentController = TextEditingController();

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  void _addItem() {
    final itemTitle = titleController.text.trim();
    final content = contentController.text.trim();
    if (itemTitle.isEmpty || content.isEmpty) return;
    setState(() {
      items.add(_WorldDetailItem(title: itemTitle, content: content));
      titleController.clear();
      contentController.clear();
    });
  }

  Future<void> _editItem(int index) async {
    final editTitleController = TextEditingController(text: items[index].title);
    final editContentController = TextEditingController(
      text: items[index].content,
    );
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('编辑${widget.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editTitleController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '设定标题'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: editContentController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '设定内容',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              jsonEncode({
                'title': editTitleController.text,
                'content': editContentController.text,
              }),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    // showDialog returns before its closing transition fully detaches the
    // TextFields. Dispose after the transition so AnimatedTextField listeners
    // cannot touch an already-disposed controller.
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      editTitleController.dispose();
      editContentController.dispose();
    });
    if (!mounted || value == null) return;
    final decoded = jsonDecode(value);
    if (decoded is! Map) return;
    final edited = _WorldDetailItem.fromJson(
      Map<String, dynamic>.from(decoded),
    );
    if (edited.title.trim().isEmpty || edited.content.trim().isEmpty) return;
    setState(() => items[index] = edited);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: Text(widget.title),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, items),
          child: const Text('完成', style: TextStyle(color: gold)),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
      children: [
        Text(
          widget.bookTitle,
          style: const TextStyle(color: gold, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '在这里拆分维护多条${widget.title}，保存后会回到当前作品的设定集。',
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          card(
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('还没有细化设定，请在下方添加')),
            ),
          )
        else
          ...items.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: card(
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE7D7C0),
                    foregroundColor: gold,
                    child: Text('${entry.key + 1}'),
                  ),
                  title: Text(
                    entry.value.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    entry.value.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(height: 1.45),
                  ),
                  trailing: const Icon(
                    Icons.edit_outlined,
                    color: Colors.black38,
                  ),
                  onTap: () => _editItem(entry.key),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: '设定标题',
            hintText: '例如：皇城地理',
            filled: true,
            fillColor: surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5D8C2)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: contentController,
          minLines: 3,
          maxLines: 6,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: '设定内容',
            hintText: '输入一条新的${widget.title}内容……',
            filled: true,
            fillColor: surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5D8C2)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _addItem,
          icon: const Icon(Icons.add),
          label: Text('添加${widget.title}'),
          style: FilledButton.styleFrom(backgroundColor: gold),
        ),
      ],
    ),
  );
}

class _WorldEmptyRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _WorldEmptyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: gold),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
    trailing: const Icon(Icons.chevron_right, color: Colors.black38),
  );
}

class _WorldCharacterRow extends StatelessWidget {
  final String name;
  final String role;
  final String intro;
  final String image;
  const _WorldCharacterRow({
    required this.name,
    required this.role,
    required this.intro,
    required this.image,
  });
  @override
  Widget build(BuildContext context) => card(
    Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(image, width: 78, height: 96, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                role,
                style: const TextStyle(
                  color: gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                intro,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CharacterCardPage(name: name, role: role, image: image),
            ),
          ),
          child: const Text('角色卡', style: TextStyle(color: gold, fontSize: 11)),
        ),
      ],
    ),
  );
}
