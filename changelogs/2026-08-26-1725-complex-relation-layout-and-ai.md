# 修复复杂人物关系图与 AI 排布并安装

- 日期：2026-08-26 17:25
- Agent：Codex

## 做了什么

- 同一对人物之间允许同时显示多条关系，关系线按平行偏移绘制，每条线保留独立箭头和关系文字。
- 复杂关系图改为中心节点加多环分层布局，超过 6 个旁支人物时自动分到内外两层，降低节点重叠。
- 修复新增关系的反向关系去重条件，只有人物和关系都相同才视为重复，避免第二条不同关系被吞掉。
- 修复 AI 排布使用初始人物而不是当前中心人物的问题。
- AI 接口无配置、返回格式异常或请求失败时，改用按关系数量排序的本地智能布局，不再表现为点击无效；远程返回支持文本数组格式。
- 构建并覆盖安装到已连接 Android 真机，保留应用数据。

## 更改的文件

- `lib/features/characters/relations.dart:103-174`：修复反向关系保存和当前中心人物的 AI 排布。
- `lib/features/characters/relations.dart:405-442`：增加复杂关系的多环布局。
- `lib/features/characters/relations.dart:464-548`：按人物对分组绘制多条平行关系线、箭头和标签。
- `lib/features/characters/relation_store.dart:68-76`：保留同一人物对之间的不同关系。
- `lib/features/characters/relation_layout_service.dart:3-136`：增加本地智能排序和远程响应容错。
- `build/app/outputs/flutter-apk/app-debug.apk`：安装构建产物。

## 验证

- 使用真机页面 `review/phone_relation_current.png` 检查单条关系布局问题。
- `dart format lib/features/characters/relations.dart lib/features/characters/relation_layout_service.dart`
- `flutter analyze --no-pub`：无 error；保留项目既有 warning/info。
- `flutter test --no-pub`：37 项测试全部通过。
- `flutter build apk --debug`：构建成功。
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`：Success。
- `adb shell dumpsys window`：确认 `com.arcglow.arc_reader/.MainActivity` 已启动。
