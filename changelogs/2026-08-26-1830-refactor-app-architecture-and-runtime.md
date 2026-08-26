# 应用架构与运行负担重构

- 日期：2026-08-26
- 任务：重构项目代码布局并降低手机端运行负担

## 做了什么

- 将应用启动与全局异常捕获从 AI 服务文件移至 `lib/app/app_entry.dart`。
- 将 API 请求日志、AI 图片生成与预览拆分为独立服务模块。
- 将错误日志、阅读偏好、AI 图片文件存储拆分到 `lib/core/storage/`，避免持久化职责集中在单一文件。
- 为导入作品存储复用 `SharedPreferences` 初始化 Future，减少重复的平台通道初始化和等待。
- 保留阅读器并行任务当前未提交的改动，不覆盖其页面逻辑。

## 更改的文件

- `lib/main.dart:16-70`：更新模块 part 声明并接入新的应用入口。
- `lib/app/app_entry.dart:1-45`：新增应用启动与异常捕获模块。
- `lib/core/services/api_request_log_store.dart:1-89`：新增 API 请求日志模型和存储模块。
- `lib/core/services/ai_image_service.dart:1-214`：新增 AI 图片生成与预览模块。
- `lib/core/storage/error_log_store.dart:1-112`：新增错误日志存储模块。
- `lib/core/storage/reading_preferences_store.dart:1-34`：新增阅读偏好存储模块。
- `lib/core/storage/ai_image_storage.dart:1-91`：新增 AI 图片文件存储模块。
- `lib/core/imported_work_store.dart:5-160`：复用偏好存储实例。
- `lib/core/persistence.dart`、`lib/core/services/ai_service.dart`：职责拆分后移除旧聚合文件。

## 验证方式

- `dart format`：通过。
- `flutter analyze`：通过，无 error；项目现有 warning/info 仍有 68 条。
- `flutter test test/billing_controller_test.dart`：6 项通过。
- `flutter test`：现有阅读器/作品详情相关测试有 7 项失败，集中在并行任务未提交的阅读器改动与既有 `widget_test.dart`，本次服务层重构未产生编译错误。
- `flutter build apk --debug`：通过，生成 `build/app/outputs/flutter-apk/app-debug.apk`。
