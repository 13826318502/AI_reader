part of '../../main.dart';

class ReadingPreferencesPage extends StatefulWidget {
  const ReadingPreferencesPage({super.key});
  @override
  State<ReadingPreferencesPage> createState() => _ReadingPreferencesPageState();
}

class _ReadingPreferencesPageState extends State<ReadingPreferencesPage> {
  double fontSize = 18;
  bool immersive = true;
  bool pageTurn = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await ReadingPreferencesStore.load();
    if (!mounted) return;
    setState(() {
      fontSize = ReadingPreferencesStore.fontSize;
      immersive = ReadingPreferencesStore.immersive;
      pageTurn = ReadingPreferencesStore.pageTurn;
    });
  }

  Future<void> _save() async {
    ReadingPreferencesStore.fontSize = fontSize;
    ReadingPreferencesStore.immersive = immersive;
    ReadingPreferencesStore.pageTurn = pageTurn;
    await ReadingPreferencesStore.save();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: const Text('阅读偏好', style: TextStyle(fontWeight: FontWeight.w900)),
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '正文样式',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('字体大小'),
                  Text(
                    '${fontSize.toInt()} px',
                    style: const TextStyle(color: gold),
                  ),
                ],
              ),
              Slider(
                value: fontSize,
                min: 14,
                max: 24,
                divisions: 5,
                activeColor: gold,
                onChanged: (v) {
                  setState(() => fontSize = v);
                  _save();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('沉浸式阅读'),
                subtitle: const Text(
                  '聚焦正文时隐藏控制栏',
                  style: TextStyle(fontSize: 11),
                ),
                value: immersive,
                activeColor: gold,
                onChanged: (v) {
                  setState(() => immersive = v);
                  _save();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('翻页动效'),
                value: pageTurn,
                activeColor: gold,
                onChanged: (v) {
                  setState(() => pageTurn = v);
                  _save();
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
