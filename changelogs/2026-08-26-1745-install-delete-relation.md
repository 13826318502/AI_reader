# 安装删除人物关系版本 APK

- 日期：2026-08-26 17:45
- Agent：Codex

## 做了什么

- 构建包含删除人物关系功能的 Debug APK。
- 覆盖安装到已连接 Android 真机，保留应用数据。
- 启动 `com.arcglow.arc_reader` 并确认 MainActivity 已获得焦点。

## 更改的文件

- 无源代码改动。
- `build/app/outputs/flutter-apk/app-debug.apk`：本次安装的构建产物。

## 验证

- `flutter build apk --debug`：构建成功。
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`：Success。
- `adb shell dumpsys window`：确认 `com.arcglow.arc_reader/.MainActivity` 已启动。
