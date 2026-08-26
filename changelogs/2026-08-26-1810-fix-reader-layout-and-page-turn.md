# 修复阅读器布局警告与真实翻页效果

- 日期：2026-08-26 18:10
- Agent：Codex

## 做了什么

- 将 Flutter 启动初始化、错误处理和 runApp 放入同一个 runZonedGuarded，消除新启动产生的 Zone mismatch。
- 为阅读器底部控制栏增加最大高度和内部滚动，避免小屏、大字号或控制项展开时 RenderFlex 底部溢出。
- 增加页面边缘轴翻转、阴影和边缘光影，让 PageView 拖动时更接近书页翻动，同时避免整页强透视斜切。
- 保留错误日志历史记录；本次安装后的新启动日志未再出现 Zone mismatch、RenderFlex overflow、组件释放后访问等错误。

## 更改的文件

- lib/core/services/ai_service.dart: main：统一 Flutter 初始化与 runApp 的 zone。
- lib/features/reader/reader.dart: 阅读器控制栏和页面构建：修复布局约束并接入翻页渲染。
- lib/shared/reader_widgets.dart: _BookTurnPage：页面边缘翻转、阴影和边缘渐变。
- changelogs/2026-08-26-1810-fix-reader-layout-and-page-turn.md: 记录本次修复。

## 验证

- dart format lib：通过。
- flutter analyze --no-pub：无编译错误，仅保留既有 lint/deprecation 提示。
- flutter test --no-pub：全部测试通过。
- flutter build apk --debug：构建成功。
- adb install -r build/app/outputs/flutter-apk/app-debug.apk：安装成功。
- 重启应用后抓取 ADB 日志：未出现 Zone mismatch、RenderFlex overflowed、FATAL EXCEPTION 或 Flutter 组件释放错误。
