part of '../main.dart';

class ImportedWorkStore {
  static const collectionKey = 'imported_works';
  static List<String>? _source;
  static Future<List<_ImportedWork>>? _decoded;
  static List<_ImportedWork>? _cachedWorks;

  static Future<List<_ImportedWork>> loadAll() async {
    final preferences = await SharedPreferences.getInstance();
    final rawList = preferences.getStringList(collectionKey);
    if (rawList != null) {
      if (!listEquals(_source, rawList)) {
        _source = List.unmodifiable(rawList);
        _cachedWorks = null;
        _decoded = null;
      }
      if (_cachedWorks != null) return List.of(_cachedWorks!);
      if (rawList.fold<int>(0, (total, item) => total + item.length) < 65536) {
        _cachedWorks = _decodeImportedWorks(rawList);
        return List.of(_cachedWorks!);
      }
      final source = _source;
      _decoded ??= compute(_decodeImportedWorks, rawList);
      try {
        final works = await _decoded!;
        if (identical(source, _source)) _cachedWorks = works;
        return List.of(works);
      } catch (_) {
        if (identical(source, _source)) _decoded = null;
        rethrow;
      }
    }
    // Migrate the old single-work storage once, without creating demo data.
    final legacy = preferences.getString('latest_imported_work');
    if (legacy == null || legacy.isEmpty) return [];
    try {
      final records = legacy.length < 65536
          ? _decodeImportedWorks([legacy])
          : await compute(_decodeImportedWorks, [legacy]);
      if (records.isEmpty) return [];
      final work = records.first;
      await preferences.setStringList(collectionKey, [legacy]);
      return [work];
    } catch (_) {
      return [];
    }
  }

  static Future<_ImportedWork?> find(String title) async {
    final normalizedTitle = title.trim();
    final works = await loadAll();
    for (final work in works) {
      if (work.title.trim() == normalizedTitle) return work;
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
    final records = await compute(_encodeImportedWorks, works);
    await preferences.setStringList(collectionKey, records);
    await preferences.setString('latest_imported_work', records.first);
  }

  static Future<bool> rename(String oldTitle, String newTitle) async {
    final oldValue = oldTitle.trim();
    final newValue = newTitle.trim();
    if (oldValue.isEmpty || newValue.isEmpty || oldValue == newValue)
      return false;
    final preferences = await SharedPreferences.getInstance();
    final works = await loadAll();
    final work = works.cast<_ImportedWork?>().firstWhere(
      (item) => item?.title == oldValue,
      orElse: () => null,
    );
    if (work == null || works.any((item) => item.title == newValue))
      return false;
    final renamed = work.copyWith(title: newValue);
    works
      ..removeWhere((item) => item.id == work.id || item.title == oldValue)
      ..insert(0, renamed);
    final records = await compute(_encodeImportedWorks, works);
    await preferences.setStringList(collectionKey, records);
    final latest = preferences.getString('latest_imported_work');
    if (latest != null && latest.contains('"title":"$oldValue"')) {
      await preferences.setString('latest_imported_work', records.first);
    }

    final prefixes = [
      'characters_${oldValue}',
      'world_${oldValue}_',
      'ai_image_pages_${oldValue}',
      'bookmarks_${oldValue}',
      'bookmark_${oldValue}_',
      'bookmark_page_${oldValue}_',
      'reading_offset_${oldValue}_',
      'reading_page_${oldValue}_',
      'reading_chapter_${oldValue}',
    ];
    for (final key in preferences.getKeys().toList()) {
      final prefix = prefixes.cast<String?>().firstWhere(
        (item) => item != null && key.startsWith(item),
        orElse: () => null,
      );
      if (prefix == null) continue;
      final suffix = key.substring(prefix.length);
      final newKey = prefix.replaceFirst(oldValue, newValue) + suffix;
      final value = preferences.get(key);
      if (value is String) {
        await preferences.setString(newKey, value);
      } else if (value is bool) {
        await preferences.setBool(newKey, value);
      } else if (value is int) {
        await preferences.setInt(newKey, value);
      } else if (value is double) {
        await preferences.setDouble(newKey, value);
      } else if (value is List<String>) {
        await preferences.setStringList(newKey, value);
      }
      await preferences.remove(key);
    }
    return true;
  }

  static Future<void> delete(String title) async {
    final preferences = await SharedPreferences.getInstance();
    final works = await loadAll();
    works.removeWhere((item) => item.title == title);
    final records = await compute(_encodeImportedWorks, works);
    await preferences.setStringList(collectionKey, records);
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

List<_ImportedWork> _decodeImportedWorks(List<String> records) => records
    .map((value) {
      try {
        final decoded = jsonDecode(value);
        return decoded is Map<String, dynamic>
            ? _ImportedWork.fromJson(decoded)
            : null;
      } catch (_) {
        return null;
      }
    })
    .whereType<_ImportedWork>()
    .toList();

List<String> _encodeImportedWorks(List<_ImportedWork> works) =>
    works.map((work) => jsonEncode(work.toJson())).toList();
