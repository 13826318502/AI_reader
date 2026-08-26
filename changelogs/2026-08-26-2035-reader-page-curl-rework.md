# 阅读器拟真翻页与设置生效修复

- 日期：2026-08-26
- Agent：Codex

## 做了什么

- 参考 `turnable_page`、`cosmos_epub` 等开源 Flutter 阅读器的页面翻转结构，将原来依附 `PageView` 的轻量旋转替换为独立的书页翻转视口。
- 翻页时先显示目标页作为底页，当前页根据手指拖动进度绕左/右书脊旋转至 90 度，并加入纸页阴影、页边高光和透视效果。
- 修复目录、书签、图片页跳转与新翻页视口之间的控制链路。
- 从阅读器进入设置并返回后，重新读取字体、主题、护眼、行距、边距和翻页模式，使设置立即作用于当前阅读器。

## 更改文件

- `lib/shared/reader_widgets.dart`：新增独立的 `_BookReaderViewport` 和拖拽/动画翻页逻辑。
- `lib/features/reader/reader.dart`：接入翻页视口，替换旧 `PageView` 翻页实现，并补充设置返回后的重新加载。

## 验证

- `dart format lib/shared/reader_widgets.dart lib/features/reader/reader.dart`
- `flutter analyze --no-pub`：无编译错误；保留项目原有 lint/info 提示。
- `flutter test --no-pub`：通过。
- `flutter build apk --debug`：通过。
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`：成功安装并启动。
