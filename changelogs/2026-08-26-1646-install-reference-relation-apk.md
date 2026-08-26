# 安装参考关系图版本 APK

- 日期：2026-08-26 16:46
- Agent：Codex

## 做了什么

- 构建包含最新人物关系图复刻改动的 Debug APK。
- 覆盖安装到已连接的 Android 真机，保留原应用数据。
- 启动 `com.arcglow.arc_reader` 并确认主 Activity 已获得焦点。

## 更改的文件

- 无源代码改动。
- `build/app/outputs/flutter-apk/app-debug.apk`：本次安装的构建产物。

## 验证

- `flutter build apk --debug`：构建成功。
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`：Success。
- `adb shell dumpsys window`：确认 `com.arcglow.arc_reader/.MainActivity` 已启动。
