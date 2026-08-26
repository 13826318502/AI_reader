# 真实阅读设置与书页翻页修复

- 日期：2026-08-26 11:41
- Agent：Codex

## 做了什么

- 修复双页模式仍按单页字数排版造成的底部黄色 `RenderFlex overflow`，窄页模式改为独立分页。
- 将音量键翻页接入 Android 原生按键事件，设置开启后音量上下键会真实切换阅读页。
- 将系统状态栏/沉浸式设置接入 `SystemChrome`，不再只是保存开关值。
- 将横屏双翻页接入实际双页布局；双页模式关闭了不稳定的 3D 旋转，避免出现斜切页面。
- 增加稳定的书页过渡渲染：单页模式使用轻微缩放、页面阴影和边缘渐变，移除会产生斜切错觉的强透视旋转；双页模式使用稳定横向翻页。

## 更改的文件

- `lib/main.dart`：阅读器分页、双页布局、翻页渲染、系统 UI 设置和音量键通道。
- `android/app/src/main/kotlin/com/arcglow/arc_reader/MainActivity.kt`：接收音量键并转发到 Flutter 阅读器。
- `changelogs/2026-08-26-1141-real-page-turn-and-settings.md`：记录本次修复。

## 验证

- `flutter analyze --no-pub`：无编译错误；仅保留项目既有 lint/deprecation 提示。
- `flutter test --no-pub`：全部测试通过。
- `flutter build apk --debug`：构建成功并安装到 `PLS120` 真机。
- 真机进入作品详情和阅读器，检查单页/双页渲染；最新 ADB 日志未出现 `RenderFlex overflow`、`Failed assertion`、`Zone mismatch` 或崩溃。
