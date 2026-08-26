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
  final String sourceUri;
  const _ImportedWork({
    required this.id,
    required this.fileName,
    required this.title,
    required this.chapters,
    this.cover = '',
    this.sourceUri = '',
  });

  _ImportedWork copyWith({String? title, String? cover, String? sourceUri}) =>
      _ImportedWork(
        id: id,
        fileName: fileName,
        title: title ?? this.title,
        chapters: chapters,
        cover: cover ?? this.cover,
        sourceUri: sourceUri ?? this.sourceUri,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'title': title,
    'cover': cover,
    'sourceUri': sourceUri,
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
      sourceUri: json['sourceUri']?.toString() ?? '',
    );
  }
}
