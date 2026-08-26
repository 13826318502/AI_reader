part of '../../main.dart';

class CharacterStore {
  static String _key(String workTitle) => 'characters_$workTitle';

  static Future<List<_WorkCharacter>> load(String workTitle) async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_key(workTitle)) ?? const [])
        .map((value) {
          try {
            final json = jsonDecode(value);
            return json is Map
                ? _WorkCharacter.fromJson(Map<String, dynamic>.from(json))
                : null;
          } catch (_) {
            return null;
          }
        })
        .whereType<_WorkCharacter>()
        .toList();
  }

  static Future<void> save(
    String workTitle,
    List<_WorkCharacter> characters,
  ) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _key(workTitle),
      characters.map((character) => jsonEncode(character.toJson())).toList(),
    );
  }

  static Future<String?> pickAndCopyImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return null;
    final base = await getApplicationDocumentsDirectory();
    final folder = Directory('${base.path}/角色图片');
    if (!await folder.exists()) await folder.create(recursive: true);
    final extension = result!.files.single.extension?.toLowerCase() ?? 'png';
    final file = File(
      '${folder.path}/character_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
