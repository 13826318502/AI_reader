# 关系图画布与错误日志回归

- 日期：2026-08-26 16:01
- Agent：Codex

## 做了什么

- 删除关系图底部重复的手动添加按钮，保留右上角添加关系入口。
- 将关系图改为可拖动、可缩放的独立画布，主角固定在中心，其他角色环绕布局。
- 使用真实节点位置绘制角色连线，并在连线中点标注双方关系。
- 将角色详情从右侧移到关系图画布下方中间区域。
- 保留右上角 AI 自动整理关系图布局入口。
- 检查 APP 错误日志，确认历史记录主要来自旧图片路径加载和旧控制器退场；当前版本启动回归未出现新的 FlutterError、FATAL EXCEPTION 或 RenderFlex overflow。

## 更改的文件

- `lib/features/characters/relations.dart`：关系画布、缩放拖动、节点连线、关系标注和详情位置。
- `changelogs/2026-08-26-1601-relation-canvas-pan-zoom.md`

## 验证

- `dart format lib/features/characters/relations.dart`：通过。
- `flutter analyze --no-pub`：无 error；保留项目既有 warning/info 和弃用提示。
- `flutter test --no-pub`：37 项全部通过。
- `flutter build apk --debug --no-pub`：构建成功。
- 已安装 `app-debug.apk` 到已连接真机并启动检查，未发现新的崩溃或黄色布局错误。
