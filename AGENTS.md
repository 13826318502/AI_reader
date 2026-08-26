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
