# 安装当前 APK

日期：2026-08-26

## 做了什么

- 将 `build/app/outputs/flutter-apk/app-debug.apk` 安装到已连接的 Android 手机。
- 安装后启动 APP，确认 `com.arcglow.arc_reader/.MainActivity` 正常运行。

## 验证方式

- `adb install -r`：安装成功。
- `adb shell monkey -p com.arcglow.arc_reader 1`：启动成功。
