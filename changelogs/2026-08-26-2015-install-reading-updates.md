# 2026-08-26 安装阅读设置与错误诊断更新

## 变更内容

- 完成阅读偏好持久化：护眼模式、主题样式、翻页模式、行距和左右边距。
- 阅读器根据偏好应用主题、护眼滤镜、正文间距和翻页方式。
- 优化拟真翻页的静止状态，避免页面边缘在翻页结束后露出异常斜边。
- 错误日志增加当前会话筛选、诊断详情和顶部清理入口。
- 构建并安装 Android debug APK，验证应用包可正常安装和启动。

## 验证

- `dart format lib`
- `flutter analyze --no-pub`
- `flutter test --no-pub`
- `flutter build apk --debug`
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`

## 更改文件

- `lib/core/persistence.dart`
- `lib/features/reader/reader.dart`
- `lib/features/settings/error_log_page.dart`
- `lib/features/settings/reading_preferences.dart`
- `lib/shared/reader_widgets.dart`
- `changelogs/2026-08-26-2000-reading-settings-and-log-actions.md`

## 备注

- `review/` 下的临时截图仅用于排查布局问题，不提交到仓库。
