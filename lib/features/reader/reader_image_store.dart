part of '../../main.dart';

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
