# 增加普通大模型配置入口

- 日期：2026-08-26 15:38
- Agent：Codex

## 做了什么

- 在“我的 · AI 服务配置”新增“普通大模型服务”区域。
- 新增普通模型 API Base URL 和普通模型名称输入框，用于人物关系自动布局、设定整理等文本任务。
- 普通大模型与生图服务共用已保存的 API Key，配置分别保存为 `ai_text_base_url` 和 `ai_text_model`，不影响已有生图配置。
- 保存、恢复配置时同步处理普通大模型配置。
- 增加 OpenAI 兼容接口提示，并说明未配置时关系图使用本地稳定布局。

## 更改的文件

- `lib/features/settings/ai_service_config.dart`：普通大模型配置字段、持久化和恢复逻辑。
- `lib/features/characters/relation_layout_service.dart`：读取普通大模型配置并请求关系布局建议的服务。
- `lib/main.dart`：注册关系布局服务 part。
- `changelogs/2026-08-26-1538-add-text-model-config.md`

## 验证

- `dart format`：通过。
- `flutter analyze --no-pub`：无 error；保留项目既有 warning/info 和弃用提示。
- `flutter test --no-pub`：37 项全部通过。
- 已确认配置字段使用独立键保存，不覆盖当前生图模型、Base URL 或 API Key。
