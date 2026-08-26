# 增加删除人物关系功能

- 日期：2026-08-26 17:38
- Agent：Codex

## 做了什么

- 在人物关系图顶部菜单增加“删除人物关系”入口。
- 新增关系管理底部面板，列出当前中心人物的全部关系，并为每条关系提供删除按钮。
- 删除前增加确认提示，确认后同时删除当前人物记录和对方保存的反向关系，避免残留连线。
- 支持同一对人物存在多条关系时单独删除其中一条。

## 更改的文件

- `lib/features/characters/relations.dart:134-223`：新增关系管理、确认删除和双向持久化清理逻辑。
- `lib/features/characters/relations.dart:333-340`：增加顶部菜单删除入口。

## 验证

- `dart format lib/features/characters/relations.dart`
- `flutter analyze --no-pub`：无 error；保留项目既有 warning/info。
- `flutter test --no-pub`：37 项测试全部通过。
