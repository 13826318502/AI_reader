part of '../../main.dart';

class _ParsedChapter {
  final String title;
  final String content;
  const _ParsedChapter(this.title, this.content);
}

class _ImportedWork {
  final String id;
  final String fileName;
  final String title;
  final List<_ParsedChapter> chapters;
  final String cover;
  const _ImportedWork({
    required this.id,
    required this.fileName,
    required this.title,
    required this.chapters,
    this.cover = '',
  });

  _ImportedWork copyWith({String? cover}) => _ImportedWork(
    id: id,
    fileName: fileName,
    title: title,
    chapters: chapters,
    cover: cover ?? this.cover,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'title': title,
    'cover': cover,
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
      id: json['id']?.toString() ?? json['title']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      title: json['title']?.toString() ?? '未命名作品',
      chapters: chapterList,
      cover: json['cover']?.toString() ?? '',
    );
  }
}

class ImportedWorkStore {
  static const collectionKey = 'imported_works';

  static Future<List<_ImportedWork>> loadAll() async {
    final preferences = await SharedPreferences.getInstance();
    final rawList = preferences.getStringList(collectionKey);
    if (rawList != null) {
      return rawList
          .map((value) {
            try {
              final json = jsonDecode(value);
              return json is Map
                  ? _ImportedWork.fromJson(Map<String, dynamic>.from(json))
                  : null;
            } catch (_) {
              return null;
            }
          })
          .whereType<_ImportedWork>()
          .toList();
    }
    // Migrate the old single-work storage once, without creating demo data.
    final legacy = preferences.getString('latest_imported_work');
    if (legacy == null || legacy.isEmpty) return [];
    try {
      final work = _ImportedWork.fromJson(
        jsonDecode(legacy) as Map<String, dynamic>,
      );
      await preferences.setStringList(collectionKey, [
        jsonEncode(work.toJson()),
      ]);
      return [work];
    } catch (_) {
      return [];
    }
  }

  static Future<_ImportedWork?> find(String title) async {
    final works = await loadAll();
    for (final work in works) {
      if (work.title == title) return work;
    }
    return null;
  }

  static Future<_ImportedWork?> load() async {
    final works = await loadAll();
    return works.isEmpty ? null : works.first;
  }

  static Future<void> save(_ImportedWork work) async {
    final preferences = await SharedPreferences.getInstance();
    final works = await loadAll();
    works.removeWhere((item) => item.id == work.id || item.title == work.title);
    works.insert(0, work);
    await preferences.setStringList(
      collectionKey,
      works.map((item) => jsonEncode(item.toJson())).toList(),
    );
    await preferences.setString(
      'latest_imported_work',
      jsonEncode(work.toJson()),
    );
  }

  static Future<void> delete(String title) async {
    final preferences = await SharedPreferences.getInstance();
    final works = await loadAll();
    works.removeWhere((item) => item.title == title);
    await preferences.setStringList(
      collectionKey,
      works.map((item) => jsonEncode(item.toJson())).toList(),
    );
    final latest = preferences.getString('latest_imported_work');
    if (latest != null) {
      try {
        if (_ImportedWork.fromJson(
              jsonDecode(latest) as Map<String, dynamic>,
            ).title ==
            title) {
          await preferences.remove('latest_imported_work');
        }
      } catch (_) {}
    }
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(collectionKey);
    await preferences.remove('latest_imported_work');
  }
}

class _AiImagePageEntry {
  final String id;
  final String image;
  final String label;
  final int afterTextPage;
  const _AiImagePageEntry({
    required this.id,
    required this.image,
    required this.label,
    required this.afterTextPage,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'image': image,
    'label': label,
    'after_text_page': afterTextPage,
  };

  factory _AiImagePageEntry.fromJson(Map<String, dynamic> json) =>
      _AiImagePageEntry(
        id: json['id']?.toString() ?? '',
        image: json['image']?.toString() ?? '',
        label: json['label']?.toString() ?? 'AI 生成图片',
        afterTextPage: (json['after_text_page'] as num?)?.toInt() ?? 0,
      );
}

class AiImagePageStore {
  static String key(String bookTitle) => 'ai_image_pages_$bookTitle';

  static Future<List<_AiImagePageEntry>> load(String bookTitle) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(key(bookTitle)) ?? const <String>[];
    return raw
        .map((value) {
          try {
            final json = jsonDecode(value);
            return json is Map
                ? _AiImagePageEntry.fromJson(Map<String, dynamic>.from(json))
                : null;
          } catch (_) {
            return null;
          }
        })
        .whereType<_AiImagePageEntry>()
        .toList();
  }

  static Future<void> save(
    String bookTitle,
    List<_AiImagePageEntry> entries,
  ) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      key(bookTitle),
      entries.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}
