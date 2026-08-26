part of '../../main.dart';

class _CharacterImageTile extends StatelessWidget {
  final String title;
  final String image;
  const _CharacterImageTile({required this.title, required this.image});

  @override
  Widget build(BuildContext context) => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AiImagePreview(image: image, fit: BoxFit.cover),
        ),
      ],
    ),
  );
}

class _RelationChip extends StatelessWidget {
  final String label;
  final String relation;
  const _RelationChip({required this.label, required this.relation});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8EA),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE9D3A7)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
        Text(relation, style: const TextStyle(color: gold, fontSize: 10)),
      ],
    ),
  );
}

class RelationMapPage extends StatefulWidget {
  final String selectedName;
  final String selectedImage;

  const RelationMapPage({
    required this.selectedName,
    required this.selectedImage,
    super.key,
  });

  @override
  State<RelationMapPage> createState() => _RelationMapPageState();
}

class _RelationMapPageState extends State<RelationMapPage> {
  late String selected = widget.selectedName;
  late String selectedImage = widget.selectedImage;
  List<_CharacterRelation> relations = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadRelations();
  }

  Future<void> _loadRelations() async {
    final loaded = await CharacterRelationStore.load(widget.selectedName);
    if (!mounted) return;
    setState(() {
      relations = loaded;
      loading = false;
    });
  }

  Future<void> _addRelation() async {
    final added = await showAddRelationDialog(
      context: context,
      fromName: selected,
      fromImage: selectedImage,
    );
    if (added == null) return;
    final updated = [...relations, added];
    await CharacterRelationStore.save(widget.selectedName, updated);
    if (!mounted) return;
    setState(() => relations = updated);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('角色关系已添加')));
  }

  void select(String name, String image) => setState(() {
    selected = name;
    selectedImage = image;
  });

  List<_RelationNodeData> get nodes {
    final result = <_RelationNodeData>[
      _RelationNodeData(name: widget.selectedName, image: widget.selectedImage),
    ];
    for (final relation in relations) {
      if (!result.any((item) => item.name == relation.toName)) {
        result.add(
          _RelationNodeData(name: relation.toName, image: relation.toImage),
        );
      }
    }
    return result;
  }

  List<_CharacterRelation> get selectedRelations => relations
      .where((item) => item.fromName == selected || item.toName == selected)
      .toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0E1D2C),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0E1D2C),
      foregroundColor: Colors.white,
      title: const Text(
        '人物关系图',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          onPressed: loading ? null : _addRelation,
          tooltip: '添加关系',
          icon: const Icon(Icons.add_link),
        ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: gold))
        : ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF142A3D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2C455A)),
                ),
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _RelationTab(
                            label: '世界百科',
                            selected: false,
                            onTap: () => Navigator.pop(context),
                          ),
                        ),
                        Expanded(
                          child: _RelationTab(
                            label: '人物关系',
                            selected: true,
                            onTap: () {},
                          ),
                        ),
                        Expanded(
                          child: _RelationTab(
                            label: '角色卡',
                            selected: false,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CharacterCardPage(
                                  name: selected,
                                  role: '角色',
                                  image: selectedImage,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      constraints: const BoxConstraints(minHeight: 270),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF102437),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        runAlignment: WrapAlignment.center,
                        spacing: 28,
                        runSpacing: 24,
                        children: [
                          for (final node in nodes)
                            _RelationNode(
                              name: node.name,
                              image: node.image,
                              selected: selected == node.name,
                              onTap: () => select(node.name, node.image),
                            ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 74,
                            height: 86,
                            child: AiImagePreview(
                              image: selectedImage,
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
                                selected,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (selectedRelations.isEmpty)
                                const Text(
                                  '当前只有这个角色，点击右上角“添加关系”即可录入其他角色。',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: selectedRelations.map((item) {
                                    final other = item.fromName == selected
                                        ? item.toName
                                        : item.fromName;
                                    return _RelationChip(
                                      label: other,
                                      relation: item.relation,
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addRelation,
                        icon: const Icon(Icons.add_link),
                        label: const Text('手动添加角色关系'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: gold,
                          side: const BorderSide(color: gold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
  );
}

class _RelationNodeData {
  final String name;
  final String image;
  const _RelationNodeData({required this.name, required this.image});
}

class _RelationTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RelationTab({
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
        border: Border(
          bottom: BorderSide(
            color: selected ? gold : Colors.white12,
            width: selected ? 2 : 1,
          ),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
            fontSize: 12,
          ),
        ),
      ),
    ),
  );
}

class _RelationNode extends StatelessWidget {
  final String name;
  final String image;
  final bool selected;
  final VoidCallback onTap;
  const _RelationNode({
    required this.name,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(40),
    child: SizedBox(
      width: 82,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? gold : const Color(0xFF8A6B3C),
                width: selected ? 2 : 1,
              ),
            ),
            child: ClipOval(
              child: SizedBox(
                width: 56,
                height: 56,
                child: AiImagePreview(image: image, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? gold : Colors.white,
              fontSize: 10,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
        ],
      ),
    ),
  );
}
