# 阅读器局部刷新与纸张质感优化

- 日期：2026-08-26 22:00
- Agent：Codex

## 做了什么

- 参考手机专业阅读器的翻页中间态，将底页和当前页分别按翻页方向裁切，避免前后两页文字整页叠加。
- 为当前页和目标页增加独立 `RepaintBoundary` 与稳定 key，翻页拖动时只重绘折页区域，不让整个阅读页面跟随刷新。
- 增加低对比度纸张纤维纹理和暖白渐变，改善静止页与折页背面的纸张质感。
- 保持动态分页安全余量，避免增加视觉层后重新出现底部溢出。

## 更改的文件

- `lib/shared/reader_widgets.dart:64-345`：新增纸张纹理绘制、局部裁切器和页面缓存边界；调整前后页局部重绘结构。
- `lib/features/reader/reader.dart:63-96`：保留动态分页容量与安全余量逻辑。

## 验证

- `dart format lib/shared/reader_widgets.dart lib/features/reader/reader.dart`
- `flutter analyze --no-pub`：无编译错误；保留项目既有 lint/info 提示。
- `flutter test --no-pub`：通过。
- `flutter build apk --debug`：通过。
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`：安装成功。
