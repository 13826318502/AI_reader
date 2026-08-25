# 阅读器跨章翻页、章节标题去重、书签常驻与 SnackBar 缩短

- 日期：2026-08-25 17:30
- Agent：opencode

## 做了什么

1. 阅读器支持跨章翻页：将 `PageView` 改为 `PageView.builder`，把全书所有章节按每页 560 字拼成一张全局页表，翻到章节末尾可继续滑到下一章；当前章节/页码由全局页码动态推导，工具栏进度、目录高亮、进度弹窗均改为跟随当前阅读位置。
2. 每章第一页标题去重：删掉第一页上重复的 `第X章` 大字标题，只保留「第X章 · 标题」这一行（若解析出的章节标题已含"第X章"则原样显示，否则自动补全编号），置于第一页左上角。
3. 书签常驻右上角并持久化：书签改为按书存储（`bookmarks_<书名>`），进入阅读页时一次性从本地加载到内存 `Set`；翻到已添加书签的页面时右上角书签徽标立即显示，不再每次翻页异步重读本地存储。
4. 缩短所有操作确认 SnackBar 显示时长至 1.2 秒（原默认约 4 秒 / 书签 2 秒）。
5. 作品详情"继续阅读"改为恢复到上次阅读章节（原来固定从第 1 章开始）。

## 更改的文件

- `lib/main.dart`：
  - `ReaderPage` 状态类整体重构，新增全局分页计算（`_chapterStartPages` / `_locationOf` / `_globalPageOf` / `_initialGlobalPage` / `_persistReadingPosition`）约 1414-2280 行
  - 新增 `_chapterHeaderText` / `_buildChapterHeader` / `_buildDemoPage` / `_buildPage`，移除 `_buildImportedPages` 约 1505-1594 行
  - 书签持久化重构（`_bookmarksKey` / `_loadBookmarks` / `_persistBookmarks`）约 1602-1660 行
  - `build` 改为块体并计算 `readerProgress`，工具栏显示当前章节/总章节与整本进度约 2034-2260 行
  - 全文件约 37 处 SnackBar 增加 `duration: Duration(milliseconds: 1200)`
  - 作品详情"继续阅读"使用 `lastChapter` 约 1197-1209 行

## 验证

- `flutter analyze`：0 error（仅 3 个既有 unused warning + info）
- `flutter test`：All tests passed
- 手动测试点：阅读页跨章滑动；每章第一页仅显示一行「第X章 · 标题」；给某页加书签后翻走再翻回，右上角徽标即时出现；各类操作提示条 1 秒左右自动消失
- 已重新构建并安装到手机（`build/app/outputs/flutter-apk/app-release.apk`）
