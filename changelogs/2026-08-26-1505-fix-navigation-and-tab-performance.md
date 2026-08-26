# 修复作品导航与页面切换卡顿

- 日期：2026-08-26 15:05
- Agent：Codex

## 做了什么

- 底部页面改为按需创建并使用 `IndexedStack` 保留已打开页面状态，避免每次切换重复初始化和读取本地数据。
- 删除书架打开作品返回后的重复刷新调用。
- 作品详情增加加载中状态，避免异步查询完成前误显示“作品不存在或已删除”。
- 作品查询对标题去除首尾空格后再匹配，并行加载作品、角色和阅读进度数据。

## 更改的文件

- `lib/app/app_shell.dart:11-74`：新增按需页面缓存和状态保活。
- `lib/features/shelf/shelf.dart:296-302`：移除重复的书架数据刷新。
- `lib/core/models/work_models.dart:98-103`：规范化作品标题匹配。
- `lib/features/works/book_detail.dart:15-39`：增加加载状态并并行读取详情数据。

## 验证

- `dart format lib/app/app_shell.dart lib/features/shelf/shelf.dart lib/core/models/work_models.dart lib/features/works/book_detail.dart`
- `flutter test --no-pub`：11 项测试全部通过。
- `flutter analyze --no-pub`：无新增 error；保留项目既有 lint/info 提示。
- `git diff --check`：通过（仅有项目文件换行格式提示）。
