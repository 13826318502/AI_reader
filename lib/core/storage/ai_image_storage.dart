part of '../../main.dart';

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

  static Future<List<File>> imageFiles() async {
    final folder = await directory();
    final files = <File>[];
    await for (final entity in folder.list(
      recursive: false,
      followLinks: false,
    )) {
      if (entity is File &&
          RegExp(
            r'\.(png|jpg|jpeg|webp)$',
            caseSensitive: false,
          ).hasMatch(entity.path)) {
        files.add(entity);
      }
    }
    return files;
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
