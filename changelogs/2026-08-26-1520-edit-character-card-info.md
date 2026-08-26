# 角色卡资料手动编辑

- 日期：2026-08-26 15:20
- Agent：Codex

## 做了什么

- 扩展角色模型，新增外貌特征、性格特点、人物背景、目标与动机、首次出场字段，并兼容旧角色 JSON。
- 新增独立角色卡编辑页，支持编辑姓名、角色定位、简介、图片和全部详细资料。
- 保存时按角色 ID 更新对应作品的本地角色列表；没有作品上下文时也能在当前角色卡页面即时更新。
- 从角色列表、作品详情角色区和角色详情页传递作品标题与角色 ID，确保已有角色修改后可以持久化。
- 角色卡增加详细资料展示区，未填写时提示进入编辑。

## 更改的文件

- `lib/features/characters/character_model.dart:3`：扩展 `_WorkCharacter` 字段和 JSON 兼容读写。
- `lib/features/characters/character_editor.dart:3`：新增角色卡编辑页面。
- `lib/features/characters/character_card_page.dart:3`：增加编辑入口和详细资料展示。
- `lib/features/characters/character_detail_page.dart:3`：接入编辑入口并显示已填写简介。
- `lib/features/characters/character_card.dart:3`：向详情页传递作品、角色和详细资料信息。
- `lib/features/characters/character_pages.dart:38`：从角色列表传递可持久化上下文。
- `lib/features/works/book_characters_section.dart:56`：从作品详情角色区传递可持久化上下文。
- `lib/main.dart:23`：追加角色编辑器 part。

## 验证

- `dart format`：相关 8 个 Dart 文件格式化完成。
- `flutter test --no-pub`：11 项测试全部通过。
- `flutter analyze --no-pub`：角色代码无新增编译错误；当前仍被并行任务中的 `lib/features/billing/volcengine_signer.dart` 缺少 `crypto` 依赖阻断，并保留项目既有 lint/info 提示。
