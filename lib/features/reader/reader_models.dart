part of '../../main.dart';

class _ReaderBookmark {
  final int chapter;
  final int page;
  final String preview;
  final int textOffset;
  const _ReaderBookmark(this.chapter, this.page, this.preview, this.textOffset);
}

class _ReaderFlatPage {
  final int chapterIndex;
  final int pageInChapter;
  final int textGlobal;
  final String? imagePath;
  final String? imageId;
  const _ReaderFlatPage.text(
    this.chapterIndex,
    this.pageInChapter,
    this.textGlobal,
  ) : imagePath = null,
      imageId = null;
  const _ReaderFlatPage.image(
    this.chapterIndex,
    this.textGlobal,
    this.imagePath,
    this.imageId,
  ) : pageInChapter = -1;
  bool get isImage => imagePath != null;
}

class _AiImagePageEntry {
  final String id;
  final String image;
  final String label;
  final int afterTextPage;
  final int? chapterIndex;
  final int? textOffset;
  const _AiImagePageEntry({
    required this.id,
    required this.image,
    required this.label,
    required this.afterTextPage,
    this.chapterIndex,
    this.textOffset,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'image': image,
    'label': label,
    'after_text_page': afterTextPage,
    if (chapterIndex != null) 'chapter_index': chapterIndex,
    if (textOffset != null) 'text_offset': textOffset,
  };

  factory _AiImagePageEntry.fromJson(Map<String, dynamic> json) =>
      _AiImagePageEntry(
        id: json['id']?.toString() ?? '',
        image: json['image']?.toString() ?? '',
        label: json['label']?.toString() ?? 'AI 生成图片',
        afterTextPage: (json['after_text_page'] as num?)?.toInt() ?? 0,
        chapterIndex: (json['chapter_index'] as num?)?.toInt(),
        textOffset: (json['text_offset'] as num?)?.toInt(),
      );
}
