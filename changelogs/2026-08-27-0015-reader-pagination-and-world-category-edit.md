# 阅读器分页与设定集分类编辑修复

- 日期：2026-08-27 00:15
- Agent：Codex

## 做了什么

- 使用 `TextPainter` 按实际字号、行距、可用宽高测量每页可容纳字符数，减少黄色布局溢出并让正文更充分填充页面。
- 翻页拖动到页边时立即提交当前页并接续下一页，支持一次连续手势跨越多页。
- 设定集中的地域设定、力量体系和时代背景改为点击进入独立分类详情页。
- 分类详情页支持新增多条设定、编辑已有设定，并以 JSON 形式按作品和分类持久化；兼容旧版单条摘要数据。
- 对损坏的分类 JSON 做容错处理，避免打开设定集时再次报错。

## 更改的文件

- `lib/features/reader/reader.dart:74-113`：新增基于 `TextPainter` 的动态分页测量。
- `lib/shared/reader_widgets.dart:190-231`：支持连续拖动跨页和未完成翻页接管。
- `lib/features/worlds/worlds.dart:15-176`：增加分类设定加载、保存及独立编辑入口。
- `lib/features/worlds/worlds.dart:258-435`：新增分类详情编辑页面，支持多条设定维护。

## 验证

- `dart format lib/features/reader/reader.dart lib/shared/reader_widgets.dart lib/features/worlds/worlds.dart`
- `flutter analyze --no-pub`：无编译错误；保留项目既有 lint/info 提示。
- `flutter test --no-pub`：通过。
- `flutter build apk --debug`：通过。
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`：安装成功。
