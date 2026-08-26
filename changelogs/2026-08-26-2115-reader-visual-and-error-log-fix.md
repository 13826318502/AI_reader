# 阅读器质感与错误日志修复

- 日期：2026-08-26 21:15
- Agent：Codex

## 做了什么

- 根据已连接设备上的实际阅读体验，修复正文页因固定字数分页和系统文字缩放导致的底部溢出。
- 按设备可用宽高、字号、行距和文字缩放动态计算每页容量，并保留安全边距，确保正文超出界面时进入下一页。
- 增强左右翻页的拟真效果：加入纸张底色、背面渐变、折页高光、书脊阴影，并结合滑动速度判断翻页意图。
- 修复错误日志在“仅看本次启动”且无记录时仍显示列表的问题；日志读取过滤空记录，日志写入失败不会反向触发运行时错误。

## 更改的文件

- `lib/features/reader/reader.dart:63-96`：新增基于设备布局和文字缩放的动态分页容量计算。
- `lib/shared/reader_widgets.dart:150-298`：增强书页翻转动效、纸张层次和滑动速度判定。
- `lib/core/persistence.dart:67-108`：增强错误日志存取容错并避免日志系统递归报错。
- `lib/features/settings/error_log_page.dart:105-173`：修正错误日志筛选后的空状态展示。

## 验证

- `dart format lib/features/reader/reader.dart lib/shared/reader_widgets.dart lib/core/persistence.dart lib/features/settings/error_log_page.dart`
- `flutter analyze --no-pub`：无编译错误；保留项目既有 lint/info 提示。
- `flutter test --no-pub`：通过。
- `flutter build apk --debug`：通过并成功安装到已连接 Android 设备。
- 真机手动验证：进入作品详情和正文阅读页，正文无底部溢出；左右滑动可翻页；隐藏控制栏后保持沉浸式阅读；本项目日志未出现崩溃堆栈。
