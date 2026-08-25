# Desktop Release Source Diagnostics

## 何时读取

完整读取本 reference，不要只摘命令：

- FDE 与 Account readback 有 Release，但桌面 `release_id` 或
  `release_manifest_hash` 为空；
- `bridge.mjs release` / `release-sync` 打印错误 JSON，但 shell exit code 为 0；
- `release-sync` 对不存在、bundled、legacy 或不可见员工显示成功；
- 原始 `/employee-catalog` 有一行员工，但人才市场默认页或某个岗位/场景筛选看不到；
- 用户明确要求检查 YooDesk 电脑端 catalog → Release → 强拉 → 人才市场源码链。

## 证据边界

源码、服务端 Release、Account 响应、安装版 App 和桌面物化是独立证据：

- 源码审查与单元测试不能证明已打包、已安装或当前运行进程已更新；
- FDE Release readback 不能证明 Account 已透传字段，也不能证明桌面已物化；
- `/employee-catalog` 原始响应与 Renderer 筛选后的可见卡片不是同一层；
- 本源码诊断不得自动发布、撤销、访问线上 FDE、读取
  `~/.yoodesk/custom-employees/assets` 或 runtime snapshot；
- 若 Main、IPC、Renderer 或 CLI 源码改变，需要单独重建并验证安装版 App。员工 Release
  热更新不能替代桌面构建。

这里有两个不同的“根”，不得混用：

- **源码命令 cwd** 是 `/Users/admin/crf/bdsh/yoodesk`。从这里读文件或跑测试时使用
  `apps/...`、`packages/...`，**不要再加 `yoodesk/` 前缀**；
- **Git toplevel** 是 `/Users/admin/crf/bdsh`。从 Git 输出看到的路径会带
  `yoodesk/apps/...`，但这不改变源码命令 cwd。

审计前记录以下值，结束时原样重跑并比较 digest 与行数。无需创建临时状态文件：

```bash
git -C /Users/admin/crf/bdsh rev-parse HEAD
git -C /Users/admin/crf/bdsh status --porcelain=v1 |
  LC_ALL=C sort | shasum -a 256
git -C /Users/admin/crf/bdsh status --porcelain=v1 | wc -l

git -C /Users/admin/crf/bdsh/yoodesk_fde rev-parse HEAD
git -C /Users/admin/crf/bdsh/yoodesk_fde status --porcelain=v1 |
  LC_ALL=C sort | shasum -a 256
git -C /Users/admin/crf/bdsh/yoodesk_fde status --porcelain=v1 | wc -l
```

已有 WIP 属于用户；禁止清理、覆盖或把 preexisting dirty 归因于本轮。

## 固定源码链

从 `/Users/admin/crf/bdsh/yoodesk` 开始，按顺序读取；只有证据要求时才扩展：

| 层 | 权威文件 | 必须回答 |
|---|---|---|
| Account client response | `packages/cloud-client/src/types.ts`, `packages/cloud-client/src/account.ts` | catalog 类型和真实解析是否包含两个 Release 字段 |
| Desktop Account session adapter | `apps/desktop/src/main/auth/SessionManager.ts` | `getEmployeeCatalog()` 是否把 Account client response 原样交给 policy |
| Main catalog projection | `apps/desktop/src/main/employee/EmployeePolicyService.ts` | `toItemView` 是否保留字段；未知 policy 值是否 fail-closed |
| Main service pass-through | `apps/desktop/src/main/adapters/employee/EmployeeServiceImpl.ts` | `catalog()` 是否原样返回 policy view，不做第二次投影 |
| IPC handler and output parse | `apps/desktop/src/main/ipc/employee.ts`, `apps/desktop/src/main/ipc/registrar.ts`, `packages/ipc-contract/src/domains/employee.ts` | handler 是否调用同一个 service；registrar 的 Zod output parse 是否声明并保留字段 |
| Main shared-instance wiring | `apps/desktop/src/main/index.ts`, `apps/desktop/src/main/cloud/CloudRuntimeConfig.ts`, `apps/desktop/src/main/bridge/startDebugBridge.ts` | Renderer IPC 与 Debug Bridge 是否收到同一个 `EmployeeServiceImpl`；status 是否拿到启动时真实解析的 server binding |
| Release inspect/sync | `apps/desktop/src/main/employee/CustomEmployeeSyncService.ts` | inspect 与强制动作的语义是否分离；同步前后是否都校验目标 |
| Debug Bridge HTTP/CLI | `apps/desktop/src/main/bridge/DebugBridge.ts`, `apps/desktop/src/main/bridge/DebugBridgeStatus.ts`, `apps/desktop/scripts/bridge.mjs` | HTTP 状态、脱敏 server binding、direct/group 入口、稳定错误码和进程退出码是否一致 |
| Renderer IPC pass-through | `apps/desktop/src/renderer/ipc/client.ts`, `apps/desktop/src/renderer/app-api/index.ts` | Renderer 是否原样取得 `employee:catalog` output |
| Renderer discoverability | `apps/desktop/src/renderer/pages/MarketPage.tsx` | 默认全部、岗位 chip、scenario 各自怎样过滤 category |

Debug Bridge `/employee-catalog` 与 Renderer IPC 都必须调用上述同一个
`EmployeeServiceImpl.catalog()`；不要另猜一个不存在的 `EmployeeService.ts`。只有确实需要解释
definition → Persona category 转换时，再读
`apps/desktop/src/renderer/data/runtimeEmployees.ts`。不要从仓库根目录盲扫、寻找服务器代码、
安装包、ASAR 或本地资产缓存。

报告增加 `sourceMapMisses`：列出为证明本审计结论而读取、但没有出现在上表或允许的
`runtimeEmployees.ts` 扩展中的**产品源码**。测试文件、changelog 和 Skill 文件不计。
若非空，说明 canonical map 仍不完整；解释为什么需要该文件并先修 reference，再用新会话复核。
不得一边声称“固定地图完整”，一边把必要的额外源码搜索藏起来。

## 字段不变量

`release_id` 和 `release_manifest_hash` 必须从 cloud-client 响应进入
`EmployeePolicyService` catalog view，再通过 IPC schema 到
Debug Bridge `/employee-catalog`。当前 custom Release 应输出字符串或 `null`；IPC 字段保持
optional 只为兼容旧缓存快照。字段是诊断身份，不是新的授权依据。

验证必须断言解析后的输出仍含字段。仅断言 Zod “接受”带额外字段的对象不够，因为未声明字段
可能被静默剥除。字符串在进入桌面 view 时去除首尾空白；空字符串归一为 `null`。

未知 `availability` 或无效的 employee/current/required plan level 不能回退成可聘用。
行可保留用于诊断，显示层级可兼容回落 L0，但最终 availability 必须 fail-closed 为
`disabled`。

## inspect 与强制同步语义

`inspectRelease` 是只读诊断。目标不存在或不是 custom 时，它可返回 HTTP 200 fingerprint，
例如 `remote=null` 或 `matchBasis=not_custom`；这只证明检查完成，不代表同步成功。

`ensureReleaseCurrent` / `POST /employees/release/sync` 是明确动作，必须 fail-closed：

| 目标状态 | 稳定错误码 | HTTP |
|---|---|---|
| catalog 不存在该行 | `release_not_found` | 404 |
| 行存在但 `source !== custom` | `release_not_custom` | 409 |
| custom 但不可见 | `release_not_visible` | 409 |
| 强拉后仍不一致 | `release_mismatch` | 409 |
| 下载、验签或物化失败 | `release_refresh_failed` | 503 |

同步前和同步后都必须重新校验目标，防止物化期间 catalog 改变后误报
`synchronized=true`。这些动作错误与后台缺席宽限/GC 是两套语义；不要为修动作结果而缩短
GC 宽限。

## CLI 退出码不变量

`apps/desktop/scripts/bridge.mjs` 的每个 HTTP 命令都是可脚本化接口：

- 2xx 保留正常输出并 exit 0；
- 任意非 2xx 保留服务端错误正文并 exit non-zero；
- 网络/解析异常同样必须 non-zero；
- `release` 与 `release-sync` 不能因“打印了 JSON”就被当成成功；
- 此规则也覆盖 `status`、`open-direct`、`send-direct`、`create-group`、
  `send`、`catalog` 等其他 HTTP 子命令。

发布后做真实员工调用时，先用 `status` 确认正在运行的 App 绑定和协议版本，
再用 `open-direct` / `send-direct` 进入真实单聊；不要用一人群模拟单聊。
`health` 只能证明旧探针可达，不能证明 status 或 direct 能力已安装。

## 人才市场 unknown category 判定

先比较原始 `/employee-catalog`，再比较人才市场：

- “全部岗位”且无 scenario 时，未知 category 可保留；
- 用户选择已有岗位 chip 或 scenario 后，严格白名单会过滤未知 category；
- 这能解释“全部能看到，某个筛选看不到”，不能解释原始 catalog 整行消失；
- 不要把 `utility` 等未知值武断归入“运营”，也不要通过重新发布 Release、改 entitlement
  或清缓存解决 Renderer 可发现性；
- 若产品需要“其他岗位”入口，这是单独的 Renderer UI/交互变更，必须按桌面 UI 变更流程
  获得明确授权、补视觉/交互验证和 UI changelog。

## 症状判定表

| 现象 | 层次 | 行动 |
|---|---|---|
| FDE 正确，Account JSON 缺字段 | Account 运行版映射/部署漂移 | 修 Account；do not republish |
| Account JSON 有字段，桌面 catalog 丢失 | Policy 或 IPC 投影 | 修源码、契约和测试；do not republish |
| `release` 收到非 2xx 但 exit 0 | CLI | 修共享 HTTP exit invariant |
| `release` 返回 `remote=null` | 只读诊断完成 | 不得称为同步成功 |
| `release-sync` 目标 missing/non-custom | 动作无法完成 | HTTP/CLI fail-closed |
| `health` 成功但 `status`/`open-direct` 404 | 安装版 Bridge 协议旧 | 重建/安装，不用一人群绕过 |
| 原始 catalog 有 `utility`，岗位筛选没有 | Renderer 筛选 | 不重发、不改 entitlement |
| 源码测试通过，安装版行为仍旧 | package/install/runtime 证据缺失 | 重建后另做安装版验证 |

## 聚焦验证

不扩大到全仓。每条相对路径命令都显式锚定 YooDesk 源码根目录；不要依赖上一条 shell
或包管理命令留下的工作目录，也不要因为一次路径猜错而改用全仓盲扫：

```bash
cd /Users/admin/crf/bdsh/yoodesk && pnpm --dir apps/desktop exec vitest run \
  tests/unit/EmployeePolicyService.test.ts \
  tests/unit/CustomEmployeeSyncService.test.ts \
  tests/unit/DebugBridge.test.ts \
  tests/unit/ipc-employee.test.ts \
  tests/unit/MarketPage.test.tsx

cd /Users/admin/crf/bdsh/yoodesk && \
  pnpm --dir packages/cloud-client exec vitest run tests/account.test.ts
cd /Users/admin/crf/bdsh/yoodesk && \
  pnpm --dir packages/ipc-contract exec vitest run tests/contract.test.ts \
  -t 'employee catalog output preserves|contract schemas — employee:catalog'

cd /Users/admin/crf/bdsh/yoodesk && pnpm --dir apps/desktop typecheck
cd /Users/admin/crf/bdsh/yoodesk && pnpm --dir packages/cloud-client typecheck
cd /Users/admin/crf/bdsh/yoodesk && pnpm --dir packages/ipc-contract typecheck
cd /Users/admin/crf/bdsh/yoodesk && node --check apps/desktop/scripts/bridge.mjs
```

测试后再次记录 `git status --porcelain=v1`，区分 `preexisting_dirty` 与
`new_changes_by_this_run`。

## 独立复核报告一致性硬门

引导式和自主 OpenCode 复核都使用同一份结构化结论。不要只让模型复述源码；报告必须满足
以下可机械检查的语义：

- 每条 finding 都带 `can_remove_entire_catalog_row`。只有 Account 响应、Main catalog
  投影或 IPC `/employee-catalog` 本身有证据删除/剥除整行时才可为 `true`；
- Release inspect/sync 状态、CLI exit code 和 Renderer category 筛选均不能把原始 catalog
  整行删除，因此对应 finding 必须为 `false`；
- `summary.can_explain_raw_catalog_row_absence` 必须等于 findings 中
  `can_remove_entire_catalog_row=true` 的逻辑“或”。当所有 finding 都为 `false` 时，
  summary **必须是 `false`**，不得因“已经解释了 unknown category”而反写成 `true`；
- `source_has_problem=false` 只表示这次审查的源码和聚焦测试没有发现缺陷，不能清空
  `remaining_uncertainty`，也不能升级成服务器、安装版 App 或物化成功；
- 若 OpenCode 的模型供应商在完成工具调用后没有输出最终 JSON，记录为
  `report_incomplete`。保留会话和工具证据，结束无进展等待，并使用**全新会话**重跑；不得把
  半份输出拼成通过结论。

最终 JSON 至少包含 `round_id`、`mode`、`loadedSkillPath`、`referenceRead`、每条命令的
`exitCode`、guardrail 计数、findings、`preexisting_dirty`、
`new_changes_by_this_run`、`sourceMapMisses` 和上述两个 summary 布尔值。输出前先逐条执行
这个一致性检查。

两个仓库身份必须分开，不得在一个含糊的 `repository.branch` 中混写。使用下面的固定形状；
`source` 的 branch 来自 `/Users/admin/crf/bdsh`，`skill` 的 branch 来自
`/Users/admin/crf/bdsh/yoodesk_fde`：

```json
{
  "repository": {
    "source": {
      "cwd": "/Users/admin/crf/bdsh/yoodesk",
      "gitToplevel": "/Users/admin/crf/bdsh",
      "head": "",
      "branch": "",
      "statusBefore": {"digest": "", "count": 0},
      "statusAfter": {"digest": "", "count": 0}
    },
    "skill": {
      "root": "/Users/admin/crf/bdsh/yoodesk_fde",
      "head": "",
      "branch": "",
      "statusBefore": {"digest": "", "count": 0},
      "statusAfter": {"digest": "", "count": 0}
    }
  },
  "sourceMapMisses": [],
  "sourceMapOptionalReads": []
}
```

即使没有按需扩展，也必须输出空的 `sourceMapOptionalReads`；读取
`runtimeEmployees.ts` 时必须把其绝对路径放进该数组。禁止把 FDE `preview` 分支写到
source repository，也禁止把 bdsh `main` 分支写到 Skill repository。

## OpenCode 独立复核门

OpenCode 必须加载 canonical Skill，不得把 `.codex` / `.claude` discovery loader
当完整规则。每次 Skill 或源码变化后使用全新会话：

```bash
cd /Users/admin/crf/bdsh/yoodesk_fde
FDE_CANONICAL_SKILL="$(pwd)/skill-is-all-you-need/skills/fde-publishing"
FDE_OPENCODE_CONFIG="$(
  jq -cn --arg skillPath "$FDE_CANONICAL_SKILL" '{
    skills: {paths: [$skillPath]},
    permission: {
      edit: "deny",
      bash: "allow",
      external_directory: "allow"
    },
    tool_output: {
      max_lines: 100000,
      max_bytes: 50000000
    }
  }'
)"

OPENCODE_DISABLE_EXTERNAL_SKILLS=1 \
OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1 \
OPENCODE_CONFIG_CONTENT="$FDE_OPENCODE_CONFIG" \
opencode debug skill |
jq -e '
  .[] |
  select(
    .name == "fde-publishing" and
    .location ==
      "/Users/admin/crf/bdsh/yoodesk_fde/skill-is-all-you-need/skills/fde-publishing/SKILL.md"
  )
'
```

引导式复核可给出上面的源码地图。自主复核只给自然语言症状，让 OpenCode 通过 Skill 找到
reference、源码链和测试。两种模式都必须只读并报告：

- `loadedSkillPath` 和 `referenceRead`；
- 每条命令及 `exitCode`；
- 带文件/行号的 `findings`；
- `changedFiles`，并证明没有把已有 WIP 算作本轮写入。
- `sourceMapMisses`；完整地图验收时必须为空，允许的
  `runtimeEmployees.ts` 按需扩展单独列为 `sourceMapOptionalReads`；两个 key 即使为空也
  不得省略。
- `summary.can_explain_raw_catalog_row_absence` 与每条
  `can_remove_entire_catalog_row` 严格满足上面的逻辑“或”不变量。

从 OpenCode 日志或导出会话核对真实 Skill/tool 调用；模型文字声称“已加载/已执行”不是证据。
