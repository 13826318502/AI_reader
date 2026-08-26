part of '../../main.dart';

class _CharacterRelation {
  final String id;
  final String fromName;
  final String fromImage;
  final String toName;
  final String toImage;
  final String relation;

  const _CharacterRelation({
    required this.id,
    required this.fromName,
    required this.fromImage,
    required this.toName,
    required this.toImage,
    required this.relation,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'from_name': fromName,
    'from_image': fromImage,
    'to_name': toName,
    'to_image': toImage,
    'relation': relation,
  };

  factory _CharacterRelation.fromJson(Map<String, dynamic> json) =>
      _CharacterRelation(
        id:
            json['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        fromName: json['from_name']?.toString() ?? '',
        fromImage: json['from_image']?.toString() ?? 'assets/ai_portrait.png',
        toName: json['to_name']?.toString() ?? '',
        toImage: json['to_image']?.toString() ?? 'assets/ai_portrait.png',
        relation: json['relation']?.toString() ?? '相关人物',
      );
}

class CharacterRelationStore {
  static String _key(String characterName) =>
      'character_relations_${characterName.trim()}';

  static Future<List<_CharacterRelation>> load(String characterName) async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_key(characterName)) ?? const [])
        .map((value) {
          try {
            final json = jsonDecode(value);
            return json is Map
                ? _CharacterRelation.fromJson(Map<String, dynamic>.from(json))
                : null;
          } catch (_) {
            return null;
          }
        })
        .whereType<_CharacterRelation>()
        .where((item) => item.fromName.isNotEmpty && item.toName.isNotEmpty)
        .toList();
  }

  static Future<void> save(
    String characterName,
    List<_CharacterRelation> relations,
  ) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _key(characterName),
      relations.map((relation) => jsonEncode(relation.toJson())).toList(),
    );
  }
}
