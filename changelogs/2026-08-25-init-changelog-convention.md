# 创建 Agent 任务 changelog 规范

- 日期：2026-08-25
- Agent：opencode

## 做了什么

- 新建 `changelogs/` 目录，用于存放 Agent 每次任务对项目的更改记录。
- 在 `changelogs/README.md` 中定义记录规则与模板（文件名格式 `YYYY-MM-DD-HHMM-简短描述.md`、模板字段、现有记录索引）。
- 新建 `AGENTS.md`，把"任务完成后必须更新 changelog"写进 Agent 工作规范，使后续 Agent 自动遵守。
- 在 `AGENTS.md` 新增"提交 git 前先查看最近 changelog"规范：Agent 在 commit/push 前必须读取最近生成的 changelog，确认改动已记录、diff 一致，并参考其风格编写 commit message。

## 更改的文件

- `changelogs/README.md`：记录规则与模板。
- `AGENTS.md`：Agent 工作规范，新增 changelog 必做项及提交前查看最近 changelog 的规范。

## 验证

- 手动检查 `changelogs/` 目录存在、模板文件可读、`AGENTS.md` 内容完整。
