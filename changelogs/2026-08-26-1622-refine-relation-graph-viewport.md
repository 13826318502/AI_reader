# 关系图参考布局与画布窗口优化

- 日期：2026-08-26 16:22
- Agent：Codex

## 做了什么

- 按目标图恢复“左侧人物关系图 + 右侧角色详情卡”的同屏布局。
- 将主角固定为关系网络中心，补齐关系双方节点，连线增加箭头与关系标签底板，减少标签与节点重叠。
- 将关系图改为固定窗口内的大画布：只允许关系图区域拖动、缩放，页面和右侧详情卡保持固定。
- 角色详情卡补充角色身份、简介、性格特征及“生成角色图”入口。
- 修复关系图容器高度为 0 导致真机页面只显示顶部标签的问题。

## 更改的文件

- `lib/features/characters/relations.dart:183`：补齐关系节点、同屏双栏布局及固定画布窗口。
- `lib/features/characters/relations.dart:345`：调整关系图节点尺寸、主角居中和布局顺序。
- `lib/features/characters/relations.dart:443`：绘制关系箭头和带底板的关系文字。
- `lib/features/characters/relations.dart:504`：扩展角色详情卡信息与生图入口。

## 验证

- `dart format lib/features/characters/relations.dart`：通过。
- `flutter analyze --no-pub`：无 error；保留项目既有 warning/info。
- `flutter test --no-pub`：37 项全部通过。
- `flutter build apk --debug --no-pub`：生成并安装 `app-debug.apk`。
- 真机回归：关系图页面可见，主角与关系角色连线及关系文字显示；页面外层不再跟随画布拖动，详情卡保持在右侧。
