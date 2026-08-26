# 按真机参考复刻人物关系图

- 日期：2026-08-26 16:39
- Agent：Codex

## 做了什么

- 在连接的真机上查看起点读书的“冉青墨-角色关系”页面，并点击“许元”确认切换中心人物后的布局状态。
- 将项目关系图改为整屏深色星空/地球感画布、中心人物大头像、环形关系节点、金色连线与底部人物介绍栏。
- 点击任意人物后继续以该人物为中心重排关系图，标题和底部介绍同步更新。
- 将世界百科、角色卡、添加关系和 AI 排布入口收进顶部菜单，保留原有功能并减少参考页面中的额外面板。

## 更改的文件

- `lib/features/characters/relations.dart:219-317`：调整顶部栏、整屏关系画布和底部人物信息布局。
- `lib/features/characters/relations.dart:319-355`：新增深色星空/轨道背景绘制器。
- `lib/features/characters/relations.dart:357-445`：调整关系节点环形排布和中心人物尺寸。
- `lib/features/characters/relations.dart:520-584`：将人物介绍改为参考页面的居中底部信息栏。
- `lib/features/characters/relations.dart:629-690`：调整头像、半透明姓名条和中心头像尺寸。

## 验证

- 真机只进行了页面浏览、截图和点击“许元”查看中心人物切换，未安装 APK、未写入用户数据。
- `dart format lib/features/characters/relations.dart`
- `flutter analyze --no-pub`：通过，无 error；保留项目既有 warning/info。
- `flutter test --no-pub`：37 项测试全部通过。
- `git diff --check`：通过（仅报告项目既有换行格式提示）。
