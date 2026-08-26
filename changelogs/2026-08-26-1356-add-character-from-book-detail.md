# 作品详情新增角色功能

- 日期：2026-08-26 13:56
- Agent：Codex

## 做了什么

- 在作品详情的角色区域增加“新增角色”入口。
- 新增角色时仅要求填写姓名并选择图片，图片会复制到应用本地角色图片目录。
- 角色数据按作品保存到本地，作品详情和“全部角色”页面共享已保存角色。
- 新增角色使用默认身份和简介，后续可在角色卡中补充资料；本地图片支持角色卡展示。

## 更改的文件

- `lib/features/works/book_detail.dart:11-48`：加载作品角色、保存新增角色并在详情页展示新增入口和角色卡片。
- `lib/features/characters/character_store.dart:1-155`：新增角色模型、本地持久化、图片复制和新增角色对话框。
- `lib/features/characters/character_pages.dart:84-119`：让全部角色页面按作品读取持久化角色。
- `lib/main.dart:19`：引入角色存储模块。

## 验证

- `dart format lib/features/characters/character_store.dart lib/features/characters/character_pages.dart lib/features/works/book_detail.dart lib/main.dart`
- `flutter analyze --no-pub`：无编译错误，保留项目既有 lint/info 提示。
- `flutter test --no-pub`：通过，`All tests passed!`。
- 手动测试点：作品详情 → 角色 → 新增角色 → 输入姓名 → 选择图片 → 添加；返回详情和全部角色页面确认角色仍存在。
