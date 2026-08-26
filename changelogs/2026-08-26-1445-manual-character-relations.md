# 手动添加角色关系

- 日期：2026-08-26 14:45
- Agent：Codex

## 做了什么

- 将人物关系页从固定空节点改为动态读取当前角色的关系数据。
- 新增“手动添加角色关系”表单，可填写对方角色和关系说明。
- 新增本地关系持久化；重新打开关系页后仍可显示已添加关系。
- 即使当前只有一个角色，关系页也会显示该角色，并提示可继续添加关系。
- 关系节点支持点击切换当前角色，使用现有图片预览组件兼容资源图和本地图片。

## 更改的文件

- `lib/main.dart:36`：追加关系存储和关系表单 part。
- `lib/features/characters/relation_store.dart:3`：新增关系模型与 SharedPreferences 存储。
- `lib/features/characters/relation_form.dart:3`：新增手动添加关系对话框。
- `lib/features/characters/relations.dart:50`：重构关系页为动态单角色/多角色展示，并接入新增关系入口。

## 验证

- `dart format lib/main.dart lib/features/characters/relations.dart lib/features/characters/relation_store.dart lib/features/characters/relation_form.dart`
- `flutter test --no-pub`：8 项测试全部通过。
- `flutter analyze --no-pub`：无本次新增代码 error；仍有项目既有 lint/info 提示及新私有类型公开 API 提示。
- `git diff --check`：通过（仅有项目文件换行格式提示）。
