# 改进复杂人物关系图自动布局

日期：2026-08-26

## 做了什么

- 将关系图从固定两层圆环改为可扩展的多层环形布局。
- 每层最多放置 6 个角色，关系数量增加时自动扩展画布，避免角色集中在中心区域。
- AI 返回的角色顺序现在会真正参与节点分层和槽位排列。
- 保留 InteractiveViewer 的缩放和拖动能力，用于查看大规模关系图。
- 保留同一对角色的多条关系，并继续对关系线、箭头和关系标签进行分组偏移。

## 更改文件

- `lib/features/characters/relations.dart:460-595`：关系图画布、节点位置和多环布局算法。

## 验证方式

- `flutter analyze lib/features/characters/relations.dart`：无 error。
- `flutter test`：37 项全部通过。
- `flutter build apk --debug`：构建成功。
- APK 已安装到连接的 Android 手机，启动 Activity 验证成功。
