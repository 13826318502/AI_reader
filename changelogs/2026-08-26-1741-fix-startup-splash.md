# 修复 APP 启动停留在 Flutter 启动画面

日期：2026-08-26

## 做了什么

- 修复启动流程在 `SharedPreferences` 和系统初始化完成前不调用 `runApp` 的问题。
- 将 APP 壳层首帧提前渲染，主题偏好读取改为后台执行，避免本地数据量较大或平台通道延迟时卡住启动画面。
- 修正测试数据生成器的 `getStringList` 编码：使用项目实际的“固定前缀 + JSON 数组”格式，恢复作品、角色和关系数据的正常读取。
- 修正章节切分逻辑，仙侠测试作品现在显示 6 章。

## 更改文件

- `lib/core/services/ai_service.dart:259-290`：启动流程调整。
- `review/SeedPrefs.java:12-37`：SharedPreferences 字符串列表编码修正。
- `review/prepare_xianxia_seed.ps1:66-67`：章节切分修正。

## 验证方式

- `flutter analyze`：无 error。
- `flutter test`：37 项全部通过。
- 构建并安装 debug APK 成功。
- ADB 重启验证：APP 正常进入书架，测试作品显示封面和 6 章，不再停留在 Flutter 启动画面。
