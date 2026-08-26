# 关系图中心角色连线过滤

- 日期：2026-08-26 16:35
- Agent：Codex

## 做了什么

- 关系图节点改为围绕当前选中的角色生成，选中角色始终作为中心节点。
- 关系图仅展示当前中心角色的直接关系，隐藏其他角色之间的旁支关系。
- 所有关系箭头统一从中心角色指向关联角色，避免出现反向或互相交叉的混乱箭头。
- AI 自动整理布局只整理当前中心角色及其关联角色，不再把整部作品的无关角色混入布局。

## 更改的文件

- `lib/features/characters/relations.dart:235`：AI 布局输入改为当前中心角色的关系子图。
- `lib/features/characters/relations.dart:270`：节点集合改为当前选中角色及直接关联角色。
- `lib/features/characters/relations.dart:409`：关系画布只接收中心角色关系。
- `lib/features/characters/relations.dart:581`：连线绘制统一以中心角色为起点并绘制方向箭头。

## 验证

- `dart format lib/features/characters/relations.dart`：通过。
- `flutter analyze --no-pub`：无 error；保留项目既有 warning/info。
- `flutter test --no-pub`：37 项全部通过。
- `flutter build apk --debug --no-pub`：构建成功。
- 尝试安装真机 APK 时设备已断开，未完成本轮真机安装。
