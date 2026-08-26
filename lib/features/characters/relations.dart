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
  final String? workTitle;

  const RelationMapPage({
    required this.selectedName,
    required this.selectedImage,
    this.workTitle,
    super.key,
  });

  @override
  State<RelationMapPage> createState() => _RelationMapPageState();
}

class _RelationMapPageState extends State<RelationMapPage> {
  late String selected = widget.selectedName;
  late String selectedImage = widget.selectedImage;
  List<_CharacterRelation> relations = const [];
  List<_WorkCharacter> characters = const [];
  List<String> layoutOrder = const [];
  bool loading = true;
  bool arranging = false;

  @override
  void initState() {
    super.initState();
    _loadRelations();
    if (widget.workTitle != null) {
      CharacterStore.load(widget.workTitle!).then((loaded) {
        if (mounted) setState(() => characters = loaded);
      });
    }
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
      availableCharacters: characters,
    );
    if (added == null) return;
    final updated = [...relations, added];
    await CharacterRelationStore.save(selected, updated);
    if (added.toName.isNotEmpty) {
      final reverse = _CharacterRelation(
        id: '${added.id}-reverse',
        fromName: added.toName,
        fromImage: added.toImage,
        toName: added.fromName,
        toImage: added.fromImage,
        relation: added.relation,
      );
      final targetRelations = await CharacterRelationStore.load(added.toName);
      if (!targetRelations.any(
        (item) =>
            item.fromName == reverse.fromName &&
            item.toName == reverse.toName &&
            item.relation == reverse.relation,
      )) {
        await CharacterRelationStore.save(added.toName, [
          ...targetRelations,
          reverse,
        ]);
      }
    }
    if (!mounted) return;
    setState(() => relations = updated);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('角色关系已添加')));
  }

  Future<void> _manageRelations() async {
    final relation = await showModalBottomSheet<_CharacterRelation>(
      context: context,
      backgroundColor: const Color(0xFF17263A),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '管理人物关系',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (selectedRelations.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    '当前人物还没有关系记录',
                    style: TextStyle(color: Colors.white60),
                  ),
                )
              else
                ...selectedRelations.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item.fromName == selected ? item.toName : item.fromName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      item.relation,
                      style: const TextStyle(color: Color(0xFFE6C77B)),
                    ),
                    trailing: IconButton(
                      tooltip: '删除关系',
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => Navigator.pop(context, item),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (relation == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条人物关系？'),
        content: Text('将删除“${relation.relation}”关系及其反向记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final remaining = relations
        .where((item) => item.id != relation.id)
        .toList();
    await CharacterRelationStore.save(selected, remaining);
    final otherName = relation.fromName == selected
        ? relation.toName
        : relation.fromName;
    final otherRelations = await CharacterRelationStore.load(otherName);
    await CharacterRelationStore.save(
      otherName,
      otherRelations
          .where(
            (item) =>
                !(item.fromName == relation.toName &&
                    item.toName == relation.fromName &&
                    item.relation == relation.relation),
          )
          .toList(),
    );
    if (!mounted) return;
    setState(() => relations = remaining);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('人物关系已删除')));
  }

  Future<void> _arrangeWithAi() async {
    if (arranging) return;
    final names = <String>{widget.selectedName};
    for (final relation in selectedRelations) {
      names
        ..add(relation.fromName)
        ..add(relation.toName);
    }
    if (names.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('至少添加两个角色和一条关系后才能整理布局')));
      return;
    }
    setState(() => arranging = true);
    try {
      final suggested = await CharacterRelationLayoutService.suggestOrder(
        protagonist: selected,
        names: names.toList(),
        relations: selectedRelations,
      );
      if (!mounted) return;
      final usedRemote = CharacterRelationLayoutService.lastUsedRemote;
      setState(() {
        layoutOrder =
            suggested ?? [selected, ...names.where((name) => name != selected)];
        arranging = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(usedRemote ? 'AI 已整理关系图布局' : '普通模型不可用，已使用本地智能布局'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => arranging = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AI 布局暂时不可用，已保留当前布局')));
    }
  }

  void select(String name, String image) => setState(() {
    selected = name;
    selectedImage = image;
  });

  List<_RelationNodeData> get nodes {
    final result = <_RelationNodeData>[
      _RelationNodeData(name: selected, image: selectedImage),
    ];
    for (final relation in selectedRelations) {
      if (!result.any((item) => item.name == relation.fromName)) {
        result.add(
          _RelationNodeData(name: relation.fromName, image: relation.fromImage),
        );
      }
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

  _WorkCharacter? get selectedCharacter {
    for (final character in characters) {
      if (character.name == selected) return character;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0B1020),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0B1020),
      foregroundColor: Colors.white,
      title: Text(
        '${selected}-角色关系',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.ios_share)),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'world') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Worlds()),
              );
            } else if (value == 'card') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CharacterCardPage(
                    name: selected,
                    role: '角色',
                    image: selectedImage,
                  ),
                ),
              );
            } else if (value == 'add' && !loading) {
              _addRelation();
            } else if (value == 'manage' && !loading) {
              _manageRelations();
            } else if (value == 'ai' && !loading && !arranging) {
              _arrangeWithAi();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'world', child: Text('世界百科')),
            PopupMenuItem(value: 'card', child: Text('角色卡')),
            PopupMenuItem(value: 'add', child: Text('添加人物关系')),
            PopupMenuItem(value: 'manage', child: Text('删除人物关系')),
            PopupMenuItem(value: 'ai', child: Text('AI 自动排布')),
          ],
        ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: gold))
        : LayoutBuilder(
            builder: (context, constraints) {
              final infoHeight = math.min(190.0, constraints.maxHeight * .25);
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _RelationBackdropPainter()),
                  ),
                  Positioned.fill(
                    bottom: infoHeight,
                    child: ClipRect(
                      child: InteractiveViewer(
                        constrained: false,
                        minScale: .7,
                        maxScale: 2.2,
                        boundaryMargin: const EdgeInsets.all(120),
                        child: _RelationGraph(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight - infoHeight,
                          nodes: nodes,
                          relations: selectedRelations,
                          protagonist: selected,
                          selected: selected,
                          order: layoutOrder,
                          onSelect: select,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: infoHeight,
                    child: _RelationInfoPanel(
                      name: selected,
                      image: selectedImage,
                      relations: selectedRelations,
                      character: selectedCharacter,
                      onGenerate: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CharacterAiPage(
                            name: selected,
                            image: selectedImage,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
  );
}

class _RelationBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .58);
    final maxRadius = math.max(size.width, size.height) * .72;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFF1F315C), Color(0xFF0B1020)],
          stops: const [.05, .95],
        ).createShader(Rect.fromCircle(center: center, radius: maxRadius)),
    );
    final globe = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFF314D7B), Color(0x001A2B55)],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * .42));
    canvas.drawCircle(center, size.width * .34, globe);
    final rings = Paint()
      ..color = const Color(0x243A4E80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final factor in [.55, .73, .9]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: size.width * factor,
          height: size.width * factor * .58,
        ),
        rings,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RelationGraph extends StatelessWidget {
  final double width;
  final double height;
  final List<_RelationNodeData> nodes;
  final List<_CharacterRelation> relations;
  final String protagonist;
  final String selected;
  final List<String> order;
  final void Function(String name, String image) onSelect;

  const _RelationGraph({
    required this.width,
    required this.height,
    required this.nodes,
    required this.relations,
    required this.protagonist,
    required this.selected,
    required this.order,
    required this.onSelect,
  });

  List<_RelationNodeData> get orderedNodes {
    final byName = {for (final node in nodes) node.name: node};
    final names = order.isEmpty
        ? nodes.map((node) => node.name).toList()
        : order;
    final arranged = [
      protagonist,
      ...names.where((name) => name != protagonist),
    ];
    return [
      for (final name in arranged)
        if (byName[name] != null) byName[name]!,
    ];
  }

  @override
  Widget build(BuildContext context) => Container(
    width: math.max(width, _canvasExtent),
    height: math.max(height, _canvasExtent),
    color: Colors.transparent,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final list = orderedNodes;
        final center = Offset(
          constraints.maxWidth / 2,
          constraints.maxHeight / 2,
        );
        final positions = _buildPositions(list, center, constraints.biggest);
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RelationLinesPainter(
                  positions: positions,
                  relations: relations,
                  protagonist: protagonist,
                ),
              ),
            ),
            for (final node in list)
              Positioned(
                left:
                    positions[node.name]!.dx -
                    (node.name == protagonist ? 66 : 38),
                top:
                    positions[node.name]!.dy -
                    (node.name == protagonist ? 66 : 38),
                child: _RelationNode(
                  name: node.name,
                  image: node.image,
                  selected: selected == node.name,
                  onTap: () => onSelect(node.name, node.image),
                  protagonist: node.name == protagonist,
                ),
              ),
          ],
        );
      },
    ),
  );

  int get _ringCount {
    final outside = math.max(1, orderedNodes.length - 1);
    return (outside / 6).ceil();
  }

  double get _canvasExtent {
    final rings = _ringCount;
    final outerRadius = 175.0 + (rings - 1) * 125.0;
    return math.max(math.max(width, height), outerRadius * 2 + 190);
  }

  Map<String, Offset> _buildPositions(
    List<_RelationNodeData> list,
    Offset center,
    Size canvas,
  ) {
    final positions = <String, Offset>{};
    if (list.isEmpty) return positions;
    positions[list.first.name] = center;
    final outside = list.skip(1).toList();
    final ringCount = math.max(1, (outside.length / 6).ceil());
    var cursor = 0;
    for (var ring = 0; ring < ringCount; ring++) {
      final remaining = outside.length - cursor;
      final ringSize = math.min(6, remaining);
      final radius = 175.0 + ring * 125.0;
      final phase = ring.isEven
          ? -math.pi / 2
          : -math.pi / 2 + math.pi / ringSize;
      for (var slot = 0; slot < ringSize; slot++) {
        final angle = phase + slot * math.pi * 2 / ringSize;
        final node = outside[cursor++];
        positions[node.name] =
            center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      }
    }
    return positions;
  }
}

class _RelationLinesPainter extends CustomPainter {
  final Map<String, Offset> positions;
  final List<_CharacterRelation> relations;
  final String protagonist;

  const _RelationLinesPainter({
    required this.positions,
    required this.relations,
    required this.protagonist,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFE6C77B)
      ..strokeWidth = 2.1
      ..style = PaintingStyle.stroke;
    final groups = <String, List<_CharacterRelation>>{};
    for (final relation in relations) {
      final otherName = relation.fromName == protagonist
          ? relation.toName
          : relation.fromName;
      if (!positions.containsKey(protagonist) ||
          !positions.containsKey(otherName) ||
          otherName == protagonist) {
        continue;
      }
      final names = [protagonist, otherName]..sort();
      groups.putIfAbsent(names.join('|'), () => []).add(relation);
    }
    for (final group in groups.values) {
      for (var index = 0; index < group.length; index++) {
        final relation = group[index];
        final otherName = relation.fromName == protagonist
            ? relation.toName
            : relation.fromName;
        final from = positions[protagonist]!;
        final to = positions[otherName]!;
        final distance = (to - from).distance;
        if (distance < 1) continue;
        final direction = (to - from) / distance;
        final perpendicular = Offset(-direction.dy, direction.dx);
        final parallelOffset = (index - (group.length - 1) / 2) * 30.0;
        final lineStart =
            from + direction * 44 + perpendicular * parallelOffset;
        final arrowTip = to - direction * 44 + perpendicular * parallelOffset;
        canvas.drawLine(lineStart, arrowTip, line);
        final arrow = Path()
          ..moveTo(arrowTip.dx, arrowTip.dy)
          ..lineTo(
            arrowTip.dx - direction.dx * 8 + perpendicular.dx * 4,
            arrowTip.dy - direction.dy * 8 + perpendicular.dy * 4,
          )
          ..moveTo(arrowTip.dx, arrowTip.dy)
          ..lineTo(
            arrowTip.dx - direction.dx * 8 - perpendicular.dx * 4,
            arrowTip.dy - direction.dy * 8 - perpendicular.dy * 4,
          );
        canvas.drawPath(arrow, line);
        final midpoint = Offset(
          (lineStart.dx + arrowTip.dx) / 2,
          (lineStart.dy + arrowTip.dy) / 2,
        );
        final painter = TextPainter(
          text: TextSpan(
            text: relation.relation,
            style: const TextStyle(
              color: Color(0xFFFFE2A0),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 72);
        final labelRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: midpoint,
            width: painter.width + 8,
            height: painter.height + 4,
          ),
          const Radius.circular(4),
        );
        canvas.drawRRect(labelRect, Paint()..color = const Color(0xFF102437));
        painter.paint(
          canvas,
          midpoint - Offset(painter.width / 2, painter.height / 2),
        );
        painter.dispose();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RelationLinesPainter oldDelegate) =>
      oldDelegate.positions != positions || oldDelegate.relations != relations;
}

class _RelationInfoPanel extends StatelessWidget {
  final String name;
  final String image;
  final List<_CharacterRelation> relations;
  final _WorkCharacter? character;
  final VoidCallback onGenerate;
  const _RelationInfoPanel({
    required this.name,
    required this.image,
    required this.relations,
    required this.character,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
    decoration: const BoxDecoration(
      color: Color(0xE9161A2B),
      border: Border(top: BorderSide(color: Color(0x263F4C69))),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('◇', style: TextStyle(color: Colors.white38)),
            const SizedBox(width: 12),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFF2D58D),
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 12),
            const Text('◇', style: TextStyle(color: Colors.white38)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${character?.role ?? '角色'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        const SizedBox(height: 7),
        Text(
          character?.intro.isNotEmpty == true
              ? character!.intro
              : (relations.isEmpty ? '暂无人物介绍' : relations.first.relation),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
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
  final bool protagonist;
  const _RelationNode({
    required this.name,
    required this.image,
    required this.selected,
    required this.onTap,
    this.protagonist = false,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(40),
    child: SizedBox(
      width: protagonist ? 132 : 76,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: protagonist || selected ? gold : const Color(0xFF8A6B3C),
                width: protagonist || selected ? 2 : 1.2,
              ),
            ),
            child: ClipOval(
              child: SizedBox(
                width: protagonist ? 116 : 62,
                height: protagonist ? 116 : 62,
                child: AiImagePreview(image: image, fit: BoxFit.cover),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -28),
            child: Container(
              width: protagonist ? 118 : 64,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: const Color(0xB51A1E2D),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white,
                  fontSize: protagonist ? 20 : 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
