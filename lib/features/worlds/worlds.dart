part of '../../main.dart';

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
  final Map<String, String> worldSettings = {};

  @override
  void initState() {
    super.initState();
    selectedTitle = widget.initialTitle;
    _loadWorks();
    if (selectedTitle != null) _loadWorldSettings();
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
    for (final key in ['region', 'power', 'era']) {
      loaded[key] = p.getString('world_${title}_$key') ?? '';
    }
    if (mounted)
      setState(() {
        worldSettings
          ..clear()
          ..addAll(loaded);
      });
  }

  Future<void> _editWorldSetting(String key, String title) async {
    final controller = TextEditingController(text: worldSettings[key] ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑$title'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || selectedTitle == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setString('world_${selectedTitle}_$key', value);
    if (mounted) setState(() => worldSettings[key] = value);
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
    onTap: () => _editWorldSetting(key, title),
  );

  final characters = const <(String, String, String, String)>[];

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
                    });
                    _loadWorldSettings();
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
                            child: const Icon(Icons.menu_book_outlined),
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
                onPressed: () => setState(() => selectedTitle = null),
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('暂无角色资料')),
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
