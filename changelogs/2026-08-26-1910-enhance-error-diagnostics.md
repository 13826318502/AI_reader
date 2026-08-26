# 增强错误定位与阅读器问题诊断

- 日期：2026-08-26 19:10
- Agent：Codex

## 做了什么

- 为错误日志增加启动会话 ID、错误类型和诊断信息，区分当前启动产生的新问题与历史遗留问题。
- FlutterError 记录完整 FlutterErrorDetails，布局溢出即使没有调用栈也会保留诊断上下文。
- 错误日志页增加“仅看本次启动/查看全部历史”切换，并显示历史记录提示，避免把旧版本问题误认为当前问题。
- 错误日志复制和导出内容增加会话、类型和诊断信息，便于 agent 根据错误类别和上下文定位。
- 保留旧日志 JSON 的兼容读取，已有数据不会因新增字段损坏。

## 更改的文件

- lib/core/persistence.dart: AppErrorLog 与 AppErrorLogStore：新增 sessionId、kind、diagnostics 字段及兼容解析。
- lib/core/services/ai_service.dart: FlutterError 处理：记录完整诊断信息。
- lib/features/settings/error_log_page.dart: 增加本次会话过滤和诊断详情展示。
- changelogs/2026-08-26-1910-enhance-error-diagnostics.md: 记录本次修复。

## 验证

- dart format lib：通过。
- flutter analyze --no-pub：无编译错误，仅保留既有 lint/deprecation 提示。
- flutter test --no-pub：全部测试通过。
- flutter build apk --debug：构建成功。
- ADB 复装验证：手机连接在复装阶段断开，未完成本轮真机安装；重新连接设备后应继续验证阅读页、控制栏和错误日志筛选。
