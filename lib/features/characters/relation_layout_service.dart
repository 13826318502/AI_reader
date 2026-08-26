part of '../../main.dart';

class CharacterRelationLayoutService {
  static bool lastUsedRemote = false;

  static List<String> _localOrder({
    required String protagonist,
    required List<String> names,
    required List<_CharacterRelation> relations,
  }) {
    final degree = <String, int>{for (final name in names) name: 0};
    for (final relation in relations) {
      degree[relation.fromName] = (degree[relation.fromName] ?? 0) + 1;
      degree[relation.toName] = (degree[relation.toName] ?? 0) + 1;
    }
    final rest = names.where((name) => name != protagonist).toList()
      ..sort((a, b) {
        final score = (degree[b] ?? 0).compareTo(degree[a] ?? 0);
        return score != 0 ? score : a.compareTo(b);
      });
    return [protagonist, ...rest];
  }

  static Future<List<String>?> suggestOrder({
    required String protagonist,
    required List<String> names,
    required List<_CharacterRelation> relations,
  }) async {
    lastUsedRemote = false;
    final p = await SharedPreferences.getInstance();
    final key = (p.getString('ai_text_api_key') ?? '').trim();
    final model =
        (p.getString('ai_text_model') ?? p.getString('ai_model') ?? '').trim();
    var baseUrl =
        (p.getString('ai_text_base_url') ?? p.getString('ai_base_url') ?? '')
            .trim()
            .replaceFirst(RegExp(r'/+$'), '');
    final fallback = _localOrder(
      protagonist: protagonist,
      names: names,
      relations: relations,
    );
    if (key.isEmpty || model.isEmpty || baseUrl.isEmpty) return fallback;
    if (model.startsWith('doubao-seedream')) return fallback;
    final authorization = key.replaceFirst(
      RegExp(r'^(Bearer\s+)+', caseSensitive: false),
      '',
    );
    if (!baseUrl.endsWith('/chat/completions')) {
      baseUrl = '$baseUrl/chat/completions';
    }
    final relationText = relations
        .map((item) => '${item.fromName}-${item.relation}-${item.toName}')
        .join('；');
    try {
      final response = await http
          .post(
            Uri.parse(baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authorization',
            },
            body: jsonEncode({
              'model': model,
              'temperature': 0.2,
              'messages': [
                {'role': 'system', 'content': '你是小说人物关系图布局助手，只返回JSON数组，不要解释。'},
                {
                  'role': 'user',
                  'content':
                      '主角：$protagonist。人物：${names.join('、')}。关系：$relationText。请返回从上到下、从左到右的角色名数组，主角必须放第一位。',
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return fallback;
      }
      final decoded = jsonDecode(response.body);
      String? content;
      if (decoded is Map && decoded['choices'] is List) {
        final choices = decoded['choices'] as List;
        if (choices.isNotEmpty && choices.first is Map) {
          final message = (choices.first as Map)['message'];
          if (message is Map) {
            final rawContent = message['content'];
            content = rawContent is List
                ? rawContent.map((item) => item.toString()).join()
                : rawContent?.toString();
          }
        }
      }
      if (content == null) return fallback;
      final start = content.indexOf('[');
      final end = content.lastIndexOf(']');
      if (start < 0 || end <= start) return fallback;
      final parsed = jsonDecode(content.substring(start, end + 1));
      if (parsed is! List) return fallback;
      final ordered = parsed
          .map((item) => item.toString())
          .where(names.contains)
          .toList();
      lastUsedRemote = true;
      return [
        protagonist,
        ...ordered.where((name) => name != protagonist),
        ...names.where(
          (name) => name != protagonist && !ordered.contains(name),
        ),
      ];
    } catch (_) {
      return fallback;
    }
  }
}
