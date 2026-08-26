# AI 服务配置新增 AK/SK 录入

- 日期：2026-08-26 14:20
- Agent：Codex

## 做了什么

- 在 AI 服务配置页新增 Access Key ID（AK）和 Secret Access Key（SK）输入框。
- 将 AK/SK 接入本地加载、保存、恢复之前配置和控制器释放流程。
- SK 默认隐藏并提供显示切换，同时在页面提示敏感凭据不要分享。
- 未将用户提供的真实凭据写入源码或项目文件。

## 更改的文件

- `lib/features/settings/ai_service_config.dart:12`：新增 AK/SK 控制器、持久化字段与配置输入 UI。
- `lib/features/settings/ai_service_config.dart:188`：保存、恢复 AK/SK 配置。

## 验证

- `dart format lib/features/settings/ai_service_config.dart`
- `flutter analyze --no-pub`：通过；存在项目原有提示信息。
- `flutter test --no-pub`：3 个测试通过，1 个既有阅读器布局测试失败（`lib/shared/reader_widgets.dart:14` 的 RenderFlex 溢出）。
