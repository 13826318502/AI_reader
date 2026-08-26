# AGENTS.md — Agent 工作规范

## 任务完成后的必做项：更新 changelog

### 新对话启动检查

新对话进入本项目后，开始任何代码检查、修改、构建或提交前，必须先阅读：

1. `AGENTS.md`
2. `changelogs/README.md`
3. `changelogs/` 中最近一条记录

如果本次任务涉及代码或项目文件，结束前必须新增或追加 changelog；没有 changelog 不得宣称任务完成。

每次 Agent 完成一个任务后，**必须**在 `changelogs/` 目录中记录本次任务的更改：

1. 新增一个文件，命名格式：`changelogs/YYYY-MM-DD-HHMM-简短描述.md`（例如 `changelogs/2026-08-25-1530-fix-reader-bug.md`）。
2. 按照 `changelogs/README.md` 中的模板填写：
   - 任务名称与日期
   - 做了什么（具体改动点）
   - 更改的文件列表（`file_path:line` 便于定位）
   - 验证方式（如 `flutter analyze`、`flutter test`、手动测试点）
3. 如果本次任务是纯研究/咨询、未改动任何代码，也要记录，写明"无代码改动"及结论。

## 提交 git 前：先查看最近生成的 changelog

在向 GitHub 仓库提交（commit/push）之前，Agent **必须**先阅读 `changelogs/` 目录中最近生成的一条 changelog：

1. 用 `Get-ChildItem changelogs -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 5` 找出最近的文件，读取内容。
2. 确认本次任务的改动已记录在其中（记录要与实际 diff 一致）。
3. 参考最近 changelog 的风格与内容，编写与之一致的 commit message。
4. 若本次改动尚未记录，先在 `changelogs/` 补上记录，再提交。

## 通用规范

- 遵循项目现有代码风格与既有库/工具，不引入未使用的依赖。
- 除用户明确要求外，不提交 git。
- 不添加无关注释。

## 模块化开发规范（必须遵守）

- 不得把新的页面、业务流程、数据模型、网络请求或持久化逻辑继续堆入 `lib/main.dart`。
- 新代码必须按职责放入对应目录：`lib/app`、`lib/core`、`lib/features`、`lib/shared`；目录不存在时先创建。
- 一个文件只负责一个清晰的模块；页面、状态管理、数据模型、服务和通用组件应分离。
- 修改旧代码时，若发现文件已经承担多个职责，应优先拆分后再实现新功能；不要为了省事继续扩大单文件。
- 页面文件建议控制在约 500 行以内；超过后必须按组件、状态逻辑或子流程继续拆分，并在 changelog 中说明拆分边界。
- 每次任务开始先盘点现有模块和依赖关系，每完成一个拆分阶段就运行 `dart format`、`flutter analyze` 和相关测试。
- 新对话必须把本节作为执行提示词：任何功能实现、修复或 UI 调整都要先考虑模块归属、复用边界、单一职责和后续可维护性。
