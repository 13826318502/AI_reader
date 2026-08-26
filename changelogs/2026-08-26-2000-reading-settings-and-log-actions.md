# 扩展阅读设置与错误日志交互

- 日期：2026-08-26 20:00
- Agent：Codex

## 做了什么

- 增加护眼模式、暖白纸张/豆沙绿/夜间深色主题、拟真书页/平移/无动画翻页模式。
- 增加行距和左右边距调节，所有阅读设置通过 SharedPreferences 持久化，并由阅读器实际读取。
- 阅读页根据主题切换背景和正文颜色，护眼模式使用暖色滤镜，正文排版读取行距和边距设置。
- 错误日志清理改为顶部工具栏删除按钮，并通过确认对话框执行，不再在列表底部固定清理按钮。
- 保留旧版本设置的兼容默认值。

## 更改的文件

- lib/core/persistence.dart: ReadingPreferencesStore：新增护眼、主题、翻页模式、行距和边距配置。
- lib/features/settings/reading_preferences.dart: 增加阅读设置控件及保存逻辑。
- lib/features/reader/reader.dart: 接入主题、护眼、翻页模式、行距和边距。
- lib/shared/reader_widgets.dart: 根据阅读设置动态应用正文边距，并保留拟真翻页渲染。
- lib/features/settings/error_log_page.dart: 清理按钮移动到顶部并增加确认对话框。
- changelogs/2026-08-26-2000-reading-settings-and-log-actions.md: 记录本次优化。

## 验证

- dart format lib：通过。
- flutter analyze --no-pub：无编译错误，仅保留既有 lint/deprecation 提示。
- flutter test --no-pub：全部测试通过。
- flutter build apk --debug：构建成功。
- 手机因 ADB 连接不稳定，本轮未重新安装；设置和翻页需在设备重新连接后进行最终手势验证。
