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
  bool eyeCare = false;
  String theme = 'paper';
  String pageMode = 'curl';
  double lineHeight = 2.05;
  double horizontalPadding = 22;

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
      eyeCare = ReadingPreferencesStore.eyeCare;
      theme = ReadingPreferencesStore.theme;
      pageMode = ReadingPreferencesStore.pageMode;
      lineHeight = ReadingPreferencesStore.lineHeight;
      horizontalPadding = ReadingPreferencesStore.horizontalPadding;
    });
  }

  Future<void> _save() async {
    ReadingPreferencesStore.fontSize = fontSize;
    ReadingPreferencesStore.immersive = immersive;
    ReadingPreferencesStore.pageTurn = pageTurn;
    ReadingPreferencesStore.eyeCare = eyeCare;
    ReadingPreferencesStore.theme = theme;
    ReadingPreferencesStore.pageMode = pageMode;
    ReadingPreferencesStore.lineHeight = lineHeight;
    ReadingPreferencesStore.horizontalPadding = horizontalPadding;
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
                title: const Text('护眼模式'),
                subtitle: const Text(
                  '降低冷色对比，适合长时间阅读',
                  style: TextStyle(fontSize: 11),
                ),
                value: eyeCare,
                activeColor: gold,
                onChanged: (v) {
                  setState(() => eyeCare = v);
                  _save();
                },
              ),
              const SizedBox(height: 8),
              const Text(
                '主题样式',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: theme,
                decoration: const InputDecoration(
                  labelText: '阅读底色',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'paper', child: Text('暖白纸张')),
                  DropdownMenuItem(value: 'green', child: Text('豆沙绿')),
                  DropdownMenuItem(value: 'dark', child: Text('夜间深色')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => theme = v);
                  _save();
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: pageMode,
                decoration: const InputDecoration(
                  labelText: '翻页模式',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'curl', child: Text('拟真书页')),
                  DropdownMenuItem(value: 'slide', child: Text('平移翻页')),
                  DropdownMenuItem(value: 'none', child: Text('无动画')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => pageMode = v);
                  pageTurn = v != 'none';
                  _save();
                },
              ),
              const SizedBox(height: 14),
              Text(
                '行距 ${lineHeight.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 13),
              ),
              Slider(
                value: lineHeight,
                min: 1.5,
                max: 2.6,
                divisions: 11,
                activeColor: gold,
                onChanged: (v) {
                  setState(() => lineHeight = v);
                  _save();
                },
              ),
              Text(
                '左右边距 ${horizontalPadding.toInt()}',
                style: const TextStyle(fontSize: 13),
              ),
              Slider(
                value: horizontalPadding,
                min: 14,
                max: 40,
                divisions: 13,
                activeColor: gold,
                onChanged: (v) {
                  setState(() => horizontalPadding = v);
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
