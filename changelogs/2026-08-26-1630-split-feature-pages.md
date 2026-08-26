# 按功能域拆分 Flutter 页面模块

- 日期：2026-08-26 16:30
- Agent：Codex

## 做了什么

- 将应用壳、书架、作品详情、搜索、阅读器、AI 生图、人物与关系、世界观、图库和设置页面拆到独立文件。
- 将作品模型、阅读器通用组件和 AI 页面子流程分别归档，入口文件仅保留依赖、part 声明和共享状态。
- 保持现有页面类名、持久化键、跨模块调用和业务行为不变。

## 更改的文件

- lib/main.dart:1：精简为模块入口，当前约 39 行。
- lib/app/app_shell.dart:1：应用壳与底部导航。
- lib/features/shelf/shelf.dart:1：书架页面。
- lib/features/works/book_detail.dart:1：作品详情页面。
- lib/features/works/works.dart:1：作品导入与作品列表。
- lib/features/search/search.dart:1：全局搜索。
- lib/features/reader/reader.dart:1：阅读器页面。
- lib/features/ai/ai_image_page.dart:1、ai_gallery.dart:1、ai_generate.dart:1：AI 生图及图库流程。
- lib/features/characters/:1：人物、关系图和人物 AI 页面。
- lib/features/worlds/worlds.dart:1：世界观页面。
- lib/features/gallery/gallery.dart:1：公共图库页面。
- lib/features/settings/:1：我的、错误日志、费用监控、阅读偏好、AI 配置和数据管理。
- lib/core/models/work_models.dart:1：作品与章节模型。
- lib/shared/reader_widgets.dart:1：阅读器通用组件。
- changelogs/2026-08-26-1630-split-feature-pages.md:1：记录本次拆分。

## 验证

- dart format lib：通过。
- flutter analyze --no-pub：无编译错误，仅保留既有 lint/deprecation 提示。
- flutter test --no-pub：全部测试通过。
- flutter build apk --debug：构建成功。
