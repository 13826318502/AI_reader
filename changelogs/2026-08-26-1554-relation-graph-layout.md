# 关系图布局与 AI 自动整理

- 日期：2026-08-26 15:54
- Agent：Codex

## 做了什么

- 删除关系图底部重复的“手动添加角色关系”按钮，保留右上角添加入口。
- 将主角固定在关系图中心，其他角色按环形分布，并用连线连接角色。
- 在连线上显示关系名称，右侧显示当前角色头像、名称和关系列表。
- 右上角新增 AI 自动整理关系图布局按钮，读取普通大模型配置并返回角色排序；未配置或请求失败时使用稳定的本地布局。
- 保留普通大模型与生图服务的独立配置和 Key。

## 更改的文件

- `lib/features/characters/relations.dart`：关系图绘制、中心主角、右侧详情、顶部 AI 布局入口。
- `lib/features/characters/relation_layout_service.dart`：调用普通大模型生成角色布局顺序。
- `lib/main.dart`：注册关系布局服务模块。
- `changelogs/2026-08-26-1554-relation-graph-layout.md`

## 验证

- `dart format`：通过。
- `flutter analyze --no-pub`：无 error；保留项目既有 warning/info 和弃用提示。
- `flutter test --no-pub`：37 项全部通过。
- `flutter build apk --debug --no-pub`：构建成功。
- 已安装 `app-debug.apk` 到已连接真机。
