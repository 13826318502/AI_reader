part of '../../main.dart';

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
          child: Image.asset(
            image,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
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
  static const names = <String>[];
  static const images = <String>[];

  void select(String name, String image) => setState(() {
    selected = name;
    selectedImage = image;
  });

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) {
      return const Scaffold(body: Center(child: Text('暂无人物关系数据')));
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0E1D2C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1D2C),
        foregroundColor: Colors.white,
        title: const Text(
          '世界百科 / 人物关系图',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
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
                        onTap: () => Navigator.pop(context),
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
                              role: '女主 · 合欢派圣女',
                              image: selectedImage,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 370,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _RelationLinesPainter()),
                      ),
                      _RelationNode(
                        name: names[0],
                        image: images[0],
                        left: 118,
                        top: 18,
                        selected: selected == names[0],
                        onTap: () => select(names[0], images[0]),
                      ),
                      _RelationNode(
                        name: names[1],
                        image: images[1],
                        left: 118,
                        top: 132,
                        selected: selected == names[1],
                        onTap: () => select(names[1], images[1]),
                      ),
                      _RelationNode(
                        name: names[2],
                        image: images[2],
                        left: 12,
                        top: 112,
                        selected: selected == names[2],
                        onTap: () => select(names[2], images[2]),
                      ),
                      _RelationNode(
                        name: names[3],
                        image: images[3],
                        left: 224,
                        top: 112,
                        selected: selected == names[3],
                        onTap: () => select(names[3], images[3]),
                      ),
                      _RelationNode(
                        name: names[4],
                        image: images[4],
                        left: 12,
                        top: 250,
                        selected: selected == names[4],
                        onTap: () => select(names[4], images[4]),
                      ),
                      _RelationNode(
                        name: names[5],
                        image: images[5],
                        left: 224,
                        top: 250,
                        selected: selected == names[5],
                        onTap: () => select(names[5], images[5]),
                      ),
                      _RelationNode(
                        name: names[6],
                        image: images[6],
                        left: 118,
                        top: 300,
                        selected: selected == names[6],
                        onTap: () => select(names[6], images[6]),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        selectedImage,
                        width: 74,
                        height: 86,
                        fit: BoxFit.cover,
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
                          const SizedBox(height: 4),
                          const Text(
                            '女主 · 合欢派圣女',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '暂无人物关系数据',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
  final double left;
  final double top;
  final bool selected;
  final VoidCallback onTap;
  const _RelationNode({
    required this.name,
    required this.image,
    required this.left,
    required this.top,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Positioned(
    left: left,
    top: top,
    width: 72,
    child: InkWell(
      onTap: onTap,
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
              child: Image.asset(
                image,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
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

class _RelationLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8A6B3C)
      ..strokeWidth = 1;
    final center = Offset(size.width / 2, 165);
    for (final point in [
      Offset(size.width / 2, 50),
      Offset(48, 145),
      Offset(size.width - 48, 145),
      Offset(48, 280),
      Offset(size.width - 48, 280),
      Offset(size.width / 2, 325),
    ]) {
      canvas.drawLine(center, point, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
