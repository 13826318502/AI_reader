# 作品导航与页面切换卡顿排查

- 日期：2026-08-26 14:55
- Agent：Codex

## 做了什么

- 只读检查作品点击导航、作品详情加载和底部页面切换逻辑。
- 确认项目代码已按 `lib/app`、`lib/core`、`lib/features`、`lib/shared` 分文件，但多个页面仍然偏大；`main.dart` 本身不是主要性能瓶颈。
- 定位到页面切换时页面子树会被替换，各页面再次触发 SharedPreferences/本地数据加载；书架返回作品详情后还会重复加载两次。
- 定位到作品详情初始状态直接以 `importedWork == null` 显示“作品不存在或已删除”，且最终只接受标题完全相等的查询结果，可能造成点击后看起来无法进入作品页面。

## 更改的文件

- 无代码文件改动；新增本排查记录。

## 验证

- 阅读 `lib/app/app_shell.dart:9-46`、`lib/features/shelf/shelf.dart:20-35`、`lib/features/shelf/shelf.dart:296-303`、`lib/features/works/book_detail.dart:11-35`。
- 统计 `lib` 下 Dart 文件行数，确认最大文件为 `ai_service_config.dart` 653 行、`worlds.dart` 642 行；`main.dart` 仅承担 part 组装。
- 未操作手机、未安装 APK、未修改业务代码。
