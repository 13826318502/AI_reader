# 修复人物关系图连线与关系标签

- 日期：2026-08-26 16:54
- Agent：Codex

## 做了什么

- 缩小非中心人物节点并增大环形排布半径，避免头像互相遮挡。
- 将连线起点和终点从头像中心调整到头像边缘，恢复可见的金色箭头。
- 提高连线和关系文字的对比度，并将关系标签放在线段中部偏移位置，避免被头像覆盖。

## 更改的文件

- `lib/features/characters/relations.dart:405-445`：调整节点间距和节点定位。
- `lib/features/characters/relations.dart:467-524`：调整连线边缘裁切、箭头绘制和关系标签样式。
- `lib/features/characters/relations.dart:650-690`：缩小旁支头像，保留中心头像突出显示。

## 验证

- `dart format lib/features/characters/relations.dart`
- `flutter analyze --no-pub`：无 error；保留项目既有 warning/info。
- `flutter test --no-pub`：37 项测试全部通过。
