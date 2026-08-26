# 普通大模型使用独立 API Key

- 日期：2026-08-26 15:42
- Agent：Codex

## 做了什么

- 在 AI 服务配置中为普通大模型增加独立 API Key 输入框。
- 普通大模型使用 `ai_text_api_key`，生图继续使用 `ai_api_key`，两者可分别配置且互不覆盖。
- 保存、恢复和页面重新打开时同步读取普通模型 Key，并沿用隐藏/显示控制。
- 人物关系自动布局服务改为优先使用普通大模型 Key。

## 更改的文件

- `lib/features/settings/ai_service_config.dart`：普通模型 Key 的输入、保存、恢复和销毁。
- `lib/features/characters/relation_layout_service.dart`：读取普通模型独立 Key。
- `changelogs/2026-08-26-1542-separate-text-api-key.md`

## 验证

- `dart format`：通过。
- `flutter analyze --no-pub`：无 error；保留项目既有 warning/info 和弃用提示。
- `flutter test --no-pub`：37 项全部通过。
- `flutter build apk --debug --no-pub`：构建成功。
- 已安装 `app-debug.apk` 到已连接真机，安装成功。
