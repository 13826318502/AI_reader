# 安装关系图箭头修复版本 APK

- 日期：2026-08-26 17:01
- Agent：Codex

## 做了什么

- 构建包含关系图节点间距、箭头和关系标签修复的 Debug APK。
- 使用覆盖安装方式安装到已连接 Android 真机，保留应用数据。
- 启动 `com.arcglow.arc_reader` 并确认 MainActivity 已启动。

## 更改的文件

- 无源代码改动。
- `build/app/outputs/flutter-apk/app-debug.apk`：本次安装的构建产物。

## 验证

- `flutter build apk --debug`：构建成功。
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`：Success。
- `adb shell dumpsys window`：确认 `com.arcglow.arc_reader/.MainActivity` 已启动。
