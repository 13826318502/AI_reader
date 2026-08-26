# Flutter 项目核心模块重构

- 日期：2026-08-26 15:45
- Agent：Codex

## 做了什么

- 将主题颜色与主题偏好存储从入口文件抽离。
- 将错误日志、阅读偏好、AI 图片文件存储和作品基础持久化能力抽离到核心模块。
- 将 AI 请求日志、图片生成服务和图片预览组件抽离到独立服务模块。
- 保留原有持久化键、页面类名、AI 请求链路和应用入口行为，使用 Dart part 保持跨页面私有类型兼容。

## 更改的文件

- lib/main.dart:1：保留依赖、模块声明和应用壳，移除核心基础设施实现。
- lib/core/theme.dart:1：主题状态、颜色和主题偏好。
- lib/core/persistence.dart:1：错误日志、阅读偏好、AI 图片存储和作品基础存储。
- lib/core/services/ai_service.dart:1：AI 请求日志、图片生成服务和图片预览。
- changelogs/2026-08-26-1545-refactor-core-modules.md:1：记录本次重构。

## 验证

- dart format lib：通过。
- flutter analyze --no-pub：无编译错误，仅保留既有 lint/deprecation 提示。
- flutter test --no-pub：全部测试通过。
- flutter build apk --debug：构建成功。
