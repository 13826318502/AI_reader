import 'package:flutter/material.dart';

typedef _PaginationKey = (
  String,
  String,
  Size,
  TextStyle,
  TextScaler,
  TextDirection,
  Locale?,
);

class ReaderTextPaginator {
  @visibleForTesting
  static int debugLayoutCount = 0;
  static final _cache = <_PaginationKey, List<TextRange>>{};
  static int _cachedCharacters = 0;
  final Size size;
  final TextStyle style;
  final TextScaler textScaler;
  final TextDirection textDirection;
  final Locale? locale;
  static const headerStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w900,
  );

  const ReaderTextPaginator({
    required this.size,
    required this.style,
    required this.textScaler,
    required this.textDirection,
    this.locale,
  });

  TextPainter _painter(String text, TextStyle style, {int? maxLines}) {
    assert(() {
      debugLayoutCount++;
      return true;
    }());
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: textScaler,
      textDirection: textDirection,
      locale: locale,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '…',
    )..layout(maxWidth: size.width);
  }

  List<TextRange> paginate(String text, {required String title}) {
    final key = (text, title, size, style, textScaler, textDirection, locale);
    final cached = _cache.remove(key);
    if (cached != null) _cachedCharacters -= text.length;
    final pages =
        cached ??
        List<TextRange>.unmodifiable(
          paginateBatches(text, title: title).expand((batch) => batch),
        );
    _cache[key] = pages;
    _cachedCharacters += text.length;
    while (_cache.length > 128 || _cachedCharacters > 1000000) {
      final oldest = _cache.keys.first;
      _cachedCharacters -= oldest.$1.length;
      _cache.remove(oldest);
    }
    return pages;
  }

  Future<List<TextRange>?> paginateAsync(
    String text, {
    required String title,
    required bool Function() cancelled,
  }) async {
    final key = (text, title, size, style, textScaler, textDirection, locale);
    if (_cache.containsKey(key)) {
      return cancelled() ? null : paginate(text, title: title);
    }
    final pages = <TextRange>[];
    final batches = paginateBatches(text, title: title).iterator;
    while (!cancelled()) {
      if (!batches.moveNext()) return List.unmodifiable(pages);
      pages.addAll(batches.current);
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    return null;
  }

  // Keep native paragraph shaping bounded even for a book imported as one chapter.
  Iterable<List<TextRange>> paginateBatches(
    String text, {
    required String title,
  }) sync* {
    if (text.isEmpty) {
      yield const [TextRange(start: 0, end: 0)];
      return;
    }
    final characters = text.characters.iterator;
    var tail = '';
    var base = 0;
    var first = true;
    var exhausted = false;
    while (!exhausted || tail.isNotEmpty) {
      final buffer = StringBuffer(tail);
      while (buffer.length < 4096) {
        if (!characters.moveNext()) {
          exhausted = true;
          break;
        }
        buffer.write(characters.current);
      }
      final window = buffer.toString();
      final ranges = _paginate(window, title: title, includeHeading: first);
      // The final page/line of a window can wrap differently once more text arrives.
      final count = exhausted ? ranges.length : ranges.length - 1;
      if (count == 0) {
        // Extremely large viewports still make bounded forward progress.
        yield [TextRange(start: base, end: base + window.length)];
        base += window.length;
        tail = '';
      } else {
        yield [
          for (final range in ranges.take(count))
            TextRange(start: base + range.start, end: base + range.end),
        ];
        final consumed = ranges[count - 1].end;
        base += consumed;
        tail = window.substring(consumed);
      }
      first = false;
    }
  }

  List<TextRange> _paginate(
    String text, {
    required String title,
    bool includeHeading = true,
  }) {
    if (text.isEmpty) return const [TextRange(start: 0, end: 0)];
    final heading = _painter(title, headerStyle, maxLines: 2);
    final headingHeight = includeHeading ? heading.height + 20 : 0;
    heading.dispose();
    final boundaries = <int>[0];
    for (final character in text.characters) {
      boundaries.add(boundaries.last + character.length);
    }
    int characterStart(int offset) {
      var low = 0;
      var high = boundaries.length - 1;
      while (low < high) {
        final middle = (low + high + 1) ~/ 2;
        if (boundaries[middle] <= offset) {
          low = middle;
        } else {
          high = middle - 1;
        }
      }
      return boundaries[low];
    }

    final painter = _painter(text, style);
    try {
      final lines = painter.computeLineMetrics();
      int lineStart(int index) => index >= lines.length
          ? text.length
          : characterStart(
              painter
                  .getLineBoundary(
                    painter.getPositionForOffset(
                      Offset(
                        0,
                        lines[index].baseline -
                            lines[index].ascent +
                            (lines[index].ascent + lines[index].descent) / 2,
                      ),
                    ),
                  )
                  .start,
            );
      final pages = <TextRange>[];
      var firstLine = 0;
      var start = 0;
      while (firstLine < lines.length && start < text.length) {
        final available = size.height - (pages.isEmpty ? headingHeight : 0) - 1;
        if (pages.isEmpty && available < lines[firstLine].height) {
          pages.add(const TextRange(start: 0, end: 0));
          continue;
        }
        var endLine = firstLine;
        var height = 0.0;
        do {
          height += lines[endLine].height;
          endLine++;
        } while (endLine < lines.length &&
            height + lines[endLine].height <= available);
        var end = lineStart(endLine);
        // Preserve complete graphemes even when a font reports a line break
        // inside a surrogate pair or a joined emoji sequence.
        while (end <= start && endLine < lines.length) {
          end = lineStart(++endLine);
        }
        pages.add(TextRange(start: start, end: end));
        start = end;
        firstLine = endLine;
      }
      return pages;
    } finally {
      painter.dispose();
    }
  }
}
