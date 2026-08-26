part of '../../main.dart';

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});
  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final controller = TextEditingController();
  String query = '';
  List<(String, String, String, int)> results = [];

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final loaded = <(String, String, String, int)>[];
    for (final work in await ImportedWorkStore.loadAll()) {
      for (var i = 0; i < work.chapters.length; i++) {
        final chapter = work.chapters[i];
        final preview = chapter.content.trim();
        if (preview.isEmpty) continue;
        loaded.add((
          work.title,
          '第${i + 1}章 · ${chapter.title}',
          preview.substring(0, preview.length.clamp(0, 120)),
          i + 1,
        ));
      }
    }
    if (mounted) setState(() => results = loaded);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget _highlight(String text) {
    final keyword = query.trim();
    if (keyword.isEmpty) return Text(text);
    final parts = text.split(keyword);
    final spans = <TextSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        spans.add(
          TextSpan(
            text: keyword,
            style: const TextStyle(color: Color(0xFFE69A00)),
          ),
        );
      }
      spans.add(TextSpan(text: parts[i]));
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(color: primaryText, fontSize: 18, height: 1.45),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      toolbarHeight: 86,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, size: 32),
      ),
      leadingWidth: 52,
      titleSpacing: 0,
      title: Row(
        children: [
          Expanded(
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFEADFE1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                onChanged: (v) => setState(() => query = v),
                onSubmitted: (v) => setState(() => query = v.trim()),
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 22),
                decoration: InputDecoration(
                  hintText: '搜索',
                  hintStyle: const TextStyle(fontSize: 22),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search, size: 34),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            controller.clear();
                            setState(() => query = '');
                          },
                          icon: const Icon(Icons.cancel, size: 30),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () => FocusScope.of(context).unfocus(),
            child: const Text(
              '搜索',
              style: TextStyle(color: Color(0xFFE69A00), fontSize: 20),
            ),
          ),
        ],
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        if (query.trim().isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 52),
            child: Center(child: Text('输入关键词搜索作品、章节或正文')),
          )
        else
          ...results
              .where(
                (r) =>
                    r.$1.contains(query) ||
                    r.$2.contains(query) ||
                    r.$3.contains(query),
              )
              .map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReaderPage(chapter: r.$4, bookTitle: r.$1),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _highlight(r.$3),
                          const SizedBox(height: 10),
                          Text(
                            '${r.$1}  ·  ${r.$2}',
                            style: TextStyle(color: mutedText, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ],
    ),
  );
}
