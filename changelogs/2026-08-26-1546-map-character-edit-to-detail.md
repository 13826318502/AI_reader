# 编辑角色卡映射到角色详情

- 日期：2026-08-26 15:46
- Agent：Codex

## 做了什么

- 将角色详情页改为有状态页面，编辑角色卡返回后立即刷新当前详情内容。
- 按编辑页字段拆分详情模块：角色简介、外貌特征、性格特点、人物背景、目标与动机、首次出场。
- 空字段使用统一占位文案，已有角色资料不会因字段为空导致布局缺失。

## 更改的文件

- `lib/features/characters/character_detail_page.dart`：接收编辑结果并按字段分模块展示。
- `changelogs/2026-08-26-1546-map-character-edit-to-detail.md`

## 验证

- `dart format`：通过。
- `flutter test --no-pub`：37 项全部通过。
- `flutter build apk --debug --no-pub`：构建成功。
- 已安装 `app-debug.apk` 到已连接真机，安装成功。
