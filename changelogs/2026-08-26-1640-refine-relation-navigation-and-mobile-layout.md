# 关系图导航与真机布局优化

- 日期：2026-08-26 16:40
- Agent：Codex

## 做了什么

- 将关系图中的“世界百科”标签改为跳转到“设定集”页面，不再只是返回上一页。
- 根据真机当前页面的深色星空风格，将关系图区域调整为手机宽度全屏展示，下方显示角色介绍面板。
- 点击任意人物头像后，将该人物设置为关系图中心，并同步更新下方的头像、姓名、角色定位、简介、关系和性格信息。

## 更改的文件

- `lib/features/characters/relations.dart:260`：接入世界百科到设定集的跳转。
- `lib/features/characters/relations.dart:292-329`：调整为全宽关系图和下方详情面板。
- `lib/features/characters/relations.dart:311`：点击节点后以当前选中人物为中心重新布局。

## 验证

- 已读取真机截图 `review/phone_current.png`，依据深色星空背景、全屏关系图和底部介绍面板调整布局。
- `dart format lib/features/characters/relations.dart`
- `flutter test --no-pub`：37 项测试全部通过。
- `git diff --check`：通过（仅有项目文件换行格式提示）。
- 未点击、输入或安装操作，仅读取真机截图用于布局参考。
