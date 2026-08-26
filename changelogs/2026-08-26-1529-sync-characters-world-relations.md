# 同步角色设定与人物关系图

- 日期：2026-08-26 15:29
- Agent：Codex

## 做了什么

- 修复设定集角色页始终显示空占位的问题，改为读取当前作品角色库并展示角色卡。
- 在设定集角色页增加“角色卡片”入口，支持进入全部角色及角色详情。
- 添加人物关系时优先从当前作品已有角色中选择对方，并自动使用对方头像。
- 保存人物关系时同时写入正向和反向关系，确保关系图重新进入、切换节点后仍能显示关系。
- 保留地域设定、力量体系、时代背景三个独立详情页，每类均支持标题和内容新增/编辑。

## 更改的文件

- `lib/features/worlds/worlds.dart`：同步当前作品角色库并补充角色卡片入口。
- `lib/features/characters/relation_form.dart`：增加当前作品角色选择和头像映射。
- `lib/features/characters/relations.dart`：保存关系时同步双方关系记录。
- `lib/features/characters/character_card_page.dart`：传递作品信息到关系图。
- `lib/features/characters/character_detail_page.dart`：传递作品信息到关系图。
- `changelogs/2026-08-26-1529-sync-characters-world-relations.md`

## 验证

- `dart format`：通过。
- `flutter analyze --no-pub`：无 error；仅保留项目既有 warning/info 及弃用提示。
- `flutter test --no-pub`：37 项全部通过。
- `flutter build apk --debug --no-pub`：构建成功。
- 已安装 `app-debug.apk` 到已连接真机，启动后未发现新的 `FATAL EXCEPTION`、`RenderFlex overflow` 或 Flutter 错误日志。
- 真机检查设定集作品入口、地域设定详情和 AI 图片集合；新增角色同步逻辑及关系图代码已通过编译和测试验证。
