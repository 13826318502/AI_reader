import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arc_reader/main.dart';
import 'package:arc_reader/features/reader/reader_pagination.dart';
import 'package:arc_reader/core/services/source_file_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('作品缓存避免重复解析且保存来源时保留正文与封面', () async {
    SharedPreferences.setMockInitialValues({
      'imported_works': [
        jsonEncode({
          'id': 'store',
          'title': '持久化测试',
          'fileName': 'test.txt',
          'cover': 'cover.png',
          'chapters': [
            {'title': '章节', 'content': '需要保留的正文'},
          ],
        }),
      ],
    });
    final first = await ImportedWorkStore.find('持久化测试');
    expect(identical(first, await ImportedWorkStore.find('持久化测试')), isTrue);
    const uri =
        'content://com.android.externalstorage.documents/document/primary%3ADownload%2Ftest.txt';
    await ImportedWorkStore.save(first!.copyWith(sourceUri: uri));
    final saved = await ImportedWorkStore.find('持久化测试');
    expect(saved!.sourceUri, uri);
    expect(saved.cover, 'cover.png');
    expect(saved.chapters.single.content, '需要保留的正文');
    final returned = await ImportedWorkStore.loadAll();
    returned.clear();
    expect(await ImportedWorkStore.find('持久化测试'), isNotNull);
    await ImportedWorkStore.delete('持久化测试');
    expect(await ImportedWorkStore.find('持久化测试'), isNull);
  });

  testWidgets('阅读端显示书架入口', (tester) async {
    await tester.pumpWidget(const ArcReaderApp());
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('我的书架'), findsOneWidget);
  });

  testWidgets('角色详情的大图不撑破横向布局', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: CharacterDetailPage(
          name: '张培斌',
          role: '角色',
          image: 'assets/ai_portrait.png',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final count in [0, 1, 5]) {
    testWidgets('作品详情角色区显示 $count 位角色并可进入全部角色', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'imported_works': [
          jsonEncode({
            'id': 'book',
            'title': '测试作品',
            'fileName': 'test.txt',
            'chapters': [
              {'title': '第一章', 'content': '内容'},
            ],
          }),
        ],
        'characters_测试作品': List.generate(
          count,
          (i) => jsonEncode({
            'id': '$i',
            'name': '角色$i',
            'role': '角色',
            'intro': '角色简介',
            'image': 'assets/ai_portrait.png',
          }),
        ),
      });
      await tester.pumpWidget(
        const MaterialApp(home: BookDetail(title: '测试作品')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('全部角色'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('角色 · $count'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('全部角色'));
      await tester.pumpAndSettle();
      expect(find.byType(CharacterListPage), findsOneWidget);
      if (count == 0) expect(find.text('暂无角色资料'), findsOneWidget);
      if (count > 0) expect(find.text('角色0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('新增角色取消时控制器保持到退场动画结束', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => showAddCharacterDialog(context),
                child: const Text('打开'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '测试角色');
    await tester.tap(find.text('取消'));
    await tester.pump();
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    void listener() {}
    controller.addListener(listener);
    controller.removeListener(listener);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0, 768.0]) {
    testWidgets('角色卡适配宽度 $width 和大字体', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: TextScaler.linear(2),
            ),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CharacterCard(
                    name: '这是一个非常非常长的角色姓名',
                    role: '身份名称也可能很长',
                    intro: '这里是角色简介，简介可能包含多个句子，需要保持卡片尺寸稳定。',
                    image: 'assets/ai_portrait.png',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AiImagePreview)), const Size(72, 96));
    });
  }

  testWidgets('真实分页完整保留正文且每页高度符合约束', (tester) async {
    final text = List.generate(
      40,
      (i) =>
          '第$i段：中文标点，换行。\n\nEnglish words and 👨‍👩‍👧‍👦 emoji. 长段落${'故事' * 70}\n',
    ).join().trim();
    const title = '第一章 很长的标题也要计算高度并限制行数';
    for (final size in [
      const Size(276, 460),
      const Size(316, 700),
      const Size(600, 350),
    ]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        final scaler = TextScaler.linear(scale);
        const style = TextStyle(fontSize: 20, height: 2.05);
        final pages = ReaderTextPaginator(
          size: size,
          style: style,
          textScaler: scaler,
          textDirection: TextDirection.ltr,
        ).paginate(text, title: title);
        expect(pages.map((p) => text.substring(p.start, p.end)).join(), text);
        final header = TextPainter(
          text: const TextSpan(
            text: title,
            style: ReaderTextPaginator.headerStyle,
          ),
          maxLines: 2,
          ellipsis: '…',
          textScaler: scaler,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: size.width);
        for (var i = 0; i < pages.length; i++) {
          final page = pages[i];
          final painter = TextPainter(
            text: TextSpan(
              text: text.substring(page.start, page.end).trimRight(),
              style: style,
            ),
            textScaler: scaler,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: size.width);
          final height =
              (page.isCollapsed ? 0 : painter.height) +
              (i == 0 ? header.height + 20 : 0);
          expect(
            height,
            lessThanOrEqualTo(size.height),
            reason: '$size / $scale / page $i',
          );
          painter.dispose();
        }
        header.dispose();
      }
    }
  });

  testWidgets('超长章节分块排版保留字符且可取消', (tester) async {
    final text = ('中文👨‍👩‍👧‍👦e\u0301连续正文。\n' * 8000).trim();
    const paginator = ReaderTextPaginator(
      size: Size(316, 650),
      style: TextStyle(fontSize: 18, height: 2),
      textScaler: TextScaler.noScaling,
      textDirection: TextDirection.ltr,
    );
    final first = paginator.paginateBatches(text, title: '长篇').first;
    expect(first.last.end, lessThan(5000));
    final pages = paginator.paginate(text, title: '长篇');
    expect(
      pages.map((range) => text.substring(range.start, range.end)).join(),
      text,
    );
    final boundaries = <int>{0};
    var offset = 0;
    for (final character in text.characters) {
      offset += character.length;
      boundaries.add(offset);
    }
    expect(
      pages.every(
        (range) =>
            boundaries.contains(range.start) && boundaries.contains(range.end),
      ),
      isTrue,
    );
    var cancelled = false;
    final pending = paginator.paginateAsync(
      '${text}新内容',
      title: '可取消',
      cancelled: () => cancelled,
    );
    cancelled = true;
    await tester.pump(const Duration(milliseconds: 2));
    expect(await pending, isNull);
  });

  testWidgets('816章作品继续阅读只排当前及邻章，保留深处阅读位置', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'imported_works': [
        jsonEncode({
          'id': 'long-book',
          'title': '长篇性能测试',
          'fileName': 'long.txt',
          'chapters': List.generate(
            816,
            (i) => {
              'title': '第${i + 1}章',
              'content': '章节${i + 1}独有内容。${'长篇正文用于测试。' * 450}',
            },
          ),
        }),
      ],
      'reading_offset_长篇性能测试_401': 1500,
    });
    await SharedPreferences.getInstance();
    await tester.runAsync(() => ImportedWorkStore.loadAll());
    final before = ReaderTextPaginator.debugLayoutCount;
    await tester.pumpWidget(
      const MaterialApp(home: ReaderPage(chapter: 401, bookTitle: '长篇性能测试')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('正在排版本章…'), findsNothing);
    expect(ReaderTextPaginator.debugLayoutCount - before, lessThan(30));
    expect(
      (await SharedPreferences.getInstance()).getInt(
        'reading_offset_长篇性能测试_401',
      ),
      1500,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('跳转尚未排版的旧书签后保存正确章节和页码', (tester) async {
    SharedPreferences.setMockInitialValues({
      'imported_works': [
        jsonEncode({
          'id': 'bookmark-jump',
          'title': '书签跳转测试',
          'fileName': 'test.txt',
          'chapters': List.generate(
            10,
            (i) => {'title': '第${i + 1}章', 'content': '用于书签跳转的连续正文。' * 400},
          ),
        }),
      ],
      'bookmarks_书签跳转测试': ['9:2'],
    });
    await tester.pumpWidget(
      const MaterialApp(home: ReaderPage(chapter: 1, bookTitle: '书签跳转测试')),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 220));
    await tester.pumpAndSettle();
    await tester.tap(find.text('目录'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '第9章'));
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt('reading_chapter_书签跳转测试'), 9);
    expect(preferences.getInt('reading_page_书签跳转测试_9'), 2);
    expect(tester.takeException(), isNull);
  });

  for (final source in [
    '',
    'content://com.android.externalstorage.documents/document/primary%3ADownload%2Ftest.txt',
  ]) {
    testWidgets('本地文件入口${source.isEmpty ? '解释旧记录并关联' : '传递真实来源定位'}', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SourceFileService.channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SourceFileService.channel, null),
      );
      SharedPreferences.setMockInitialValues({
        'imported_works': [
          jsonEncode({
            'id': 'source',
            'title': '文件定位测试',
            'fileName': 'test.txt',
            'sourceUri': source,
            'chapters': [
              {'title': '正文', 'content': '文字'},
            ],
          }),
        ],
      });
      await tester.pumpWidget(
        const MaterialApp(home: BookDetail(title: '文件定位测试')),
      );
      await tester.pumpAndSettle();
      final button = find.text(source.isEmpty ? '关联原文件' : '打开所在文件夹');
      await tester.scrollUntilVisible(
        button,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      if (source.isEmpty) {
        expect(find.text('选择原文件'), findsOneWidget);
        expect(calls, isEmpty);
        await tester.tap(find.text('取消'));
      } else {
        expect(calls.single.method, 'openLocation');
        expect((calls.single.arguments as Map)['uri'], source);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('阅读器处理真实换行和章节标题且切换工具栏无溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'imported_works': [
        jsonEncode({
          'id': 'test',
          'title': '分页测试',
          'fileName': 'test.txt',
          'chapters': [
            {
              'title': '第一章 很长的章节标题也需要占用实际的页面高度',
              'content': List.generate(120, (i) => '第$i行：短段落。\n\n').join(),
            },
          ],
        }),
      ],
    });
    await tester.pumpWidget(
      const MaterialApp(home: ReaderPage(chapter: 1, bookTitle: '分页测试')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(180, 380));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.dragFrom(const Offset(310, 330), const Offset(-280, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final preferences = await SharedPreferences.getInstance();
    final offset = preferences.getInt('reading_offset_分页测试_1');
    expect(offset, greaterThan(0));
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(preferences.getInt('reading_offset_分页测试_1'), offset);
  });
}
