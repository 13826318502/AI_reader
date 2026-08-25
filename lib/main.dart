import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<bool> appDarkMode = ValueNotifier<bool>(false);
Color get background =>
    appDarkMode.value ? const Color(0xFF101820) : const Color(0xFFF7F1E6);
Color get surface =>
    appDarkMode.value ? const Color(0xFF1B2935) : const Color(0xFFFFFBF3);
Color get mutedText => appDarkMode.value ? Colors.white70 : Colors.black54;
Color get primaryText => appDarkMode.value ? Colors.white : Colors.black87;
const gold = Color(0xFFD99222);

class AiImageStorage {
  static const _folderName = 'AI生成图片';

  static Future<Directory> directory() async {
    final base =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final folder = Directory('${base.path}/$_folderName');
    if (!await folder.exists()) await folder.create(recursive: true);
    return folder;
  }

  static Future<String?> save(
    String image, {
    String prefix = 'ai_image',
  }) async {
    try {
      final bytes = image.startsWith('data:image/')
          ? base64Decode(image.substring(image.indexOf(',') + 1))
          : (await http.get(Uri.parse(image))).bodyBytes;
      final folder = await directory();
      final stamp = DateTime.now().toIso8601String().replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      final file = File('${folder.path}/${prefix}_$stamp.png');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static Future<int> sizeBytes() async {
    final folder = await directory();
    var total = 0;
    await for (final entity in folder.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  static Future<void> clear() async {
    final folder = await directory();
    await for (final entity in folder.list(
      recursive: false,
      followLinks: false,
    )) {
      await entity.delete(recursive: true);
    }
  }

  static Future<Directory> openDirectory() async {
    final folder = await directory();
    try {
      await const MethodChannel(
        'arc_reader/file_manager',
      ).invokeMethod<void>('openFolder', {'path': folder.path});
    } catch (_) {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [folder.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [folder.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [folder.path]);
      }
    }
    return folder;
  }
}

class ApiRequestLog {
  final DateTime timestamp;
  final String provider;
  final String model;
  final String url;
  final int? statusCode;
  final int durationMs;
  final bool success;
  final String? error;

  const ApiRequestLog({
    required this.timestamp,
    required this.provider,
    required this.model,
    required this.url,
    required this.statusCode,
    required this.durationMs,
    required this.success,
    required this.error,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'provider': provider,
    'model': model,
    'url': url,
    'status_code': statusCode,
    'duration_ms': durationMs,
    'success': success,
    'error': error,
  };

  factory ApiRequestLog.fromJson(Map<String, dynamic> json) => ApiRequestLog(
    timestamp:
        DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
        DateTime.now(),
    provider: json['provider']?.toString() ?? '',
    model: json['model']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
    statusCode: json['status_code'] is num
        ? (json['status_code'] as num).toInt()
        : null,
    durationMs: json['duration_ms'] is num
        ? (json['duration_ms'] as num).toInt()
        : 0,
    success: json['success'] == true,
    error: json['error']?.toString(),
  );
}

class ApiRequestLogStore {
  static const key = 'ai_api_request_logs';
  static const maxEntries = 100;

  static Future<List<ApiRequestLog>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(key) ?? const [];
    return raw
        .map((item) {
          try {
            final decoded = jsonDecode(item);
            return decoded is Map
                ? ApiRequestLog.fromJson(Map<String, dynamic>.from(decoded))
                : null;
          } catch (_) {
            return null;
          }
        })
        .whereType<ApiRequestLog>()
        .toList();
  }

  static Future<void> append(ApiRequestLog entry) async {
    final entries = await load();
    entries.insert(0, entry);
    final limited = entries
        .take(maxEntries)
        .map((item) => jsonEncode(item.toJson()))
        .toList();
    final p = await SharedPreferences.getInstance();
    await p.setStringList(key, limited);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(key);
  }
}

class AiImageService {
  static Future<String> generate({
    required String prompt,
    String size = '1024x1024',
    List<String>? referenceImages,
  }) async {
    final p = await SharedPreferences.getInstance();
    final key = (p.getString('ai_api_key') ?? '').trim().replaceFirst(
      RegExp(r'^(Bearer\s+)+', caseSensitive: false),
      '',
    );
    final model = (p.getString('ai_model') ?? '').trim();
    final provider = p.getString('ai_provider') ?? '';
    var url = (p.getString('ai_base_url') ?? '').trim();
    if (key.isEmpty || model.isEmpty) {
      throw StateError('请先在“我的 · AI服务配置”中填写 API Key 和模型');
    }
    final isArk = provider == '火山方舟' || model.startsWith('doubao-seedream');
    if (model.startsWith('doubao-seedream')) {
      // Seedream 不使用旧配置中的 OpenAI/自定义地址，始终走火山方舟图片接口。
      url = 'https://ark.cn-beijing.volces.com/api/v3/images/generations';
    } else if (url.isEmpty && isArk) {
      url = 'https://ark.cn-beijing.volces.com/api/v3/images/generations';
    }
    if (url.isEmpty) throw StateError('请先配置 API Base URL');
    if (!url.endsWith('/images/generations')) {
      url = '${url.replaceFirst(RegExp(r'/+$'), '')}/images/generations';
    }
    final body = <String, dynamic>{
      'model': model,
      'prompt': prompt.trim().isEmpty ? '生成一张高质量小说插画' : prompt.trim(),
      'size': isArk ? '2K' : size,
      'response_format': 'url',
    };
    if (referenceImages != null && referenceImages.isNotEmpty) {
      if (referenceImages.length == 1) {
        // 单张参考图沿用原有字段格式。
        body['image'] = referenceImages.first;
      } else {
        // 多张参考图按导入顺序发送，text 字段用于让模型区分每张图片的次序。
        body['image'] = [
          for (var i = 0; i < referenceImages.length; i++)
            {'image': referenceImages[i], 'text': '参考图${i + 1}'},
        ];
      }
    }
    if (isArk) {
      body.addAll({
        'sequential_image_generation': 'disabled',
        'stream': false,
        'watermark': true,
      });
    }
    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120));
    } catch (error) {
      stopwatch.stop();
      await ApiRequestLogStore.append(
        ApiRequestLog(
          timestamp: DateTime.now(),
          provider: provider,
          model: model,
          url: url,
          statusCode: null,
          durationMs: stopwatch.elapsedMilliseconds,
          success: false,
          error: error.toString(),
        ),
      );
      rethrow;
    }
    stopwatch.stop();
    final requestSucceeded =
        response.statusCode >= 200 && response.statusCode < 300;
    await ApiRequestLogStore.append(
      ApiRequestLog(
        timestamp: DateTime.now(),
        provider: provider,
        model: model,
        url: url,
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        success: requestSucceeded,
        error: requestSucceeded ? null : 'HTTP ${response.statusCode}',
      ),
    );
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded is Map ? decoded['error'] : null;
      final message = error is Map
          ? (error['message'] ?? error['code'] ?? '接口返回错误').toString()
          : (decoded is Map
                    ? (decoded['message'] ?? response.body)
                    : response.body)
                .toString();
      throw StateError('API 请求失败（${response.statusCode}）：$message');
    }
    final list = decoded is Map && decoded['data'] is List
        ? decoded['data'] as List
        : decoded is Map && decoded['images'] is List
        ? decoded['images'] as List
        : const [];
    if (list.isEmpty || list.first is! Map) {
      throw StateError('API 请求成功，但没有返回图片数据');
    }
    final item = list.first as Map;
    final imageUrl = item['url']?.toString();
    if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
    final b64 = item['b64_json']?.toString();
    if (b64 != null && b64.isNotEmpty) return 'data:image/png;base64,$b64';
    throw StateError('API 返回中没有可显示的图片地址');
  }
}

class AiImagePreview extends StatelessWidget {
  final String image;
  final BoxFit fit;
  const AiImagePreview({
    required this.image,
    this.fit = BoxFit.cover,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (image.startsWith('assets/')) return Image.asset(image, fit: fit);
    if (image.startsWith('data:image/')) {
      final comma = image.indexOf(',');
      return Image.memory(base64Decode(image.substring(comma + 1)), fit: fit);
    }
    if (!image.startsWith('http://') && !image.startsWith('https://')) {
      return Image.file(
        File(image),
        fit: fit,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: Color(0xFFE8DED0),
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );
    }
    return Image.network(
      image,
      fit: fit,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: Color(0xFFE8DED0),
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ArcReaderApp());
}

class ArcReaderApp extends StatefulWidget {
  const ArcReaderApp({super.key});
  @override
  State<ArcReaderApp> createState() => _ArcReaderState();
}

class _ArcReaderState extends State<ArcReaderApp> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      const Shelf(),
      const Works(),
      const Gallery(),
      const Worlds(),
      const Mine(),
    ];
    return ValueListenableBuilder<bool>(
      valueListenable: appDarkMode,
      builder: (_, dark, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'serif',
          scaffoldBackgroundColor: background,
          colorScheme: ColorScheme.fromSeed(seedColor: gold),
        ),
        darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: gold,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(
          body: pages[tab],
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.auto_stories_outlined),
                label: '书架',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                label: '作品',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                label: 'AI生图',
              ),
              NavigationDestination(
                icon: Icon(Icons.public_outlined),
                label: '设定集',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                label: '我的',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget cover(String asset, {double width = 76, double height = 104}) =>
    ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(asset, width: 76, height: 104, fit: BoxFit.cover),
    );
Widget card(Widget child) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: surface,
    border: Border.all(color: const Color(0xFFE5D8C2)),
    borderRadius: BorderRadius.circular(16),
  ),
  child: child,
);

class Shelf extends StatefulWidget {
  const Shelf({super.key});
  @override
  State<Shelf> createState() => _ShelfState();
}

class _ShelfState extends State<Shelf> {
  bool grid = false;
  String query = '';
  final books = <List<String>>[
    ['assets/cover_shanhai.png', '山海来信', '东方幻想 · 12 章 · 阅读进度 18%'],
    ['assets/cover_changye.png', '长夜拾光', '都市异能 · 42 章 · 阅读进度 46%'],
    ['assets/cover_yunchen.png', '云深不知处', '古风仙侠 · 25 章 · 已完结'],
  ];

  @override
  void initState() {
    super.initState();
    _loadImportedBook();
  }

  Future<void> _loadImportedBook() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('latest_imported_work');
    if (raw == null || !mounted) return;
    try {
      final work = _ImportedWork.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      setState(() {
        books.removeWhere((book) => book[1] == work.title);
        books.insert(0, [
          'assets/cover_shanhai.png',
          work.title,
          '本地导入 · ${work.chapters.length} 章 · 可阅读',
        ]);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final visible = books.where((b) => b[1].contains(query)).toList();
    final body = grid
        ? GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: visible.map((b) => _gridBook(context, b)).toList(),
          )
        : Column(children: visible.map((b) => _listBook(context, b)).toList());
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 90),
          children: [
            const Text(
              'ARC READER',
              style: TextStyle(
                color: gold,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '我的书架',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(onPressed: _search, icon: const Icon(Icons.search)),
                IconButton(
                  onPressed: () => setState(() => grid = !grid),
                  icon: Icon(grid ? Icons.view_list : Icons.grid_view),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text(
                  '本地作品',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 5),
                Text(
                  '(${visible.length})',
                  style: const TextStyle(color: Colors.black45),
                ),
              ],
            ),
            const SizedBox(height: 10),
            body,
          ],
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: FloatingActionButton.extended(
            backgroundColor: gold,
            foregroundColor: Colors.white,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Works()),
              );
              _loadImportedBook();
            },
            icon: const Icon(Icons.add),
            label: const Text('导入作品'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteFromShelf(
    BuildContext context,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这本小说？'),
        content: Text('确定从书架删除《$title》吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('latest_imported_work');
    var isImported = false;
    if (raw != null) {
      try {
        isImported =
            _ImportedWork.fromJson(
              jsonDecode(raw) as Map<String, dynamic>,
            ).title ==
            title;
      } catch (_) {}
    }
    if (!isImported) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(
                        content: Text('内置示例作品不能删除'),
                        duration: Duration(milliseconds: 1200),
                      ));
      return;
    }
    await p.remove('latest_imported_work');
    if (!mounted) return;
    setState(() => books.removeWhere((book) => book[1] == title));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(
                        content: Text('作品已删除'),
                        duration: Duration(milliseconds: 1200),
                      ));
  }

  Widget _listBook(BuildContext context, List<String> b) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: () => _openBook(context, b[1]),
      onLongPress: () => _confirmDeleteFromShelf(context, b[1]),
      child: card(
        Row(
          children: [
            cover(b[0]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b[1],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    b[2],
                    style: const TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(
                    value: .3,
                    color: gold,
                    backgroundColor: Color(0xFFE5D8C2),
                    minHeight: 3,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: gold),
          ],
        ),
      ),
    ),
  );
  Widget _gridBook(BuildContext context, List<String> b) => InkWell(
    onTap: () => _openBook(context, b[1]),
    onLongPress: () => _confirmDeleteFromShelf(context, b[1]),
    child: card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Image.asset(b[0], width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          Text(
            b[1],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            b[2],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 10),
          ),
        ],
      ),
    ),
  );
  Future<void> _search() async {
    final c = TextEditingController(text: query);
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('搜索书架'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入书名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('清空'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('搜索'),
          ),
        ],
      ),
    );
    if (value != null) setState(() => query = value.trim());
  }

  Future<void> _openBook(BuildContext context, String title) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookDetail(title: title)),
    );
    await _loadImportedBook();
    final p = await SharedPreferences.getInstance();
    if (p.getString('latest_imported_work') == null && mounted) {
      setState(() => books.removeWhere((book) => book[1] == title));
    }
  }
}

class BookDetail extends StatefulWidget {
  final String title;
  const BookDetail({required this.title, super.key});

  @override
  State<BookDetail> createState() => _BookDetailState();
}

class _BookDetailState extends State<BookDetail> {
  _ImportedWork? importedWork;
  int lastChapter = 1;

  String get title => widget.title;

  @override
  void initState() {
    super.initState();
    _loadImportedWork();
  }

  Future<void> _loadImportedWork() async {
    final work = await ImportedWorkStore.load();
    final p = await SharedPreferences.getInstance();
    final savedChapter = p.getInt('reading_chapter_$title') ?? 1;
    if (mounted)
      setState(() {
        if (work?.title == title) importedWork = work;
        lastChapter = savedChapter;
      });
  }

  String get asset => title.contains('长夜')
      ? 'assets/cover_changye.png'
      : title.contains('云深')
      ? 'assets/cover_yunchen.png'
      : 'assets/cover_shanhai.png';

  Future<void> _deleteBook(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这本小说？'),
        content: Text('确定从书架删除《$title》吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('latest_imported_work');
    var isImported = false;
    if (raw != null) {
      try {
        isImported =
            _ImportedWork.fromJson(
              jsonDecode(raw) as Map<String, dynamic>,
            ).title ==
            title;
      } catch (_) {}
    }
    if (!isImported) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(
                        content: Text('内置示例作品不能删除'),
                        duration: Duration(milliseconds: 1200),
                      ));
      return;
    }
    await p.remove('latest_imported_work');
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(
                        content: Text('作品已删除'),
                        duration: Duration(milliseconds: 1200),
                      ));
    Navigator.pop(context, true);
  }

  void _showChapters(BuildContext context) {
    final importedChapters = importedWork?.title == title
        ? importedWork!.chapters
        : const <_ParsedChapter>[];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: background,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              '目录',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...(importedChapters.isNotEmpty
                ? importedChapters.asMap().entries.map(
                    (entry) => ListTile(
                      leading: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(color: gold),
                      ),
                      title: Text(entry.value.title),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReaderPage(
                              chapter: entry.key + 1,
                              bookTitle: title,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : List.generate(
                    12,
                    (i) => ListTile(
                      leading: Text(
                        '${i + 1}',
                        style: const TextStyle(color: gold),
                      ),
                      title: Text('第${i + 1}章 · ${i == 1 ? '青梅不太对劲' : '山海来信'}'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ReaderPage(chapter: i + 1, bookTitle: title),
                          ),
                        );
                      },
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isImported = importedWork?.title == title;
    final chapterCount = isImported ? importedWork!.chapters.length : 12;
    final importedText = isImported
        ? importedWork!.chapters.map((chapter) => chapter.content).join('\n')
        : '';
    final progress = (lastChapter / chapterCount).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        title: const Text('作品详情'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              if (value == 'delete') _deleteBook(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('删除这本小说')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          card(
            Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  cover(asset, width: 108, height: 148),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isImported ? '本地导入作品' : '东方幻想 · 完结',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '共$chapterCount章 · ${isImported ? importedText.length : 33128}字',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '阅读进度',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '${(progress * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          color: gold,
                          backgroundColor: Color(0xFFE5D8C2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '上次阅读：第${lastChapter}章',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('作品简介', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 10),
                Text(
                  isImported
                      ? (importedText.isEmpty
                            ? '暂无简介'
                            : importedText.substring(
                                0,
                                importedText.length.clamp(0, 220),
                              ))
                      : '顾今朝从铺着鸳鸯锦被的床榻上醒来，茫然望着头顶绣着鸳鸯的锦帐。\n\n好消息：女主各具特色，皆为脱世子。',
                  style: TextStyle(
                    color: Colors.black54,
                    height: 1.55,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 6),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    '展开',
                    style: TextStyle(color: gold, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
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
                  builder: (_) => BookAiGalleryPage(title: title),
                ),
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text(
                '进入 AI 图片集合',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16283A),
              ),
            ),
          ),
          const SizedBox(height: 14),
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '角色',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CharacterListPage(),
                        ),
                      ),
                      child: const Text(
                        '全部角色',
                        style: TextStyle(color: gold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 146,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: const [
                      CharacterCard(
                        name: '林静茹',
                        role: '女主 · 温柔坚韧',
                        intro: '外柔内刚的同行者，藏着一段旧日往事。',
                        image: 'assets/ai_portrait.png',
                      ),
                      SizedBox(width: 12),
                      CharacterCard(
                        name: '顾今朝',
                        role: '男主 · 山海客',
                        intro: '误入山海的书生，正在寻找回家的路。',
                        image: 'assets/cover_shanhai.png',
                      ),
                      SizedBox(width: 12),
                      CharacterCard(
                        name: '沈青萝',
                        role: '配角 · 神秘少女',
                        intro: '来历神秘的少女，熟悉这片沉睡的山海。',
                        image: 'assets/cover_yunchen.png',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '本地文件',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8DECD),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Text(
                          'TXT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isImported ? importedWork!.fileName : '山海来信.txt',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            isImported ? '${importedText.length} 字' : '3.28 MB',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.folder_open_outlined,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '作品信息',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                SizedBox(height: 10),
                _InfoLine('导入时间', '2025-05-20 10:56'),
                _InfoLine('最后阅读', '2025-05-21 22:14'),
                _InfoLine('字数统计', '33,128 字'),
                _InfoLine('章节数量', '$chapterCount 章'),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: background,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showChapters(context),
                  icon: const Icon(Icons.list),
                  label: const Text('目录'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReaderPage(
                        chapter: isImported
                            ? (lastChapter < 1
                                  ? 1
                                  : (lastChapter > chapterCount
                                        ? chapterCount
                                        : lastChapter))
                            : 2,
                        bookTitle: title,
                      ),
                    ),
                  ),
                  style: FilledButton.styleFrom(backgroundColor: gold),
                  child: const Text('继续阅读'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});
  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final controller = TextEditingController();
  String query = '';
  List<(String, String, String)> results = [];
  static const demoResults = [
    ('山海来信', '第2章 · 青梅不太对劲', '明夷沉默了一会，忽然开口，对众人道：“你们等在这里。”'),
    ('山海来信', '第2章 · 青梅不太对劲', '“既然我负今日行动，便理应带你们所有人活着离开。”'),
    ('山海来信', '第2章 · 青梅不太对劲', '“你怎么样？”李明夷赶忙问。'),
    ('长夜拾光', '第8章 · 雨夜来客', '灯火在长街尽头摇曳，雨声落在青石板上。'),
  ];

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final work = await ImportedWorkStore.load();
    final loaded = <(String, String, String)>[...demoResults];
    if (work != null) {
      for (var i = 0; i < work.chapters.length; i++) {
        final chapter = work.chapters[i];
        final preview = chapter.content.trim();
        if (preview.isEmpty) continue;
        loaded.add((
          work.title,
          '第${i + 1}章 · ${chapter.title}',
          preview.substring(0, preview.length.clamp(0, 120)),
        ));
      }
    }
    if (mounted) setState(() => results = loaded);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget _highlight(String text) {
    final keyword = query.trim();
    if (keyword.isEmpty) return Text(text);
    final parts = text.split(keyword);
    final spans = <TextSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        spans.add(
          TextSpan(
            text: keyword,
            style: const TextStyle(color: Color(0xFFE69A00)),
          ),
        );
      }
      spans.add(TextSpan(text: parts[i]));
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(color: primaryText, fontSize: 18, height: 1.45),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      toolbarHeight: 86,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, size: 32),
      ),
      leadingWidth: 52,
      titleSpacing: 0,
      title: Row(
        children: [
          Expanded(
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFEADFE1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                onChanged: (v) => setState(() => query = v),
                onSubmitted: (v) => setState(() => query = v.trim()),
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 22),
                decoration: InputDecoration(
                  hintText: '搜索',
                  hintStyle: const TextStyle(fontSize: 22),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search, size: 34),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            controller.clear();
                            setState(() => query = '');
                          },
                          icon: const Icon(Icons.cancel, size: 30),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () => FocusScope.of(context).unfocus(),
            child: const Text(
              '搜索',
              style: TextStyle(color: Color(0xFFE69A00), fontSize: 20),
            ),
          ),
        ],
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        if (query.trim().isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 52),
            child: Center(child: Text('输入关键词搜索作品、章节或正文')),
          )
        else
          ...results
              .where(
                (r) =>
                    r.$1.contains(query) ||
                    r.$2.contains(query) ||
                    r.$3.contains(query),
              )
              .map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReaderPage(
                          chapter: r.$1 == '山海来信' ? 2 : 8,
                          bookTitle: r.$1,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _highlight(r.$3),
                          const SizedBox(height: 10),
                          Text(
                            '${r.$1}  ·  ${r.$2}',
                            style: TextStyle(color: mutedText, fontSize: 13),
                          ),
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

class ReaderPage extends StatefulWidget {
  final int chapter;
  final String bookTitle;
  const ReaderPage({required this.chapter, this.bookTitle = '山海来信', super.key});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderBookmark {
  final int chapter;
  final int page;
  final String preview;
  const _ReaderBookmark(this.chapter, this.page, this.preview);
}

class _ReaderPageState extends State<ReaderPage> {
  _ImportedWork? importedWork;
  bool focused = false;
  bool bookmarked = false;
  bool pullBookmarkBadge = false;
  String pullBookmarkLabel = '书签';
  double pullOffset = 0;
  double brightness = .55;
  final PageController readingPages = PageController();
  int currentPage = 0;
  final List<_ReaderBookmark> bookmarks = [];
  final Set<int> bookmarkedPages = {};
  bool _ready = false;
  int _savedChapterPage = 0;
  static const int _charsPerPage = 560;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final work = await ImportedWorkStore.load();
    if (!mounted) return;
    setState(() {
      importedWork = work?.title == widget.bookTitle ? work : null;
      _ready = true;
    });
    await _loadBookmarks();
    if (!mounted) return;
    setState(() {
      currentPage = _initialGlobalPage();
      bookmarked = bookmarkedPages.contains(currentPage);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && readingPages.hasClients) {
        readingPages.jumpToPage(currentPage);
      }
    });
  }

  List<int> get _chapterPageCounts {
    final chapters = importedWork?.chapters;
    if (chapters == null) return List.filled(12, 2);
    return [
      for (final c in chapters)
        c.content.trim().isEmpty
            ? 1
            : (c.content.trim().length / _charsPerPage).ceil(),
    ];
  }

  List<int> get _chapterStartPages {
    final counts = _chapterPageCounts;
    final starts = <int>[0];
    for (var i = 0; i < counts.length - 1; i++) {
      starts.add(starts[i] + counts[i]);
    }
    return starts;
  }

  int get _totalPages => _chapterPageCounts.fold(0, (sum, n) => sum + n);

  int get _chapterCount => importedWork?.chapters.length ?? 12;

  int _clampInt(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  (int, int) _locationOf(int globalPage) {
    final starts = _chapterStartPages;
    var chapter = 0;
    for (var i = 1; i < starts.length; i++) {
      if (globalPage >= starts[i]) {
        chapter = i;
      } else {
        break;
      }
    }
    return (chapter, globalPage - starts[chapter]);
  }

  int _globalPageOf(int chapterIndex, int pageInChapter) =>
      _chapterStartPages[chapterIndex] + pageInChapter;

  int get _currentChapterIndex => _locationOf(currentPage).$1;
  int get _currentChapterNumber => _currentChapterIndex + 1;
  int get _currentPageInChapter => _locationOf(currentPage).$2;

  int _initialGlobalPage() {
    final counts = _chapterPageCounts;
    final chapterIndex = _clampInt(widget.chapter - 1, 0, _chapterCount - 1);
    final saved = _clampInt(_savedChapterPage, 0, counts[chapterIndex] - 1);
    return _clampInt(
      _chapterStartPages[chapterIndex] + saved,
      0,
      _totalPages - 1,
    );
  }

  String _chapterHeaderText(int chapterNumber, String title) {
    final numbered =
        RegExp(r'^第[0-9零一二三四五六七八九十百千万两]+[章节回卷集]').hasMatch(
          title,
        ) ||
        RegExp(r'^Chapter\s+\d+', caseSensitive: false).hasMatch(title);
    return numbered ? title : '第$chapterNumber章 · $title';
  }

  Widget _buildChapterHeader(int chapterIndex) {
    final title = importedWork?.chapters[chapterIndex].title ??
        (chapterIndex + 1 == 2 ? '青梅不太对劲' : '山海来信');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _chapterHeaderText(chapterIndex + 1, title),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: gold,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDemoPage(int chapterIndex, int pageInChapter) {
    final children = <Widget>[];
    if (pageInChapter == 0) children.add(_buildChapterHeader(chapterIndex));
    children.addAll(
      pageInChapter == 0
          ? const [
              Text('红烛摇曳，簌字高悬。', style: TextStyle(fontSize: 18, height: 2.05)),
              SizedBox(height: 18),
              Text('“这是哪里？”', style: TextStyle(fontSize: 18, height: 2.05)),
              SizedBox(height: 18),
              Text('顾今朝从铺着鸳鸯锦被的床榻上醒来，茫然望着头顶绣着鸳鸯的锦帐。',
                  style: TextStyle(fontSize: 18, height: 2.05)),
              SizedBox(height: 18),
              Text('“师兄醒了？”', style: TextStyle(fontSize: 18, height: 2.05)),
            ]
          : const [
              Text('一道轻如烟絮的嗓音飘入耳中，带着几分缠绵，几分幽怨。',
                  style: TextStyle(fontSize: 18, height: 2.05)),
              SizedBox(height: 18),
              Text('他微力侧过头，正对上了一双含情带怨的美眸。',
                  style: TextStyle(fontSize: 18, height: 2.05)),
              SizedBox(height: 18),
              Text('林静茹穿着一袭大红嫁衣，红盖头已掀开，露出一张略显苍白的俏脸。',
                  style: TextStyle(
                    fontSize: 18,
                    height: 2.05,
                    color: Colors.black87,
                  )),
            ],
    );
    return _ReadingPageContent(children: children);
  }

  Widget _buildPage(int globalPage) {
    final (chapterIndex, pageInChapter) = _locationOf(globalPage);
    final chapters = importedWork?.chapters;
    if (chapters == null) return _buildDemoPage(chapterIndex, pageInChapter);
    if (chapterIndex < 0 || chapterIndex >= chapters.length) {
      return const _ReadingPageContent(
        children: [Text('找不到该章节内容', style: TextStyle(fontSize: 18))],
      );
    }
    final content = chapters[chapterIndex].content.trim();
    if (content.isEmpty) {
      return const _ReadingPageContent(
        children: [Text('本章节暂无正文内容', style: TextStyle(fontSize: 18))],
      );
    }
    final start = pageInChapter * _charsPerPage;
    final end = start + _charsPerPage > content.length
        ? content.length
        : start + _charsPerPage;
    return _ReadingPageContent(
      children: [
        if (pageInChapter == 0) _buildChapterHeader(chapterIndex),
        Text(
          content.substring(start, end),
          style: const TextStyle(fontSize: 18, height: 2.05),
        ),
      ],
    );
  }

  @override
  void dispose() {
    readingPages.dispose();
    super.dispose();
  }

  String get _bookmarksKey => 'bookmarks_${widget.bookTitle}';

  Future<void> _loadBookmarks() async {
    final p = await SharedPreferences.getInstance();
    final loaded = <_ReaderBookmark>[];
    final pages = <int>{};
    final raw = p.getStringList(_bookmarksKey) ?? const <String>[];
    for (final item in raw) {
      final parts = item.split(':');
      if (parts.length != 2) continue;
      final c = int.tryParse(parts[0]);
      final pg = int.tryParse(parts[1]);
      if (c == null || pg == null || c < 1 || c > _chapterCount) continue;
      if (pg < 0 || pg >= _chapterPageCounts[c - 1]) continue;
      loaded.add(_ReaderBookmark(c, pg, '红烛摇曳，簌字高悬。'));
      final global = _globalPageOf(c - 1, pg);
      if (global >= 0 && global < _totalPages) pages.add(global);
    }
    for (var i = 1; i <= _chapterCount; i++) {
      final legacy = p.getBool('bookmark_${widget.bookTitle}_$i') ?? false;
      final pg = p.getInt('bookmark_page_${widget.bookTitle}_$i');
      if (legacy &&
          pg != null &&
          pg >= 0 &&
          pg < _chapterPageCounts[i - 1] &&
          !loaded.any((b) => b.chapter == i && b.page == pg)) {
        loaded.add(_ReaderBookmark(i, pg, '红烛摇曳，簌字高悬。'));
        final global = _globalPageOf(i - 1, pg);
        if (global >= 0 && global < _totalPages) pages.add(global);
      }
    }
    _savedChapterPage =
        p.getInt('reading_page_${widget.bookTitle}_${widget.chapter}') ?? 0;
    if (mounted) {
      setState(() {
        bookmarks..clear()..addAll(loaded);
        bookmarkedPages..clear()..addAll(pages);
      });
    }
  }

  Future<void> _persistBookmarks() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _bookmarksKey,
      bookmarks.map((b) => '${b.chapter}:${b.page}').toList(),
    );
  }

  void _persistReadingPosition() {
    final (chapterIndex, pageInChapter) = _locationOf(currentPage);
    SharedPreferences.getInstance().then((p) {
      p.setInt(
        'reading_page_${widget.bookTitle}_${chapterIndex + 1}',
        pageInChapter,
      );
      p.setInt('reading_chapter_${widget.bookTitle}', chapterIndex + 1);
    });
  }

  Future<void> _markBookmark() async {
    final (chapterIndex, pageInChapter) = _locationOf(currentPage);
    final chapter = chapterIndex + 1;
    if (!bookmarked) {
      setState(() {
        bookmarked = true;
        bookmarkedPages.add(currentPage);
      });
    }
    if (!bookmarks.any((b) => b.chapter == chapter && b.page == pageInChapter)) {
      setState(
        () => bookmarks.add(
          _ReaderBookmark(chapter, pageInChapter, '红烛摇曳，簌字高悬。'),
        ),
      );
    }
    await _persistBookmarks();
  }

  Future<void> _addBookmark() async {
    await _markBookmark();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: gold,
          duration: const Duration(milliseconds: 1200),
          content: Row(
            children: [
              const Icon(Icons.bookmark, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                '书签已添加 · 第$_currentChapterNumber章 · 第${_currentPageInChapter + 1}页',
              ),
            ],
          ),
        ),
      );
    setState(() {});
  }

  Future<void> _toggleBookmark() async {
    if (bookmarked) {
      await _unmarkCurrentBookmark();
    } else {
      await _addBookmark();
    }
  }

  Future<void> _unmarkCurrentBookmark() async {
    final (chapterIndex, pageInChapter) = _locationOf(currentPage);
    if (!mounted) return;
    setState(() {
      bookmarked = false;
      bookmarkedPages.remove(currentPage);
      bookmarks.removeWhere(
        (b) => b.chapter == chapterIndex + 1 && b.page == pageInChapter,
      );
    });
    await _persistBookmarks();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1200),
          content: Text('书签已删除'),
        ),
      );
  }

  Future<void> _deleteBookmark(
    _ReaderBookmark bookmark, [
    VoidCallback? refreshSheet,
  ]) async {
    setState(() {
      bookmarks.removeWhere(
        (b) => b.chapter == bookmark.chapter && b.page == bookmark.page,
      );
      if (bookmark.chapter >= 1 && bookmark.chapter <= _chapterCount) {
        final global = _globalPageOf(bookmark.chapter - 1, bookmark.page);
        bookmarkedPages.remove(global);
        if (bookmark.chapter == _currentChapterNumber &&
            bookmark.page == _currentPageInChapter) {
          bookmarked = false;
        }
      }
    });
    await _persistBookmarks();
    refreshSheet?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1200),
        content: Text('书签已删除'),
      ),
    );
  }

  Future<void> _confirmDeleteBookmark(
    _ReaderBookmark bookmark, [
    VoidCallback? refreshSheet,
  ]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除书签？'),
        content: Text('确定删除第${bookmark.chapter}章第${bookmark.page + 1}页的书签吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _deleteBookmark(bookmark, refreshSheet);
    }
  }

  Future<void> _addTag() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 12,
          decoration: const InputDecoration(hintText: '例如：重点、伏笔、人物线索'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || value == null || value.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1200),
        content: Text('标签已添加：${value.trim()}'),
      ),
    );
  }

  Future<void> _finishPullDown() async {
    final shouldBookmark = pullOffset >= 56;
    setState(() => pullOffset = 0);
    if (!shouldBookmark) return;
    final adding = !bookmarked;
    await _toggleBookmark();
    if (!mounted) return;
    setState(() {
      pullBookmarkLabel = '书签';
      pullBookmarkBadge = adding;
    });
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => pullBookmarkBadge = false);
    });
  }

  void _toggleTheme() {
    appDarkMode.value = !appDarkMode.value;
    if (mounted) setState(() {});
  }

  void _showGlobalSearch() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const GlobalSearchPage()),
  );

  String get chapterName {
    final chapters = importedWork?.chapters ?? const <_ParsedChapter>[];
    if (_currentChapterIndex >= 0 && _currentChapterIndex < chapters.length) {
      return chapters[_currentChapterIndex].title;
    }
    return _currentChapterIndex + 1 == 2 ? '青梅不太对劲' : '山海来信';
  }

  void _showChapters() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: background,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => DefaultTabController(
          length: 2,
          child: SafeArea(
            child: SizedBox(
              height: 500,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: gold,
                    tabs: [
                      Tab(text: '书签'),
                      Tab(text: '目录'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        bookmarks.isEmpty
                            ? const Center(child: Text('翻页后会自动记录书签'))
                            : ListView(
                                children: bookmarks
                                    .map(
                                      (b) => GestureDetector(
                                        onLongPress: () =>
                                            _confirmDeleteBookmark(
                                              b,
                                              () => setSheetState(() {}),
                                            ),
                                        child: ListTile(
                                          leading: const Icon(
                                            Icons.bookmark,
                                            color: gold,
                                          ),
                                          title: Text('第${b.chapter}章'),
                                          subtitle: Text('${b.preview} · 长按删除'),
                                          trailing: Text('第${b.page + 1}页'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            readingPages.jumpToPage(
                                              _globalPageOf(
                                                b.chapter - 1,
                                                b.page,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                        ListView(children: _chapterTiles()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _chapterTiles() {
    final chapters = importedWork?.chapters ?? const <_ParsedChapter>[];
    if (chapters.isNotEmpty) {
      return chapters
          .asMap()
          .entries
          .map(
            (entry) => ListTile(
              leading: Text(
                '${entry.key + 1}',
                style: const TextStyle(color: gold),
              ),
              title: Text(entry.value.title),
              trailing: entry.key + 1 == _currentChapterNumber
                  ? const Icon(Icons.check, color: gold)
                  : null,
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReaderPage(
                      chapter: entry.key + 1,
                      bookTitle: widget.bookTitle,
                    ),
                  ),
                );
              },
            ),
          )
          .toList();
    }
    return List.generate(
      12,
      (i) => ListTile(
        leading: Text('${i + 1}', style: const TextStyle(color: gold)),
        title: Text('第${i + 1}章 · ${i == 1 ? '青梅不太对劲' : '山海来信'}'),
        trailing: i + 1 == _currentChapterNumber
            ? const Icon(Icons.check, color: gold)
            : null,
        onTap: () {
          Navigator.pop(context);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ReaderPage(chapter: i + 1, bookTitle: widget.bookTitle),
            ),
          );
        },
      ),
    );
  }

  void _showProgress() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: background,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          double value = _currentChapterNumber / _chapterCount;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '阅读进度',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '第$_currentChapterNumber章 / $_chapterCount章',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  Slider(
                    value: value,
                    min: .08,
                    max: 1,
                    activeColor: gold,
                    onChanged: (v) => setSheetState(() => value = v),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(backgroundColor: gold),
                    child: const Text('保存进度'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readerProgress = _totalPages == 0
        ? 0.0
        : (currentPage + 1) / _totalPages;
    return Scaffold(
      backgroundColor: background,
      appBar: focused
          ? AppBar(
              backgroundColor: background,
              title: Text(
                '第$_currentChapterNumber章、$chapterName',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: focused
                  ? [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz),
                      onSelected: (value) {
                        if (value == 'bookmark') _toggleBookmark();
                        if (value == 'search') _showGlobalSearch();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'bookmark',
                          child: Text(bookmarked ? '删除书签' : '添加书签'),
                        ),
                        const PopupMenuItem(
                          value: 'search',
                          child: Text('全局搜索'),
                        ),
                      ],
                    ),
                  ]
                : [],
          )
        : null,
    body: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => focused = !focused),
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 0 || pullOffset > 0) {
          setState(
            () => pullOffset = (pullOffset + details.delta.dy).clamp(0, 110),
          );
        }
      },
      onVerticalDragEnd: (_) => _finishPullDown(),
      child: Stack(
        children: [
          Transform.translate(
            offset: Offset(0, pullOffset),
            child: Column(
              children: [
                Expanded(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity((1 - brightness) * .35),
                      BlendMode.darken,
                    ),
                    child: PageView.builder(
                      controller: readingPages,
                      onPageChanged: (page) {
                        setState(() {
                          currentPage = page;
                          bookmarked = bookmarkedPages.contains(page);
                        });
                        _persistReadingPosition();
                      },
                      itemCount: _ready ? _totalPages : 1,
                      itemBuilder: (_, page) => _ready
                          ? _buildPage(page)
                          : const _ReadingPageContent(
                              children: [
                                SizedBox(height: 24),
                                Text(
                                  '加载中…',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                if (focused)
                  Container(
                    decoration: BoxDecoration(
                      color: surface,
                      border: Border(top: BorderSide(color: Color(0xFFE5D8C2))),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$_currentChapterNumber/$_chapterCount',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: LinearProgressIndicator(
                                  value: readerProgress,
                                  minHeight: 3,
                                  color: gold,
                                  backgroundColor: Color(0xFFE5D8C2),
                                ),
                              ),
                            ),
                            Text(
                              '${(readerProgress * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _ReaderTool(
                              icon: Icons.list,
                              label: '目录',
                              onTap: _showChapters,
                            ),
                            _ReaderTool(
                              icon: Icons.wb_sunny_outlined,
                              label: '主题',
                              onTap: _toggleTheme,
                            ),
                            _ReaderTool(
                              icon: Icons.image_outlined,
                              label: 'AI生图',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BookAiGeneratePage(
                                    title: widget.bookTitle,
                                  ),
                                ),
                              ),
                            ),
                            _ReaderTool(
                              icon: Icons.cloud_outlined,
                              label: '设定集',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    backgroundColor: background,
                                    appBar: AppBar(
                                      backgroundColor: background,
                                      title: Text(
                                        '${widget.bookTitle} · 设定集',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    body: Worlds(
                                      initialTitle: widget.bookTitle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _ReaderTool(
                              icon: Icons.settings_outlined,
                              label: '设置',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ReadingPreferencesPage(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.wb_sunny_outlined, size: 18),
                            Expanded(
                              child: Slider(
                                value: brightness,
                                min: .2,
                                max: 1,
                                divisions: 8,
                                label: '${(brightness * 100).round()}%',
                                onChanged: (v) =>
                                    setState(() => brightness = v),
                                activeColor: const Color(0xFF665F56),
                              ),
                            ),
                            const Icon(Icons.add, size: 18),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            top: (bookmarked || pullBookmarkBadge) ? 0 : -54,
            right: 18,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFD94040),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark, color: Colors.white, size: 18),
                  SizedBox(width: 5),
                  Text(
                    pullBookmarkLabel,
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }
}

class AiImagePage extends StatefulWidget {
  const AiImagePage({super.key});
  @override
  State<AiImagePage> createState() => _AiImagePageState();
}

class _AiImagePageState extends State<AiImagePage> {
  int tab = 0;
  bool quote = true;
  bool generating = false;
  String? generatedImage;
  String ratio = '横图 16:9';
  String style = '电影感';

  Future<void> _generate() async {
    if (generating) return;
    setState(() => generating = true);
    try {
      final result = await AiImageService.generate(
        prompt:
            '${tab == 0 ? '小说人物' : '小说场景'}，$style，${ratio == '横图 16:9' ? '横构图' : '竖构图'}',
        size: ratio == '横图 16:9' ? '1536x1024' : '1024x1536',
      );
      final localImage = await AiImageStorage.save(result, prefix: 'character');
      if (!mounted) return;
      setState(() => generatedImage = localImage ?? result);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(
                        content: Text('图片生成成功'),
                        duration: Duration(milliseconds: 1200),
                      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Bad state: ', '')),
            duration: const Duration(milliseconds: 1200),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: const Text(
        'AI 生图（阅读中）',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            color: const Color(0xFF112235),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AI 生图',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _AiTab(
                      label: '角色',
                      selected: tab == 0,
                      onTap: () => setState(() => tab = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AiTab(
                      label: '场景',
                      selected: tab == 1,
                      onTap: () => setState(() => tab = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 82,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    '描述你想生成的画面……',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '引用当前段落',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Switch(
                    value: quote,
                    onChanged: (v) => setState(() => quote = v),
                    activeColor: gold,
                  ),
                ],
              ),
              const Text(
                '风格与比例',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...['横图 16:9', '竖图 3:4'].map(
                    (x) => _AiChoice(
                      label: x,
                      selected: ratio == x,
                      onTap: () => setState(() => ratio = x),
                    ),
                  ),
                  ...['电影感', '国风', '水墨'].map(
                    (x) => _AiChoice(
                      label: x,
                      selected: style == x,
                      onTap: () => setState(() => style = x),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                '生成预览',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: generatedImage == null
                    ? Image.asset(
                        'assets/ai_portrait.png',
                        width: double.infinity,
                        height: 158,
                        fit: BoxFit.cover,
                      )
                    : AiImagePreview(image: generatedImage!, fit: BoxFit.cover),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    generating ? '生成中…' : '生成图片',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(backgroundColor: gold),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AiTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AiTab({
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
        color: selected ? const Color(0xFF283A50) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    ),
  );
}

class _AiChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AiChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: selected ? gold : Colors.white12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? gold : Colors.white60,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    ),
  );
}

class _ReadingPageContent extends StatelessWidget {
  final List<Widget> children;
  const _ReadingPageContent({required this.children});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _ReaderTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ReaderTool({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(
      children: [
        Icon(icon, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    ),
  );
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.black54, fontSize: 11),
        ),
      ],
    ),
  );
}

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
  static const characters = [
    ('林静茹', '女主 · 温柔坚韧', 'assets/ai_portrait.png'),
    ('顾今朝', '男主 · 山海客', 'assets/cover_shanhai.png'),
    ('沈青萝', '配角 · 神秘少女', 'assets/cover_yunchen.png'),
    ('谢沉舟', '配角 · 旧友', 'assets/cover_changye.png'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: const Text('全部角色', style: TextStyle(fontWeight: FontWeight.w900)),
    ),
    body: ListView.separated(
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

  String get fullBodyImage => image == 'assets/ai_portrait.png'
      ? 'assets/cover_shanhai.png'
      : 'assets/cover_changye.png';

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
                '她是故事中重要的同行者，外表温柔安静，内心却有坚定的信念。她与主角在山海之间相遇，共同揭开一段被尘封的往事。',
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
              _InfoLine('首次出现', '第1章'),
              _InfoLine('相关章节', '8章'),
              _InfoLine('人物关系', '主角同行者'),
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

  String get fullBodyImage => image == 'assets/ai_portrait.png'
      ? 'assets/cover_shanhai.png'
      : 'assets/cover_changye.png';

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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _RelationChip(label: '萧景珩', relation: '倾心相爱'),
                  _RelationChip(label: '慕云深', relation: '惺惺相惜'),
                  _RelationChip(label: '沈清妍', relation: '情同姐妹'),
                  _RelationChip(label: '林老太夫人', relation: '祖孙情深'),
                ],
              ),
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
  static const names = ['林静茹', '顾今朝', '安绮兮', '伊人姐', '姬婉', '小郎君', '师兄'];
  static const images = [
    'assets/ai_portrait.png',
    'assets/cover_shanhai.png',
    'assets/cover_yunchen.png',
    'assets/cover_changye.png',
    'assets/ai_portrait.png',
    'assets/cover_yunchen.png',
    'assets/cover_changye.png',
  ];

  void select(String name, String image) => setState(() {
    selected = name;
    selectedImage = image;
  });

  @override
  Widget build(BuildContext context) => Scaffold(
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
                      onTap: () {},
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
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '关系：顾今朝 · 深爱    师兄 · 执念',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
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

class CharacterAiPage extends StatefulWidget {
  final String name;
  final String image;
  const CharacterAiPage({required this.name, required this.image, super.key});
  @override
  State<CharacterAiPage> createState() => _CharacterAiPageState();
}

class _CharacterAiPageState extends State<CharacterAiPage> {
  int mode = 0;
  bool generating = false;
  String? generatedImage;
  late final TextEditingController prompt = TextEditingController(
    text: '东方幻想风格，温柔坚韧，红色古典服饰，烛光氛围',
  );

  @override
  void dispose() {
    prompt.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (generating) return;
    setState(() => generating = true);
    try {
      final result = await AiImageService.generate(
        prompt:
            '${prompt.text.trim()}，${mode == 0 ? '人物头像，半身构图' : '人物全身立绘，全身构图'}',
        size: mode == 0 ? '1024x1024' : '1024x1536',
      );
      if (!mounted) return;
      setState(() => generatedImage = result);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(
                        content: Text('图片生成成功'),
                        duration: Duration(milliseconds: 1200),
                      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Bad state: ', '')),
            duration: const Duration(milliseconds: 1200),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: Text(
        '${widget.name} · AI 形象',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF112235),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '根据描述生成',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '为角色生成专属头像或全身形象',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _AiTab(
                      label: '头像',
                      selected: mode == 0,
                      onTap: () => setState(() => mode = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AiTab(
                      label: '全身图',
                      selected: mode == 1,
                      onTap: () => setState(() => mode = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: prompt,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '描述人物外貌、服饰、动作和氛围……',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: generatedImage == null
                    ? Image.asset(
                        mode == 0 ? widget.image : 'assets/cover_shanhai.png',
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : AiImagePreview(image: generatedImage!, fit: BoxFit.cover),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    generating ? '生成中…' : '生成形象',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(backgroundColor: gold),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ParsedChapter {
  final String title;
  final String content;
  const _ParsedChapter(this.title, this.content);
}

class _ImportedWork {
  final String fileName;
  final String title;
  final List<_ParsedChapter> chapters;
  const _ImportedWork({
    required this.fileName,
    required this.title,
    required this.chapters,
  });

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'title': title,
    'chapters': chapters
        .map((chapter) => {'title': chapter.title, 'content': chapter.content})
        .toList(),
  };

  factory _ImportedWork.fromJson(Map<String, dynamic> json) {
    final chapterList = (json['chapters'] as List? ?? [])
        .whereType<Map>()
        .map(
          (item) => _ParsedChapter(
            item['title']?.toString() ?? '未命名章节',
            item['content']?.toString() ?? '',
          ),
        )
        .toList();
    return _ImportedWork(
      fileName: json['fileName']?.toString() ?? '',
      title: json['title']?.toString() ?? '未命名作品',
      chapters: chapterList,
    );
  }
}

class ImportedWorkStore {
  static Future<_ImportedWork?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('latest_imported_work');
    if (raw == null || raw.isEmpty) return null;
    try {
      return _ImportedWork.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(_ImportedWork work) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'latest_imported_work',
      jsonEncode(work.toJson()),
    );
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('latest_imported_work');
  }
}

class Works extends StatefulWidget {
  const Works({super.key});
  @override
  State<Works> createState() => _WorksState();
}

class _WorksState extends State<Works> {
  _ImportedWork? importedWork;
  _ImportedWork? savedWork;
  bool pendingImport = false;
  bool importing = false;

  @override
  void initState() {
    super.initState();
    _loadImportedWork();
  }

  Future<void> _loadImportedWork() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('latest_imported_work');
    if (raw == null || !mounted) return;
    try {
      setState(() {
        savedWork = _ImportedWork.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        importedWork = savedWork;
      });
    } catch (_) {
      await preferences.remove('latest_imported_work');
    }
  }

  Future<void> _pickFile() async {
    if (importing) return;
    setState(() => importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'json'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) {
        if (mounted) setState(() => importing = false);
        return;
      }

      final pickedFile = result.files.single;
      final extension = pickedFile.extension?.toLowerCase();
      if (extension == 'json') {
        throw const FormatException('暂不支持直接导入 JSON 作品，请选择 TXT 或 MD 文件');
      }
      final text = _decodeText(pickedFile.bytes!);
      final chapters = _parseChapters(text);
      final title = _titleFromFileName(pickedFile.name);
      final work = _ImportedWork(
        fileName: pickedFile.name,
        title: title,
        chapters: chapters,
      );
      if (!mounted) return;
      setState(() {
        importedWork = work;
        pendingImport = true;
        importing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1200),
          content: Text('已选择《$title》，请点击下方“导入作品”确认'),
        ),
      );
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => importing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            content: Text(error.message),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => importing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            content: Text('导入失败：$error'),
          ),
        );
      }
    }
  }

  Future<void> _confirmImport() async {
    if (importing) return;
    if (!pendingImport || importedWork == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text('请先点击上方“选择本地文件”'),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }
    setState(() => importing = true);
    await ImportedWorkStore.save(importedWork!);
    if (!mounted) return;
    setState(() {
      savedWork = importedWork;
      pendingImport = false;
      importing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1200),
        content: Text(
          '已导入《${importedWork!.title}》，解析出 ${importedWork!.chapters.length} 章',
        ),
      ),
    );
  }

  Future<void> _cancelImport() async {
    if (!mounted) return;
    setState(() {
      // 只取消本次待确认的文件选择，保留已经导入并持久化的作品。
      importedWork = savedWork;
      pendingImport = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(
        content: Text('已取消导入，可重新选择文件'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  String _decodeText(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  String _titleFromFileName(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  List<_ParsedChapter> _parseChapters(String text) {
    final chapterPattern = RegExp(
      r'^\s*(?:#+\s*)?((?:第[0-9零一二三四五六七八九十百千万两]+[章节回卷集].{0,60})|(?:Chapter|chapter)\s+\d+.{0,60})\s*$',
      multiLine: true,
    );
    final matches = chapterPattern.allMatches(text).toList();
    if (matches.isEmpty) {
      final content = text.trim();
      if (content.isEmpty) {
        throw const FormatException('文件内容为空，无法解析作品');
      }
      return [_ParsedChapter('正文', content)];
    }

    final chapters = <_ParsedChapter>[];
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final nextStart = i + 1 < matches.length
          ? matches[i + 1].start
          : text.length;
      final title = match.group(1)?.trim() ?? '未命名章节';
      final content = text.substring(match.end, nextStart).trim();
      chapters.add(_ParsedChapter(title, content));
    }
    return chapters;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: const Text(
        '导入本地作品',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '支持 TXT / MD 格式，角色、世界观、封面等设定可为空',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 18),
        InkWell(
          onTap: importing ? null : _pickFile,
          borderRadius: BorderRadius.circular(16),
          child: card(
            const SizedBox(
              height: 150,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.create_new_folder_outlined, color: gold, size: 38),
                  SizedBox(height: 8),
                  Text(
                    '选择本地文件',
                    style: TextStyle(color: gold, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '点击此处选择 TXT / MD 文件',
                    style: TextStyle(color: Colors.black45, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (importedWork != null) ...[
          card(
            Row(
              children: [
                const Icon(Icons.description_outlined, color: gold),
                const SizedBox(width: 10),
                Expanded(child: Text(importedWork!.fileName)),
                const Icon(Icons.check_circle, color: gold),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '解析结果 · 共 ${importedWork!.chapters.length} 章',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          card(
            Column(
              children: importedWork!.chapters
                  .take(5)
                  .toList()
                  .asMap()
                  .entries
                  .map(
                    (entry) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(color: gold),
                      ),
                      title: Text(entry.value.title),
                      trailing: const Icon(
                        Icons.check_circle_outline,
                        color: gold,
                        size: 18,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: importing ? null : _confirmImport,
            style: FilledButton.styleFrom(backgroundColor: gold),
            child: Text(importing ? '正在解析作品…' : '导入作品'),
          ),
        ),
        if (importedWork != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: importing ? null : _cancelImport,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('取消导入'),
            ),
          ),
        ],
      ],
    ),
  );
}

class _AiGalleryItem {
  final String bookTitle;
  final String image;
  final String label;
  final int category;
  const _AiGalleryItem(this.bookTitle, this.image, this.label, this.category);

  Map<String, dynamic> toJson() => {
    'bookTitle': bookTitle,
    'image': image,
    'label': label,
    'category': category,
  };

  factory _AiGalleryItem.fromJson(Map<String, dynamic> json) => _AiGalleryItem(
    json['bookTitle']?.toString() ?? '',
    json['image']?.toString() ?? '',
    json['label']?.toString() ?? 'AI 图片',
    (json['category'] as num?)?.toInt() ?? 0,
  );
}

class AiGalleryStore {
  static final items = <_AiGalleryItem>[];
  static const storageKey = 'ai_gallery_items';

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(storageKey) ?? const [];
    items
      ..clear()
      ..addAll(
        raw.map((value) {
          try {
            final json = jsonDecode(value);
            return json is Map
                ? _AiGalleryItem.fromJson(Map<String, dynamic>.from(json))
                : null;
          } catch (_) {
            return null;
          }
        }).whereType<_AiGalleryItem>(),
      );
  }

  static Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      storageKey,
      items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  static Future<void> clear() async {
    items.clear();
    final p = await SharedPreferences.getInstance();
    await p.remove(storageKey);
  }

  static Future<void> add({
    required String bookTitle,
    required int category,
    required String prompt,
    String? image,
  }) async {
    const previews = [
      'assets/cover_shanhai.png',
      'assets/ai_portrait.png',
      'assets/cover_yunchen.png',
    ];
    items.insert(
      0,
      _AiGalleryItem(
        bookTitle,
        image ?? previews[category],
        prompt.isEmpty ? 'AI 新作品' : prompt,
        category,
      ),
    );
    await _save();
  }
}

class BookAiGalleryPage extends StatefulWidget {
  final String title;
  const BookAiGalleryPage({required this.title, super.key});
  @override
  State<BookAiGalleryPage> createState() => _BookAiGalleryPageState();
}

class _BookAiGalleryPageState extends State<BookAiGalleryPage> {
  int category = 0;
  final categories = const ['场景', '人物', '物品'];
  final images = const [
    _AiGalleryItem('山海来信', 'assets/cover_shanhai.png', '山海初见', 0),
    _AiGalleryItem('山海来信', 'assets/cover_shanhai.png', '云上鲸歌', 0),
    _AiGalleryItem('山海来信', 'assets/cover_yunchen.png', '林静茹', 1),
    _AiGalleryItem('山海来信', 'assets/ai_portrait.png', '红妆人物', 1),
    _AiGalleryItem('山海来信', 'assets/cover_changye.png', '旧城灯火', 2),
    _AiGalleryItem('山海来信', 'assets/cover_shanhai.png', '月下归舟', 2),
  ];

  @override
  void initState() {
    super.initState();
    AiGalleryStore.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  List<_AiGalleryItem> get visibleImages => [...images, ...AiGalleryStore.items]
      .where(
        (item) => item.bookTitle == widget.title && item.category == category,
      )
      .toList();

  Future<void> _importImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (!mounted) return;
    if (result != null && result.files.single.bytes != null) {
      final folder = await AiImageStorage.directory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${folder.path}/import_$stamp.png');
      await file.writeAsBytes(result.files.single.bytes!, flush: true);
      await AiGalleryStore.add(
        bookTitle: widget.title,
        category: category,
        prompt: result.files.single.name,
        image: file.path,
      );
      if (mounted) setState(() {});
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1200),
        content: Text(
          result == null ? '已取消导入' : '图片已导入到${categories[category]}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0F1E2D),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0F1E2D),
      foregroundColor: Colors.white,
      title: Text(
        '${widget.title} · AI 图片',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
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
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: List.generate(
              categories.length,
              (i) => Expanded(
                child: _GalleryTab(
                  label: categories[i],
                  selected: category == i,
                  onTap: () => setState(() => category = i),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: .92,
            ),
            itemCount: visibleImages.length,
            itemBuilder: (_, i) => _GalleryImage(
              image: visibleImages[i].image,
              label: visibleImages[i].label,
            ),
          ),
        ),
        SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF142A3D),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookAiGeneratePage(title: widget.title),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('AI 生成图片'),
                    style: FilledButton.styleFrom(backgroundColor: gold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _importImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('导入图片'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _GalleryTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GalleryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
          ),
        ),
      ),
    ),
  );
}

class _GalleryImage extends StatelessWidget {
  final String image;
  final String label;
  const _GalleryImage({required this.image, required this.label});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Stack(
      fit: StackFit.expand,
      children: [
        AiImagePreview(image: image, fit: BoxFit.cover),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black54,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ReferenceImage {
  final String name;
  final String base64;
  const _ReferenceImage({required this.name, required this.base64});
}

class BookAiGeneratePage extends StatefulWidget {
  final String title;
  const BookAiGeneratePage({required this.title, super.key});
  @override
  State<BookAiGeneratePage> createState() => _BookAiGeneratePageState();
}

class _BookAiGeneratePageState extends State<BookAiGeneratePage> {
  int mode = 0;
  int category = 0;
  bool generating = false;
  final prompt = TextEditingController();
  final List<_ReferenceImage> references = [];

  @override
  void dispose() {
    prompt.dispose();
    super.dispose();
  }

  Future<void> _pickReference() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final List<_ReferenceImage> picked = [];
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      final bytes = await File(path).readAsBytes();
      final lowerPath = path.toLowerCase();
      final mime = lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')
          ? 'jpeg'
          : lowerPath.endsWith('.webp')
          ? 'webp'
          : 'png';
      picked.add(
        _ReferenceImage(
          name: file.name,
          base64: 'data:image/$mime;base64,${base64Encode(bytes)}',
        ),
      );
    }
    if (picked.isEmpty) return;
    setState(() => references.addAll(picked));
  }

  void _removeReference(int index) {
    setState(() => references.removeAt(index));
  }

  Future<void> _generate() async {
    if (generating) return;
    setState(() => generating = true);
    try {
      final categoryName = ['场景', '人物', '物品'][category];
      final result = await AiImageService.generate(
        prompt:
            '${prompt.text.trim()}，${categoryName}类小说插画，${mode == 0 ? '参考图风格' : '高质量原创构图'}',
        size: category == 1 ? '1024x1536' : '1536x1024',
        referenceImages: mode == 0 && references.isNotEmpty
            ? [for (final r in references) r.base64]
            : null,
      );
      final localImage = await AiImageStorage.save(result, prefix: 'gallery');
      await AiGalleryStore.add(
        bookTitle: widget.title,
        category: category,
        prompt: prompt.text.trim(),
        image: localImage ?? result,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookAiGalleryPage(title: widget.title),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Bad state: ', '')),
            duration: const Duration(milliseconds: 1200),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: const Text(
        'AI 生成图片',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      children: [
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择生图方式',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _GenerateChoice(
                      label: '根据参考图生成',
                      selected: mode == 0,
                      onTap: () => setState(() => mode = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _GenerateChoice(
                      label: '从零生成',
                      selected: mode == 1,
                      onTap: () => setState(() => mode = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text('图片归类', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(
                  3,
                  (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
                      child: _GenerateChoice(
                        label: ['场景', '人物', '物品'][i],
                        selected: category == i,
                        onTap: () => setState(() => category = i),
                      ),
                    ),
                  ),
                ),
              ),
              if (mode == 0) ...[
                const SizedBox(height: 18),
                const Text(
                  '参考图片（可多张，按导入顺序编号）',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (references.isNotEmpty) ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < references.length; i++)
                        _ReferenceThumb(
                          index: i,
                          image: references[i],
                          onRemove: () => _removeReference(i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                InkWell(
                  onTap: _pickReference,
                  child: Container(
                    height: 90,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5D8C2)),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFFCF7ED),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: gold,
                            size: 26,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            references.isEmpty ? '点击上传参考图片' : '继续添加参考图片',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '提示：可一次导入多张参考图，模型会按导入顺序编号区分图片，例如“第一张图片的人物按照第二张图片的姿势”。',
                  style: TextStyle(color: Colors.black45, fontSize: 11),
                ),
              ],
              const SizedBox(height: 18),
              const Text('画面描述', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              TextField(
                controller: prompt,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '描述你想生成的画面……',
                  counterText: '0/300',
                  filled: true,
                  fillColor: Color(0xFFFCF7ED),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE5D8C2)),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    generating ? '生成中…' : '生成图片',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: FilledButton.styleFrom(backgroundColor: gold),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReferenceThumb extends StatelessWidget {
  final int index;
  final _ReferenceImage image;
  final VoidCallback onRemove;
  const _ReferenceThumb({
    required this.index,
    required this.image,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = base64Decode(image.base64.split(',').last);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5D8C2)),
            color: const Color(0xFFFCF7ED),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.memory(
              bytes,
              width: 92,
              height: 92,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.black38,
                size: 30,
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: gold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _GenerateChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GenerateChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      decoration: BoxDecoration(
        color: selected ? gold : const Color(0xFFFCF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? gold : const Color(0xFFE5D8C2)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
          ),
        ),
      ),
    ),
  );
}

class Gallery extends StatelessWidget {
  const Gallery({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      const Text(
        'AI IMAGE LIBRARY',
        style: TextStyle(
          color: gold,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
      const Text(
        'AI 生图',
        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 18),
      const Text(
        '选择作品，进入该作品的 AI 图片集合',
        style: TextStyle(color: Colors.black54),
      ),
      const SizedBox(height: 12),
      ...[
        ('山海来信', '东方幻想 · 18张图片', 'assets/cover_shanhai.png'),
        ('长夜难明', '悬疑奇幻 · 8张图片', 'assets/cover_changye.png'),
        ('云深知处', '古风仙侠 · 12张图片', 'assets/cover_yunchen.png'),
      ].map(
        (book) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookAiGalleryPage(title: book.$1),
              ),
            ),
            borderRadius: BorderRadius.circular(16),
            child: card(
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      book.$3,
                      width: 64,
                      height: 76,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.$1,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          book.$2,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '点击查看 AI 图片',
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
  final Map<String, String> worldSettings = {};

  @override
  void initState() {
    super.initState();
    selectedTitle = widget.initialTitle;
    if (selectedTitle != null) _loadWorldSettings();
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

  final characters = const [
    ('林静茹', '女主 · 温柔坚韧', '外柔内刚的同行者，藏着一段旧日往事。', 'assets/ai_portrait.png'),
    ('顾今朝', '男主 · 山海客', '误入山海的书生，正在寻找回家的路。', 'assets/cover_shanhai.png'),
    ('沈青萝', '配角 · 神秘少女', '来历神秘，熟悉这片沉睡的山海。', 'assets/cover_yunchen.png'),
  ];

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
            ...[
              ('山海来信', '东方幻想 · 世界观与角色', 'assets/cover_shanhai.png'),
              ('长夜难明', '悬疑奇幻 · 暂未添加设定', 'assets/cover_changye.png'),
              ('云深知处', '古风仙侠 · 暂未添加设定', 'assets/cover_yunchen.png'),
            ].map(
              (book) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      selectedTitle = book.$1;
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
                          child: Image.asset(
                            book.$3,
                            width: 70,
                            height: 84,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.$1,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                book.$2,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$selectedTitle · 故事资料库',
                style: const TextStyle(color: Colors.black54),
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
                    '这里将展示作品的时代背景、地域设定与世界规则。',
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
            ...characters.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _WorldCharacterRow(
                  name: c.$1,
                  role: c.$2,
                  intro: c.$3,
                  image: c.$4,
                ),
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

class Mine extends StatelessWidget {
  const Mine({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      const Text(
        'READER SETTINGS',
        style: TextStyle(
          color: gold,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
      const Text(
        '我的',
        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 18),
      card(
        Column(
          children: [
            ListTile(
              leading: const Icon(Icons.palette_outlined, color: gold),
              title: const Text('阅读偏好'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReadingPreferencesPage(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.key_outlined, color: gold),
              title: const Text('AI 服务配置'),
              subtitle: const Text(
                '配置 AI 生图 API',
                style: TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiServiceConfigPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.storage_outlined, color: gold),
              title: const Text('数据管理'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DataManagementPage()),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

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
                onChanged: (v) => setState(() => fontSize = v),
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
                onChanged: (v) => setState(() => immersive = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('翻页动效'),
                value: pageTurn,
                activeColor: gold,
                onChanged: (v) => setState(() => pageTurn = v),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AiServiceConfigPage extends StatefulWidget {
  const AiServiceConfigPage({super.key});
  @override
  State<AiServiceConfigPage> createState() => _AiServiceConfigPageState();
}

class _AiServiceConfigPageState extends State<AiServiceConfigPage> {
  final baseUrl = TextEditingController();
  final apiKey = TextEditingController();
  final model = TextEditingController(text: 'doubao-seedream-4-5-251128');
  String provider = '火山方舟';
  String selectedModel = 'doubao-seedream-4-5-251128';
  bool obscure = true;
  bool loading = true;
  bool testing = false;
  List<ApiRequestLog> requestLogs = const [];
  Map<String, String> initialConfiguration = const {};

  static const arkBaseUrl =
      'https://ark.cn-beijing.volces.com/api/v3/images/generations';
  static const modelOptions = <String, String>{
    'doubao-seedream-4-5-251128': 'Seedream 4.5（推荐）',
    'doubao-seedream-4-0-250828': 'Seedream 4.0',
    '自定义模型': '自定义模型',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final logs = await ApiRequestLogStore.load();
    final savedBaseUrl = p.getString('ai_base_url') ?? '';
    baseUrl.text =
        savedBaseUrl.isEmpty &&
            (p.getString('ai_model') == null ||
                (p.getString('ai_model') ?? '').startsWith('doubao-seedream'))
        ? arkBaseUrl
        : savedBaseUrl;
    apiKey.text = p.getString('ai_api_key') ?? '';
    final rawModel = p.getString('ai_model') ?? '';
    final savedModel =
        rawModel.isEmpty ||
            rawModel == 'image-generation' ||
            rawModel == 'Doubao-Seedream-4.5' ||
            rawModel == 'doubao-seedream-4.5'
        ? 'doubao-seedream-4-5-251128'
        : rawModel;
    model.text = savedModel;
    if (savedModel != rawModel) {
      await p.setString('ai_model', savedModel);
      await p.setString('ai_provider', '火山方舟');
      await p.setString('ai_base_url', arkBaseUrl);
      baseUrl.text = arkBaseUrl;
    }
    if (mounted) {
      setState(() {
        provider = p.getString('ai_provider') ?? '火山方舟';
        selectedModel = modelOptions.containsKey(savedModel)
            ? savedModel
            : '自定义模型';
        initialConfiguration = {
          'provider': provider,
          'base_url': baseUrl.text,
          'api_key': apiKey.text,
          'model': model.text,
        };
        requestLogs = logs;
        loading = false;
      });
    }
  }

  Future<void> _clearRequestLogs() async {
    if (requestLogs.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除 API 请求日志？'),
        content: const Text('删除后将无法恢复历史请求记录。'),
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
    await ApiRequestLogStore.clear();
    if (!mounted) return;
    setState(() => requestLogs = const []);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(
        content: Text('API 请求日志已删除'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  String _formatLogTime(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  Widget _requestLogsCard() => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'API 请求日志',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
            TextButton.icon(
              onPressed: requestLogs.isEmpty ? null : _clearRequestLogs,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('删除日志'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
        Text(
          requestLogs.isEmpty
              ? '暂无请求记录'
              : '最近 ${requestLogs.length} 条记录（最多保留 ${ApiRequestLogStore.maxEntries} 条）',
          style: TextStyle(color: mutedText, fontSize: 12),
        ),
        if (requestLogs.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...requestLogs
              .take(10)
              .map(
                (log) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    log.success
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    color: log.success ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    '${log.provider.isEmpty ? 'API' : log.provider} · ${log.model}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_formatLogTime(log.timestamp)} · ${log.statusCode == null ? '无响应' : 'HTTP ${log.statusCode}'} · ${log.durationMs} ms\n'
                    '${log.error ?? log.url}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: mutedText, fontSize: 11),
                  ),
                ),
              ),
        ],
      ],
    ),
  );

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    // 保存覆盖前的配置，供“恢复之前配置”使用。
    final oldValues = <String, String>{
      'provider': p.getString('ai_provider') ?? '',
      'base_url': p.getString('ai_base_url') ?? '',
      'api_key': p.getString('ai_api_key') ?? '',
      'model': p.getString('ai_model') ?? '',
    };
    for (final entry in oldValues.entries) {
      await p.setString('ai_previous_${entry.key}', entry.value);
    }
    await p.setString('ai_provider', provider);
    await p.setString('ai_base_url', baseUrl.text.trim());
    await p.setString('ai_api_key', apiKey.text.trim());
    await p.setString('ai_model', model.text.trim());
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text('AI 服务配置已保存'),
          duration: Duration(milliseconds: 1200),
        ),
      );
  }

  Future<void> _restorePrevious() async {
    final p = await SharedPreferences.getInstance();
    final previousModel = p.getString('ai_previous_model');
    if (previousModel == null) {
      if (initialConfiguration.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            const SnackBar(
              content: Text('还没有可恢复的历史配置'),
              duration: Duration(milliseconds: 1200),
            ),
          );
        }
        return;
      }
      setState(() {
        provider = initialConfiguration['provider'] ?? '火山方舟';
        baseUrl.text = initialConfiguration['base_url'] ?? '';
        apiKey.text = initialConfiguration['api_key'] ?? '';
        model.text = initialConfiguration['model'] ?? '';
        selectedModel = modelOptions.containsKey(model.text)
            ? model.text
            : '自定义模型';
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text('已恢复本次打开页面前的配置'),
            duration: Duration(milliseconds: 1200),
          ),
        );
      }
      return;
    }
    setState(() {
      provider = p.getString('ai_previous_provider') ?? '火山方舟';
      baseUrl.text = p.getString('ai_previous_base_url') ?? '';
      apiKey.text = p.getString('ai_previous_api_key') ?? '';
      model.text = previousModel;
      selectedModel = modelOptions.containsKey(previousModel)
          ? previousModel
          : '自定义模型';
    });
    await p.setString('ai_provider', provider);
    await p.setString('ai_base_url', baseUrl.text);
    await p.setString('ai_api_key', apiKey.text);
    await p.setString('ai_model', model.text);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text('已恢复之前保存的 AI 配置'),
          duration: Duration(milliseconds: 1200),
        ),
      );
    }
  }

  void _selectModel(String? value) {
    if (value == null) return;
    setState(() {
      selectedModel = value;
      if (value != '自定义模型') {
        model.text = value;
        provider = '火山方舟';
        baseUrl.text = arkBaseUrl;
      }
    });
  }

  Future<void> _testConnection() async {
    // 兼容用户粘贴完整的“Bearer xxx”或只粘贴 Key 两种形式。
    final key = apiKey.text.trim().replaceFirst(
      RegExp(r'^(Bearer\s+)+', caseSensitive: false),
      '',
    );
    final selected = model.text.trim();
    var url = baseUrl.text.trim();
    if (key.isEmpty || selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先填写 API Base URL、API Key 和模型名称'),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }
    if (selected.startsWith('doubao-seedream')) {
      // Seedream 始终请求火山方舟，避免旧的 Base URL 导致请求发错服务。
      url = arkBaseUrl;
    } else if (provider == '火山方舟') {
      url = url.isEmpty ? arkBaseUrl : url;
    } else {
      if (url.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text('当前模型需要填写 API Base URL'),
            duration: Duration(milliseconds: 1200),
          ),
        );
        return;
      }
      if (!url.endsWith('/images/generations')) {
        url = '${url.replaceFirst(RegExp(r'/+$'), '')}/images/generations';
      }
    }
    if (testing) return;
    setState(() => testing = true);
    try {
      final isArk =
          provider == '火山方舟' || selected.startsWith('doubao-seedream');
      final body = isArk
          ? <String, dynamic>{
              'model': selected,
              'prompt': '生成一张简单的测试图片，只用于检查 API 是否连通。',
              'size': '2K',
              'sequential_image_generation': 'disabled',
              'stream': false,
              'response_format': 'url',
              'watermark': true,
            }
          : <String, dynamic>{
              'model': selected,
              'prompt': '生成一张简单的测试图片，只用于检查 API 是否连通。',
              'size': '1024x1024',
              'response_format': 'url',
            };
      final stopwatch = Stopwatch()..start();
      http.Response response;
      try {
        response = await http
            .post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $key',
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 90));
      } catch (error) {
        stopwatch.stop();
        await ApiRequestLogStore.append(
          ApiRequestLog(
            timestamp: DateTime.now(),
            provider: provider,
            model: selected,
            url: url,
            statusCode: null,
            durationMs: stopwatch.elapsedMilliseconds,
            success: false,
            error: error.toString(),
          ),
        );
        if (mounted) {
          final logs = await ApiRequestLogStore.load();
          setState(() => requestLogs = logs);
        }
        rethrow;
      }
      stopwatch.stop();

      Map<String, dynamic> responseBody = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) responseBody = decoded;
      } catch (_) {}

      final requestSucceeded =
          response.statusCode >= 200 && response.statusCode < 300;
      await ApiRequestLogStore.append(
        ApiRequestLog(
          timestamp: DateTime.now(),
          provider: provider,
          model: selected,
          url: url,
          statusCode: response.statusCode,
          durationMs: stopwatch.elapsedMilliseconds,
          success: requestSucceeded,
          error: requestSucceeded ? null : 'HTTP ${response.statusCode}',
        ),
      );
      if (mounted) {
        final logs = await ApiRequestLogStore.load();
        setState(() => requestLogs = logs);
      }

      if (!mounted) return;
      if (requestSucceeded) {
        final hasImage =
            responseBody['data'] is List &&
            (responseBody['data'] as List).isNotEmpty;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            content: Text(
              hasImage ? 'API 连接成功，已返回测试图片' : 'API 请求成功，但响应中没有图片数据',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        final error = responseBody['error'];
        final message = error is Map
            ? (error['message'] ?? error['code'] ?? '接口返回错误').toString()
            : (responseBody['message'] ?? response.body).toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            content: Text('API 连接失败（${response.statusCode}）：$message'),
          ),
        );
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API 返回格式无法解析，请检查 Base URL 是否正确'),
            duration: Duration(milliseconds: 1200),
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text('API 请求超时，请检查网络或服务地址'),
            duration: Duration(milliseconds: 1200),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            content: Text('API 连接失败：$error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => testing = false);
    }
  }

  @override
  void dispose() {
    baseUrl.dispose();
    apiKey.dispose();
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: const Text(
        'AI 服务配置',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: gold))
        : ListView(
            padding: const EdgeInsets.all(18),
            children: [
              card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '生图服务',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '用于 AI 生图、角色头像和全身图生成',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: provider,
                      decoration: const InputDecoration(
                        labelText: '服务类型',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '火山方舟',
                          child: Text('火山方舟（Seedream）'),
                        ),
                        DropdownMenuItem(
                          value: 'OpenAI 兼容接口',
                          child: Text('OpenAI 兼容接口'),
                        ),
                        DropdownMenuItem(value: '自定义服务', child: Text('自定义服务')),
                      ],
                      onChanged: (v) =>
                          setState(() => provider = v ?? provider),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: baseUrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'API Base URL',
                        hintText: 'https://api.example.com/v1',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: apiKey,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'API Key',
                        hintText: '输入你的 API Key',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: model,
                      decoration: const InputDecoration(
                        labelText: '模型名称',
                        hintText: '例如：doubao-seedream-4-5-251128',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedModel,
                      decoration: const InputDecoration(
                        labelText: '快速选择模型',
                        border: OutlineInputBorder(),
                      ),
                      items: modelOptions.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: _selectModel,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: testing ? null : _testConnection,
                            icon: const Icon(Icons.wifi_tethering),
                            label: Text(testing ? '正在请求 API…' : '真实测试 API'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: gold,
                            ),
                            child: const Text('保存配置'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _restorePrevious,
                        icon: const Icon(Icons.restore),
                        label: const Text('恢复之前的配置'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _requestLogsCard(),
              const SizedBox(height: 12),
              const Text(
                '提示：Seedream 4.5 为默认模型。API Key 仅保存在本机，正式版建议迁移到安全存储。',
                style: TextStyle(color: Colors.black54, fontSize: 11),
              ),
            ],
          ),
  );
}

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key});
  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  bool openingFolder = false;
  bool clearingCache = false;
  int cacheBytes = 0;

  @override
  void initState() {
    super.initState();
    _refreshCacheSize();
  }

  Future<void> _refreshCacheSize() async {
    final size = await AiImageStorage.sizeBytes();
    if (mounted) setState(() => cacheBytes = size);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _clearImageCache() async {
    if (clearingCache || cacheBytes == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理 AI 图片缓存？'),
        content: const Text('这会删除本机保存的 AI 生成图片和导入图片。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => clearingCache = true);
    await AiImageStorage.clear();
    await AiGalleryStore.clear();
    await _refreshCacheSize();
    if (mounted) {
      setState(() => clearingCache = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text('AI 图片缓存已清理'),
          duration: Duration(milliseconds: 1200),
        ),
      );
    }
  }

  Future<void> _clearReadingRecords() async {
    final p = await SharedPreferences.getInstance();
    for (final key in p.getKeys().where(
      (key) => key.startsWith('bookmark_') || key.startsWith('reading_'),
    )) {
      await p.remove(key);
    }
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text('阅读记录已清空'),
          duration: Duration(milliseconds: 1200),
        ),
      );
  }

  Future<void> _openAiImageFolder() async {
    if (openingFolder) return;
    setState(() => openingFolder = true);
    try {
      final folder = await AiImageStorage.openDirectory();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            content: Text('已打开 AI 图片文件夹：${folder.path}'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            content: Text('打开文件夹失败：$error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => openingFolder = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      title: const Text('数据管理', style: TextStyle(fontWeight: FontWeight.w900)),
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        card(
          Column(
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined, color: gold),
                title: const Text('AI 图片缓存'),
                subtitle: Text(
                  '已占用 ${_formatBytes(cacheBytes)}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: TextButton(
                  onPressed: clearingCache || cacheBytes == 0
                      ? null
                      : _clearImageCache,
                  child: Text(
                    clearingCache ? '清理中…' : '清理',
                    style: const TextStyle(color: gold),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined, color: gold),
                title: const Text('AI 生成图片文件夹'),
                subtitle: const Text(
                  '打开本机存放 AI 生成图片的目录',
                  style: TextStyle(fontSize: 11),
                ),
                onTap: openingFolder ? null : _openAiImageFolder,
                trailing: TextButton(
                  onPressed: openingFolder ? null : _openAiImageFolder,
                  child: Text(
                    openingFolder ? '打开中…' : '打开',
                    style: const TextStyle(color: gold),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: gold),
                title: const Text('清空阅读记录'),
                trailing: TextButton(
                  onPressed: _clearReadingRecords,
                  child: const Text('清空', style: TextStyle(color: gold)),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
