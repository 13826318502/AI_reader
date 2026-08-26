# 作品详情角色卡横向排列

- 日期：2026-08-26 15:35
- Agent：Codex

## 做了什么

- 将作品详情页角色区从纵向/多行 `Wrap` 改为横向可滑动列表。
- 每张角色卡使用固定宽度横向排列，角色较多时可左右滑动查看；保留新增角色和全部角色入口。

## 更改的文件

- `lib/features/works/book_characters_section.dart:53`：使用横向 `ListView.separated` 展示角色卡。

## 验证

- `dart format lib/features/works/book_characters_section.dart`
- `flutter test --no-pub`：31 项测试全部通过。
- `git diff --check`：通过（仅有项目文件换行格式提示）。
