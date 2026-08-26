# Agent 任务变更日志 (Changelogs)

此目录用于记录 Agent 每次完成任务时对项目的更改。

## 规则

- 每个任务完成后，Agent **必须**在此目录新增一个 Markdown 文件（或向现有文件中追加一条记录）。
- 文件名格式：`YYYY-MM-DD-HHMM-简短描述.md`（例如 `2026-08-25-1530-fix-reader-bug.md`）。
- 若同一天/同一任务继续追加内容，可复用同名文件。
- 记录必须简明扼要，覆盖所有实际改动，禁止只写"已完成任务"而无具体内容。

## 记录模板

```markdown
# <任务名称>

- 日期：YYYY-MM-DD HH:MM
- Agent：<agent 名称/ID>

## 做了什么

- <改动点 1 的简要描述>
- <改动点 2 的简要描述>

## 更改的文件

- `path/to/file.dart`：<具体改动说明>
- `path/to/file.yaml`：<具体改动说明>

## 验证

- <如何验证本次改动，例如 flutter analyze / flutter test / 手动测试点>
```

## 现有记录

| 日期 | 任务 | 文件 |
|------|------|------|
| 2026-08-26 | AI 图片、费用监控与错误诊断 | `2026-08-26-1042-image-cost-error-logging.md` |
| 2026-08-26 | 阅读器真实数据链路与界面稳定性补记 | `2026-08-26-1043-backfill-reader-and-layout-fixes.md` |
| 2026-08-26 | 强化新对话的 changelog 规范 | `2026-08-26-1044-strengthen-agent-changelog-rule.md` |
