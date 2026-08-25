---
name: fde-publishing
description: >-
  Create, publish, update, remove, revoke, unlist, or diagnose YooDesk
  account-scoped cloud custom employees and signed FDE releases. Use for 创建、
  发布、更新、删除、撤销或下架员工、员工名称重名、修改完整员工闭包、明确替换
  active release 中已有 data/recipe/template 文档资产、cloud_only 与 bdsh_path
  校验、签名或权限被拒、客户没收到新版、签发前目标机尚未物化当前 Release、跨机器迁移/
  换机后原机能用但目标机报 `persona profile not installed`、definition-invalid、Release ID/Manifest
  为空、版本/运行时漂移、38/101 桌面包目标错位、release-sync 假成功、Bridge exit code
  错误、Runtime Module 脚本与 npm/npx 大依赖的 CAS 增量分层、员工绑定 App 内置
  `lu_tts`、语音合成/TTS 工具缺失或发布后不能生成声音、Account catalog 有员工但桌面人才市场没有、
  FDE MCP 登录失败或新员工 id 发不上去。The Flutter phone client, phone runtime-policy workflow, and
  mobile/USB Debug Bridge are retired; stop instead of recreating or routing to
  those surfaces. Do not use this Skill to design or diagnose Task
  Center schema/queue/progress or GET /tasks/batches; use trace-mjs-task-center,
  then return here only to deliver the reviewed employee closure.
---

# FDE 发布与运维

## 无上下文 Agent 强制启动序列

本节专门约束 OpenCode、小模型和任何从空工作目录启动、没有本仓库 `AGENTS.md` 上下文的
Agent。不得因为最终结论碰巧正确而跳过这些步骤：

1. 先用 Skill 工具加载本 canonical `fde-publishing`，记录工具事件给出的 `SKILL.md` 真实路径。
   `.codex/skills` 和 `.claude/skills` 都只是 loader，不得作为完整规则源。
2. 从 canonical `SKILL.md` 所在目录向上三级得到 `yoodesk_fde` 根目录；不要从当前工作目录猜路径。
   用 `read` 工具完整读取该根目录的 `AGENTS.md` 和 `FDE_PUBLISH_GUIDE.md`，再读取本 Skill 的
   [employee-crud-runbook.md](references/employee-crud-runbook.md)。只有真实、成功的
   `read` 工具事件算完成，模型文字声称“已读”不算证据。任一文件无法读取时停止，不选择命令，不退回旧文档、
   记忆或 loader。
   真实发布或撤销前还必须从这个根目录运行
   `python3 tools/fde_workflow_identity.py --require-asset-gitlink`，并保留
   `repository_commit`、`canonical_skill_sha256`、`contract_bundle_sha256`、
   `tool_bundle_sha256`、`asset_gitlink`、`asset_commit` 与 `asset_gitlink_matches=true`。
   OpenCode 必须通过 `tools/opencode_fde.sh` 启动；该 launcher 会把同一版本元组绑定到子进程，
   CLI 在读取凭据前拒绝另一个 checkout、会话期间被修改的 canonical Skill/引用/权威文档/工具，
   或与父仓 gitlink 不同的资产 HEAD。
3. 再按下面四项做最小分流，不要先拼命令：

   | 对象 | 唯一入口 | Git/源码边界 |
   |---|---|---|
   | 普通 FDE 用户创建或修改自己的完整员工包 | `tools/publish_user_employee.py --package-dir` | 本地普通目录；不读取、不写入 GitHub，不暴露 manifest/asset-root/maintainer 参数 |
   | 内部第一方/受审员工完整闭包 | `tools/publish_from_manifest.py` | 以 `yoodesk-dzhyg` manifest 为权威源；选中任一 `bdsh_path` 时仅 maintainer/CI 可传 `--maintainer-bdsh-root` |
   | active Release 中一个既有 data/recipe/template 文档 | `tools/revise_data_asset.py` | 只上传新文档字节；不得下载旧 Release 源码 |
   | 一个精确账号下架 release-backed 员工 | `tools/revoke_release.py` | 先 dry-run，再用确认的 release ID 乐观锁执行 |

   选中内部 Manifest 发布线后，必须继续完整读取
   [internal-manifest-test-release-sop.md](references/internal-manifest-test-release-sop.md)，先填写其中的
   非敏感发布单，再运行命令。该发布线固定为 `direct_signed_release`，不把审批文件或编辑席位
   当作失败后的替代路线。
4. 任何真实写入前逐项确认：员工/包身份、该发布线精确要求的治理权限、显式受审 HTTPS endpoint、
   FDE operator 用户名与可用密码载体、dry-run/名称预检结果和用户对真实写入的授权。内部 Manifest
   直发不要求编辑席位或审批 application；工作台 `approval_required` 发布才要求当前编辑者与已批准
   application。用户在当前
   精确任务中直接交给 Agent 的 FDE operator 账号/密码，或用户明确指定的 owner-only 凭据文件，
   都是允许的凭据来源；不得仅因凭据来自聊天或文件而要求用户换成手工登录。缺少任何一项才
   返回 `blocked` 以及缺失项；不得选择或猜测目标账号、使用 `*`、猜凭据或把“命令已选对”写成“已经发布”。
5. 分开报告四层证据：服务端 immutable Release/readback、桌面物化、全新会话 tools catalog、
   一次真实可调用工具结果。前一层成功不能替代后一层。

发布或验收明确涉及另一台电脑、换机、重装或“原机能用但目标机不能用”时，必须完整读取
[pre-sign-cross-machine-materialization-gate.md](references/pre-sign-cross-machine-materialization-gate.md)。
在调用任何会生成设备签名的完整发布命令前，先让目标机的当前 active Release 通过基线物化门；
目标机证据不能由签发机、原机或同版本 App 的成功结果代替。

新员工 ID 绑定 `meituan-review-web-automation*` 受保护 owner MCP 时，必须完整读取
[owner-mcp-runtime-trust.md](references/owner-mcp-runtime-trust.md)。不得向 Desktop 源码白名单追加新 ID，
也不得重新要求已退役的回评专用 capabilities、发布者角色或证书角色。发布器必须在凭据、签名和上传前
验证 `employee.yaml.mcp` 与签名 `mcp_yaml.id` 的唯一精确绑定；签名证书使用标准 `asset_signer`，
并由 v2 资产签名、employee/module scope 与 resolver-authored owner/Release provenance 共同授权。

无上下文只读验收默认禁止 shell、登录、发布和文件修改；它验证 Agent 能加载规则、读取权威文档、
选择正确入口并在硬门处停止。只有用户给出精确目标并明确授权真实发布后，才进入本 Skill 后续写入
步骤。调用方要求机器可验收 JSON 时，输出的第一个字符必须是 `{`、最后一个字符必须是 `}`；
不得添加 Markdown 代码围栏、前后说明或把候选值原样抄回。

## 权威源与漂移硬门

先读仓库根目录的 [AGENTS.md](../../../AGENTS.md) 中 `FDE Publish` 段和
[FDE_PUBLISH_GUIDE.md](../../../FDE_PUBLISH_GUIDE.md)。命令示例再以
[FDE_USAGE_EXAMPLES.md](../../../FDE_USAGE_EXAMPLES.md) 为准。若本 Skill 与它们或实际工具
参数冲突，停止并修订 Skill；不得挑选更宽松的旧规则继续操作。

创建、查询、修改、删除/下架员工时还必须读
[employee-crud-runbook.md](references/employee-crud-runbook.md)。它给出 source mutation map、
业务语义 WIP 合并、三位当前员工的真实修改模式和 asset `crf` → FDE gitlink `preview` 顺序；
具体三员工路径以 submodule 的 `EMPLOYEE_ASSET_INVENTORY.md` 为准，完整闭包仍由当前 manifest
计算，不能把清单当第二份 manifest。

### Agent 执行版本元组

canonical Skill、实际执行的发布/撤销 CLI 与内部资产 submodule 必须属于同一个
`yoodesk.fde/workflow-identity/v1` 元组。不得从 A checkout 加载 Skill，却因为示例、旧会话或
`.env` 所在位置而调用 B checkout 的工具。凭据文件可以位于仓库外或另一个 owner 管理目录；
它的位置不改变工具身份。

```bash
python3 tools/fde_workflow_identity.py --require-asset-gitlink
tools/opencode_fde.sh run --model minimax-cn-coding-plan/MiniMax-M3 "<task>"
```

`opencode_fde.sh` 固定仓库根、HEAD、canonical Skill SHA-256、完整契约 bundle SHA-256、
发布工具 bundle SHA-256 与提交的资产 gitlink。受审 CLI
在账号解析、登录、设备证书、签名或服务端写入之前重算并核对；不一致时只能返回
`FDE workflow identity rejected`，要求结束当前 Agent 会话、对齐 checkout/submodule 后从
全新会话重试。不得取消环境变量、改用绝对旧工具路径或复制 Skill 来绕过。用户本地包没有
资产 gitlink，但仍必须与同一 Skill/CLI 根绑定；内部 manifest lane 还要求实际
`yoodesk-dzhyg` HEAD 等于父仓 gitlink。

当前契约必须同时满足：

- 远程 FDE 端点只接受受审 HTTPS。`publish_from_manifest.py` 仅额外接受精确
  loopback HTTP 作为本地隧道入口；任何远程明文 HTTP 都没有同意旗标或生产例外。
- 用户自有员工的创建和完整闭包更新统一走 `publish_user_employee.py --package-dir`；该入口不暴露
  manifest、资产仓库或 maintainer 参数，也不写 GitHub。内部第一方/受审员工仍走
  `publish_from_manifest.py`。两者最终都生成同一种服务器托管的不可变 FDE v2 Release。
  旧的免源码脚本和逐项调用底层库投递 partial release 均为退役路径。
- 用户指定员工模型时，把公开 Gateway model id 写入权威 `employee.yaml` 的 `model.default`，并让
  发布命令传同值 `--model` 做精确断言。该参数不覆盖源码；未声明模型时保留桌面默认。员工
  Release 不得携带 provider URL、API key 或服务端路由。
- 创建、修改或排查该模型绑定时，完整读取
  [model-routing-contract.md](references/model-routing-contract.md)，先确认目标环境实际挂载 public id，
  再进入 Release 发布；不能用路由配置文件存在替代生效的 `/v1/models` 证据。
- 创建、修改或排查员工的语音合成能力时，完整读取
  [tts-tool-contract.md](references/tts-tool-contract.md)。FDE Release 只在权威
  `employee.yaml` 的 `mcp` 列表绑定 App 内置 `lu_tts`，不得把 MCP 实现、供应商地址、API key、
  临时下载地址或网关配置打进员工闭包。发布后必须用全新会话完成预览、明确确认和非空音频文件验收；
  不能用 Release/物化成功替代真实生成。
  `revise_data_asset.py` 是唯一受限例外：它只替换 active release 中一个既有
  `data`/`recipe`/`template` 文档资产，并通过 hash-only broker 原子生成完整派生 release；
  它不是第二条完整源码发布线。
- `revoke_release.py` 是 release-backed 员工账号级下架的受审 operator CLI。它通过
  `remove_custom_employee` 原子撤销可见性和挂载，不投递 partial release，也不删除不可变历史。
- FDE 工作台发布是员工级动作：生成并切换该员工唯一的正式版本，不存在“发布到哪个账户”。
  当前唯一 `edit` 席位可以提交和履约发布；协作成员按成员关系查看版本历史。所有有效正式使用
  授权自动跟随员工当前版本，新增其他账户使用权应调用 `grant_employee_use`，不得借发布扩大范围。
- 工作台发布账户只取当前 FDE 身份在服务端登记的唯一 YooDesk 绑定，工作台不得提供
  目标账户选择器。审批制受信代理只把登录返回的 canonical `account_id` 作为一致性锚点，
  不得接受邮箱候选、任意 UUID 或 `*` 来扩大正式使用范围。
- 低层 Release 协议中的 `account_id` 仅是不可变源码 Release 的内部归属锚点，不是工作台目标
  选择器，也不是当前编辑者必须持有的生产发布 grant。受信代理只能使用准备单冻结的锚点；不得
  接受操作者选择邮箱、任意 UUID 或 `*`。
- 内部第一方 manifest 使用 `direct_signed_release`。服务端在首个签名 Release 激活事务中自动创建
  缺失的员工项目；首次和后续直发都不要求 FDE Console 编辑席位。既有
  `approval_required` 项目不能被 manifest 直发抢占或覆盖，仍必须走当前编辑者与批准申请链。
  自动初始化不替代登录账号范围、标准 `asset_signer`、设备证书、完整 Release 验签和激活后
  entitlement/mount readback。`get_release_state.catalog_ready` 还必须为 `true`，证明项目、owner
  deployment、员工成员、代理商绑定、正式 Version 与 entitlement 已形成 Account catalog 可见闭包；
  只有 active Release 或 enabled entitlement 时不得报告成功。
- `validate_manifest.py --strict --employee-id <id>` 只校验所选闭包。全部条目
  `cloud_only: true` 且没有 `bdsh_path` 时允许 `compared 0 file mirrors`；只要出现一个
  `bdsh_path`，才转入内部 maintainer/CI 镜像线并要求 `--maintainer-bdsh-root`。

### 凭据规则按工作流区分

同一个 FDE 账号可用于不同受权工具，但密码承载规则由**工作流**决定，不由账号邮箱决定：

- 对用户自有员工发布、内部完整发布、source-free 文档修订和账号级撤销，用户可以在当前精确任务中把专用
  FDE operator 账号/密码直接交给 Agent。Agent 可以在有 PTY 时输入非回显
  `getpass`；没有可写 stdin 时，可以把本轮密码写入仓库外、预先创建为 `0600` 的任务文件，
  并用显式 `--fde-user ... --fde-password-file <path>` 让受审客户端直接读取。该文件只能包含一行
  密码，必须由当前用户拥有、不是软链接且没有 group/world 权限；任务结束即删除，除非用户明确
  要求保留为 owner 管理的 credential store。允许取得凭据不等于允许回显或扩大用途，且不得承诺
  聊天/工具基础设施零留存。
- owner 预先创建的 `0600` `.env` 仍可通过 `--env-file` 读取；受保护 CI 仍可使用成对的
  `FDE_MCP_USER`/`FDE_MCP_PASSWORD` 进程变量。进程变量只用于受控非交互 CI，不把聊天密码搬入
  环境变量。若用户给出既有 password-only 文件，优先把路径交给 `--fde-password-file`，不要先
  `cat`、`source`、打印或复制内容。不得仅因 Agent 已经拿到密码而再要求 owner 重输或重复确认。
- 任何密码都不得进入 argv、日志、员工资产、测试或 Git；`--fde-password-file` 传的是路径，
  不是密码本身。

### 真发凭据零号闸门

拼真实发布命令前，必须先用非敏感文字明确列出：`release_lane`、`publication_mode`、
`employee_id`、`environment`、`fde_url`、`account_anchor`、`fde_operator`、
`credential_carrier`、`approval_application`、`edit_seat` 和 `mirror_mode`。其中：

- `--account` / `account_anchor` 是 Release 的账号归属锚点，不是 FDE 登录账号，也不会因为 YooDesk
  账户已绑定企业就自动产生 FDE operator 密码；
- 真发必须有 FDE operator 用户名和 `interactive | password_file | owner_env | protected_ci` 之一；
  dry-run 不登录，不能证明密码存在或正确；
- `credential_carrier=missing` 时，在登录、签名、上传前停止，明确索要**目标 endpoint 的 FDE
  operator 凭据**。不得试用 YooDesk App 密码、目标客户密码、SSH 密码或服务器密码；
- 非交互 Agent 没有可写 PTY 且没有可用密码文件/owner env 时，不得启动真发后等待 `getpass`
  失败。应直接报告 `missing FDE operator password` 和允许的安全载体；
- `invalid credentials` 表示 FDE 登录身份不存在、密码错误或已停用。停止猜密码和重试，让管理员
  验证/重置该环境的 FDE operator；不能归因于员工资产签名。

内部 Manifest 测试发布的完整零号闸门、207/38/101 endpoint、命令和分层报告模板见
[internal-manifest-test-release-sop.md](references/internal-manifest-test-release-sop.md)。

## 共享触发词路由

| 用户实际目标 | 主 Skill | `Debug Bridge` / “发布”的含义 |
|---|---|---|
| 定义/排查任务中心 batch、队列、页数、进度、产物、`GET /tasks/batches` 或 8782 任务接口 | `$trace-mjs-task-center` | 桌面 Debug Bridge 读取 Task Center 投影；它不发布员工 |
| 创建/升级/撤销 cloud custom employee、签名 Release、物化与 release-sync | `$fde-publishing` | “发布”指账号范围 immutable employee Release；桌面 Bridge 只做发布后读回 |

“新建一个员工，并让它在任务中心显示逐项进度”必须组合执行：先用
`$trace-mjs-task-center`（浏览器员工还先用 `$author-fde-browser-mjs`）设计并验证生产者、
schema 和完整资产闭包，再切回 `$fde-publishing` 做名称预检、签名、激活与物化验证。
任一 Skill 都不得假装另一阶段已经完成。

## 版本与运行时漂移闭环

当症状是“源码/Release 已更新但员工仍跑旧代码”、38/101 包或后端可能混用、materialized
runtime 与 active Release 不一致、旧 sidecar/tool schema 或 batch `runtime-snapshot` 仍生效时，
必须完整读取
[runtime-release-drift-diagnostics.md](references/runtime-release-drift-diagnostics.md)。先建立
权威 source → 可选 bdsh mirror → 指定环境/active signed Release → 安装版构建与运行身份 →
桌面物化 → 新 sidecar tools snapshot → batch frozen snapshot 的分层账本，再决定是发布、重包、
强制同步、新会话还是新批次。

使用该 reference 的只读 inspector 定位 `firstDivergence`。本地员工/资产仍存在不能证明当前
包连接了目标服务器；远端、Account、update feed 或 FDE CA 身份与用户指定环境不一致时
fail-closed。镜像只允许由 `yoodesk-dzhyg` 权威源定向同步到 manifest 声明的 `bdsh_path`，禁止
反向覆盖或宽范围同步用户 WIP。历史 batch 与当前 Release hash 不同是预期冻结身份，不得手改；
新版验收必须使用物化后的新会话、新 sidecar 和新 batch。

发布前后还必须比较上一版与本版的 delivery closure。若上一版 active Release 含
`runtime_modules`（桌面为 `runtime_plan_v2` / `hybrid`），而本版回到纯
`assets_v1`，这是**运行时退役迁移**，不能把 `assetsSynced=true` 当成完成。安装版必须具备
“提交新签名资产后退役旧 active runtime pointer、保留既有 lease”的 Main 修复；否则停止安装版
放行并转交 bdsh 主程序重建。`bridge.mjs release <employee-id>` 必须证明没有旧 runtime
integrity/active pointer 不匹配；随后用全新 conversation/runtime session 核对实际 tools catalog：
新资产 MCP 必须存在，已从 manifest 删除的 typed CLI/local MCP 必须缺席，再做最小真实调用。
有 Task Center producer 时还必须新建 batch，验证真实 `batchId` 和分阶段进度；普通
`conversation_operation` 卡片不能代替业务 batch。

若 source、mirror、Release、materialized runtime 与 batch snapshot 全部一致，但暂停导出后又
自动运行或产物没有进入原聊天，排除 FDE 漂移并切换到 `$trace-mjs-task-center` 的控制、调度保留、
进程清理与 conversation delivery 闭环；不得重发 Release 或改旧 snapshot 伪造修复。

## 先做五路判断

| 场景 | 处理 |
|---|---|
| **用户把 DOCX/PDF/XLSX 等文档交给员工处理** | 这是会话任务输入，不是员工定义或 Release 变更。直接用当前员工处理文档；不要启动 FDE 发布、不要索要 bdsh 或任何私有资产仓库。 |
| **明确从一个账号删除、撤销或下架 release-backed 员工** | 使用 `tools/revoke_release.py` 的两阶段账号级撤销；它不签名、不需要 key-store，也不是发布入口。 |
| **明确替换现有 Release 的一个 `data` / `recipe` / `template` 文档资产** | 普通 operator 使用 `tools/revise_data_asset.py` 的 source-free broker。服务端只返回 hash-only plan/签名信封并继承未改资产；operator 只上传新文档，不下载 definition、SOUL、卡片、脚本或旧资产。 |
| **FDE 用户明确创建或修改自己的员工完整闭包** | 把 definition、SOUL、技能卡和资产放入普通本地 `fde-package.json` 包，使用 `tools/publish_user_employee.py`。需要指定模型时在 definition 写 `model.default` 并传同值 `--model`；不得要求或写入 GitHub，不得把用户导向共享 manifest。 |
| **员工需要携带固定版本 CLI、本地 MCP、常驻服务、原始/编译脚本或 npm 依赖** | 走 release/v2 Runtime Module。内部作者提交 strict descriptor + reviewed sources + lock/integrity；受信 publisher 构建并 seal 平台 bundle。禁止在客户设备运行 `npx`、`npm install` 或 lifecycle script，也禁止把 authoring source 伪装成 legacy catalog asset 下发。 |
| **内部第一方/受审员工的完整纯云闭包变更** | 由有资产仓库 ACL 的内部作者在受审资产包中维护完整 `cloud_only` 闭包，再用 `publish_from_manifest.py`。闭包没有 `bdsh_path` 时不需要、也不得索要 bdsh checkout。 |
| **明确要求修改带 App 镜像的员工** | 转交内部 maintainer/CI；只有该受信环境能取得源码和镜像，并显式传 `--maintainer-bdsh-root` 做逐字节校验。普通 operator 不接收源码或私库权限。 |

不要把“用户上传了文档”推断成“要把该文档写入员工资产”。只有用户明确要求改变
definition、SOUL、技能卡或后续所有会话使用的 runtime/data 资产，才进入发布流程。
普通 operator 的职责是账号范围预检、source-free 文档资产修订、签发授权与状态读回，不使用
`get_release_bundle`、`get_release_asset` 或任何下载完整 Release 源码的辅助脚本。

当 Runtime Module 同时包含经常修改的脚本与体积较大的 npm/npx 依赖，必须完整读取
[runtime-module-incremental-transfer.md](references/runtime-module-incremental-transfer.md)。完整
Release 仍重新签名，但传输以 resolved blob SHA-256 为单位：稳定 npm 闭包放在独立
`runtime_library`，小型 CLI/stdio MCP consumer 用 `runtime_dependencies` 引用，并保持
`inline_assets`。不得把 `node_modules` 重新塞回 consumer，也不得让“强制拉取”绕过 CAS 重传相同
摘要。脚本单改的验收必须证明 dependency blob 不变、publisher 不发送其 chunk、桌面只下载新
脚本 blob，并用新会话验证 Main 注入的只读依赖根。

创建 typed CLI 或 profile-bound 浏览器本地 MCP 时，还必须按
`FDE_USAGE_EXAMPLES.md` 的“8.2 Profile 隔离浏览器 MCP 完整发布”和“8.3 Typed CLI Runtime
Module 完整发布”执行最佳闭包实例。普通 employee/card 文本不是工具注册；发布器在凭据前要求
签名 `mcp_yaml` ID 与 `employee.yaml.mcp` 一致、stdio catalog 的每个 `@self/runtime` 入口都以
`kind=script` 进入同一 Release，浏览器 catalog 还必须具备 Profile binding 与 profiles root。
最终完成条件是物化后新会话完成 MCP/CLI 握手、MCP 原始 `tools/list` 出现逻辑工具、会话 schema
出现实际注册项，并完成一次无副作用调用。employee-local MCP 的会话注册名可能是
`mcp_<employee>_<catalog>_<hash>`，不一定等于裸逻辑名；按 description/input schema 和员工归属
记录 `logical_tool → registered_tool` 后调用实际注册名。合法命名空间化不是缺失，旧会话或单纯
资产存在也不算注册成功。

`--maintainer-bdsh-root` 只是镜像校验输入，不是身份授权；真正边界是源码仓库 ACL 与服务端
operator policy/role。

先 `--dry-run` 预览再真发。两个完整发布入口的 dry-run 都不联网，因此会明确报告远端名称预检
未执行；直发项目的 `activate_release` 或审批制项目的 `activate_approved_release` 仍是服务端
同名与发布资格硬门。source-free broker 的 dry-run 会登录并
验证服务端 hash-only plan，但不创建密钥、不签名也不写服务器。

Runtime Module 发布先运行 `tools/build_runtime_artifacts.py`，或在真实完整发布中显式传
`--prepare-runtime-artifacts`。后者可能访问受审包仓库，和 `--dry-run` 互斥；dry-run 只能读取并
复验 `--runtime-artifact-cache` 中相同 builder policy 生成的 sealed set。npm 闭包要求根生产依赖
与 descriptor 完全一致，所有传递包都带 exact version、sha512 integrity 和无凭据受信 HTTPS
registry URL；git/file/link/workspace 来源一律拒绝。当前 policy v4 只接受 non-ZIP64 的 stored ZIP，
并把单 blob 与解包 tree 分别硬限为 64 MiB；旧 policy cache 不得复用。publisher 从封存 blob
重新盘点 tree/size 后才签名。必须分别读回 source module digest、resolved
artifact digest、CAS blob hash/size、release/v2 signature domain 与 active release。服务端成功不等于
桌面完成：还要验证 runtime-plan 的完整 `source_descriptor`、短期 download authorization、目标
平台物化、execution host readiness、secret broker 的 `needs_auth` 分支，以及新会话的真实工具结果。
已有会话/batch 的 release lease 与 `runtime-snapshot` 不热换。

phase-one typed CLI 的 input/output schema 只能使用发布 Guide 列出的 17 个关键字、七种单字符串
type，递归深度最多 16；`$ref`、组合器、pattern 和 schema-valued additionalProperties 均拒绝。
CLI command name 使用 `^[a-z][a-z0-9_-]{0,62}$`，version 去空白后非空，JSON/NDJSON 下
commands 非空且 methods 为空；stdio MCP 只用 NDJSON 且 commands/methods 均为空。
CLI 必须是 oneshot/none/never/zero-restart/invocation，stdio MCP 必须是
persistent/mcp_initialize/never/zero-restart/conversation；partition keys 仍限三种受信 identity，
并发固定在 1..64。以 `tests/fixtures/runtime-module-phase1-contract.json` 为跨语言向量，不得因
Admin 或桌面暂时更宽松而放过 publisher。此规则不启用 HTTP local service 或 runtime library
的直接执行。

当前桌面首波只直接启动 macOS managed Node 20 typed CLI 与 stdio MCP。签名
`runtime_library` 可以作为它们同一 Release 内的只读依赖层被 Main 精确挂载，但仍不可直接启动；
不要把 HTTP/SSE local service、任意 library execution、Python、顶层 native ABI 或 Windows
artifact 误报为已经可执行。required 不兼容必须失败，optional 不兼容必须从目标 plan 省略。

**端点**：测试服(gmxlab)为
`https://yoodesk.gmxlab.ai/fde-mcp/mcp`。远程环境只能使用受审 HTTPS endpoint。
凭据是 FDE 专用账密，≠ App 登录密码。交互式 Agent 操作使用非回显输入；owner-only
`.env` 和成对进程变量分别只用于 owner 已配置的本地客户端和受控 CI，别写命令行。

## 删除、撤销或下架一个精确账号的云员工

把“删除员工”“撤销员工”“从账号下架”解释为移除**一个精确账号**对 cloud custom employee
的可见性与挂载，不是删除不可变 Release、资产或审计历史。使用
`tools/revoke_release.py`，不要逐项调用底层 MCP 工具。

先执行只读预检；一次只传一个账号，不使用重复 `--account`、逗号列表或 `*`：

```bash
.venv/bin/python tools/revoke_release.py \
  --employee-id <employee-id> \
  --account <customer-email-or-user-uuid> \
  --fde-user <operator@example.com> \
  --fde-url https://yoodesk.gmxlab.ai/fde-mcp/mcp \
  --dry-run \
  --json
```

从 JSON 核对并向用户复述 canonical `account_id`、`employee_id`、当前 active
`release_id` 和 `outcome=would-revoke`。只有用户确认这三个精确身份后，才把该次预检返回的
`release_id` 作为乐观锁执行真实撤销：

```bash
.venv/bin/python tools/revoke_release.py \
  --employee-id <employee-id> \
  --account <same-customer-email-or-user-uuid> \
  --release-id <confirmed-current-release-id> \
  --fde-user <operator@example.com> \
  --fde-url https://yoodesk.gmxlab.ai/fde-mcp/mcp \
  --json
```

真实命令必须通过 `remove_custom_employee` 原子禁用该账号的 employee entitlement、
release-specific bindings 和 release-specific card grants。若账号当前指针与确认过的
`release_id` 不一致，立即失败并重新从 dry-run 开始；不得自动撤销后来激活的新 Release。
撤销保留 immutable Release、资产与完整审计历史，且不影响其他账号。

撤销不生成或使用设备签名，不需要 `--key-store-dir`，也不修改 manifest、Release 内容或
资产字节。若预检显示 `serving_path=legacy`、`legacy-skip`、没有 immutable release pointer，
或工具/服务端不支持 `remove_custom_employee`，停止并报告边界；不得改 legacy
`custom_employees` / `custom_employee_assets`、调用 Admin retire 路径或用数据库、缓存删除兜底。
`already-revoked` 和 `not-entitled` 是无需写入的幂等结果，明确报告即可。

完成条件分两层，不能互相替代：

1. **服务端读回**：真实命令返回并复核相同 canonical `account_id`、`employee_id`、
   `release_id`，`enabled=false`、`history_preserved=true`；随后通过
   `get_release_state` 确认 entitlement 已禁用且原 Release/manifest/资产历史仍保留，通过
   `get_employee_mounts` 确认所有 resolved mount 均为 `live=false`。若写响应途中丢失，CLI
   必须用这两项读回对账：闭合时报告 `revoked-reconciled`；无法闭合时报告
   `commit-unknown` 并要求重新 dry-run，绝不把它冒充普通“未执行”错误或盲目重放。
2. **桌面读回**：确认安装版 App 当前登录的正是目标账号，按
   [FDE_USAGE_EXAMPLES.md](../../../FDE_USAGE_EXAMPLES.md) 的当前 Desktop Debug Bridge
   runbook 等待/触发 catalog 同步，确认员工已从可用 catalog/人才市场消失且新建含该员工的
   会话被策略拒绝。桌面传播是异步证据；本地 profile/资产在 GC 宽限期内仍存在不表示撤销失败。

不要手删 `~/.yoodesk/custom-employees/`、profile、资产缓存、token 或
`runtime-snapshot` 来制造“已下架”结果。若用户要求所有账号下架，先取得每个精确账号并对每个
账号分别完成 dry-run、身份确认、单账号真实撤销和分层读回；不存在跨账号通配撤销。

## 创建/发布前名称硬门

创建或签发定制员工前，先对**精确目标账号**调用
`list_account_custom_employee_names(account=<邮箱或user UUID>)`。这个账户范围的服务端结果是
重名权威来源；不要要求操作者 clone、打开或遍历任何私有资产仓库来证明名称可用。

把候选 definition 的 `displayName` 与返回项按“去首尾空白、折叠连续空白、忽略大小写”比较：

- 同名且 `employee_id` 相同：这是原员工升级，可以继续；
- 同名但 `employee_id` 不同：停止创建/发布，改用新名称；
- 目标账号没有返回项：只表示该账号当前没有已启用的同名定制员工，不代表其他账号也没有；
- 工具不存在，或 action/account 未授权：明确报告 Go FDE 后端或 operator policy 尚未就绪并停止，
  不得回退到私库目录扫描，也不得声称“无重名”。

对应项目的 `activate_release` / `activate_approved_release` 是最终硬约束：即使调用方漏做预检，服务端也必须拒绝把规范化后的同名
`displayName` 以不同 `employee_id` 发给同一账号。发布后再次调用名称列表，确认目标名称只对应
预期的 `employee_id`；名称列表成功不替代 release、桌面物化与新会话/新任务验证。

## FDE Console 审批制发布绑定

FDE Console 创建的 `approval_required` 员工不能走普通 `activate_release`。从该员工已批准的
application 详情保存完整 JSON 到本机未跟踪文件，优先通过 `publish_user_employee.py` 或内部
`publish_from_manifest.py` 传入：

```text
--publish-application-file <application-detail.json>
```

publisher 必须先证明该文件属于目标员工、状态已批准或可恢复，并逐项比较冻结 snapshot 与本地包的
完整 definition、SOUL、技能卡定义、资产 module/kind/path/hash 和 runtime modules；之后才能在计算
manifest hash、Release ID 和设备签名前写入
`publish_application_id` / `publish_snapshot_hash`，并且只调用一次
`activate_approved_release`。成对 ID/hash 参数只供受控自动化/恢复；两参数缺一或格式非法即停止。
服务端在履约事务内必须独立重做冻结 snapshot 与 staged Release 的闭包比较。不得在签名后补 metadata，也不得用
普通激活入口、数据库写入或服务端代签绕过。批准后的履约者是当前员工编辑者，不是历史 creator
或已经转出的 legacy owner。

成功返回必须证明同一 application、同一 Release、非空 Version 和 `status=published`。即使
Release readback 已 active，只要 application/outbox 完成证明缺失，仍报告未知/失败，不能冒充
发布完成。省略这对参数时保留既有直发 manifest 和 `activate_release` 兼容行为。

## 现有文档资产的 source-free 修订

只有目标账号当前 active release 已包含同一路径且其 kind 是 `data`、`recipe` 或 `template`
时才走这条路：

```bash
python3 tools/revise_data_asset.py \
  --account <customer-email-or-uuid> \
  --employee-id <employee-id> \
  --rel-path runtime/<document>.md \
  --file <local-new-document> \
  --fde-user <operator@example.com> \
  --fde-url https://yoodesk.gmxlab.ai/fde-mcp/mcp \
  --key-store-dir "$HOME/.yoodesk/fde-signing-38" \
  --dry-run
```

工具先用 `resolve_account` 把精确邮箱/UUID 绑定为 canonical user UUID，再调用
`prepare_data_asset_revision`，只接受该 UUID 下旧 release 的 hash-only manifest、派生关系和
精确签名信封；确认后再签名，并由 `commit_data_asset_revision` 在服务端原子继承未改的
definition、SOUL、卡片和资产行，只上传新文档字节。响应出现 source/payload 字段、旧 release
指针变化、hash/envelope 不匹配、目标不是三种允许 kind、文件超过 2 MiB 或路径/扩展名不安全时
全部 fail-closed。它不是创建员工、修改脚本或任意路径写入通道。

## 发布前 Definition 兼容性硬门

发布器的 manifest/签名闭包校验通过，不代表桌面一定能创建员工。每次 dry-run 和真发都必须由
`publish_from_manifest.py` 内置的严格门读取目标 `employee.yaml`，按当前桌面
`yoodesk.employee/v2` schema 校验 definition。不得只让模型目测 YAML，也不得用
`validate_manifest.py --strict` 的资产闭包成功替代这一步。

发布命令继续运行前，输出必须包含同一 release 的：

```text
[publish_from_manifest] phase=local_validated ... definition_schema=yoodesk.employee/v2 definition_compatible=true model_selection=signed model_default="MiniMax-M3" ...
```

未声明模型的员工应在同一位置输出 `model_selection=desktop_default`，且不出现伪造的
`model_default`。缺少这行、字段值不是 `true`，或进程非零退出，都必须在登录、签名和上传前停止。此门同时作用于
用户自有 `--package-dir` 和内部 manifest 两条完整发布路径，并严格检查：

- 顶层只允许 `schema`、`id`、`displayName`、`role`、`tagline`、`icon`、`tone`、
  `category`、`tags`、`version`、`publisher`、`isolation`、`mcp`、`builtins`、
  `routing`、`permissions`、`model`、`sourcePath`、`carry`。禁止把卡片或 SOUL 的说明字段
  临时塞进 definition；例如 `description` 和 `defaultLocale` 都会被 0.3.80 桌面严格拒绝。
- `routing`、`permissions` 和 `model` 同样拒绝未知子字段，并校验字符串、字符串数组、布尔值、
  正整数以及当前枚举。不能因为 YAML 能解析就推断桌面能创建员工。
- `model.default` 只允许公开模型 ID：不得有首尾空白或 ASCII 控制字符，长度按桌面 JavaScript
  语义最多 120 个 UTF-16 code unit。它进入签名 definition 与确定性 Release ID；目标服务器
  `/v1/models` 未挂载时桌面必须失败，不能静默换成默认模型。`model.provider` 只是可选目录元数据。

- `permissions.filesystem` 只允许 `none | sandbox | full`。`outputs_only` 是非法值,即使语义上只想写
  `~/.yoodesk/outputs` 也不能自造枚举;需要文件/终端沙箱时评审后使用 `sandbox`,只有明确需要宿主机完整访问才使用 `full`。
- `permissions.network` 只允许 `none | mcp_only | full`。同样禁止自造更细的枚举。
- 任何 schema 错误都必须修正权威 `employee.yaml` 后重新 dry-run，生成新的 release ID；不要删除
  已激活的不可变坏 Release，也不要反复强拉同一份坏 definition。

OpenCode 或隔离 worktree 没有自己的 `.venv` 时，不要退回缺少 PyYAML 的系统 Python，也不要临时
改源码绕过依赖。使用另一个已受审 `yoodesk_fde` checkout 的 `.venv/bin/python` 作为解释器，但
脚本参数必须指向**当前待验 worktree** 的 `tools/publish_user_employee.py`；先输出两个绝对路径，
避免误跑旧发布器。没有可验证解释器时停止，不得把静态目测冒充 dry-run。

发布后的完成条件必须包含桌面物化，不能止于 `server_verified=true`。在目标电脑上要求
远端/本地 release ID 与 manifest hash 相等，完整闭包资产 `assetsSynced=true`、
`assets_synced=true`、`allMatch=true`、`signaturesValid=true`，并且员工 profile 已创建。
服务端有效但本地 release 为空、`assets_synced=false` 或出现
`persona profile not installed` 时，按签发前跨机器 reference 先定位账号水合与 `employee-sync`，
不要反复强拉、重发相同 Release 或重装 App。设置页笼统显示
`The account or employee does not have the required permission` 时，不能直接判定为账号授权问题；
先用结构化 `employee-sync code/message` 区分授权失败、下载失败和 definition 物化失败。

## 权限模型:为什么我被拒了

服务端按操作员配白名单(`allowed_accounts/modules/employees`),**没有通配符**。两条路:

1. **发自己账号(自测首选)**：只有服务端当前授予
   `allow_self_account_publish`、operator 具备所需 role/action，且同邮箱 Account 用户仍为唯一、
   active、有效席位时，本人账号范围才可动态放行新 employee/module。每次以当前能力检查、
   dry-run/预检和服务端 readback 为准；不要把历史操作员名单或某次成功当作现行授权。
2. **发共享测试账号/客户账号**：employee id 和 scoped manifest 的**全部 module** 必须在当前
   operator policy 中显式授权。报错 `requested employee/module scope exceeds …` 时报告精确
   account/employee/module/action 缺口并停止；不要依赖旧白名单案例，也不要自行扩大范围。

**闭包校验边界**：`validate_manifest.py --strict --employee-id <id>` 只读取目标员工的
definition、绑定卡片与发布资产。`cloud_only: true` 且没有 `bdsh_path` 的完整闭包直接通过，
不要求上一级目录存在 bdsh；无关模块缺失或私有内容不可见也不能阻塞该 scoped 校验。
目标闭包只要实际声明了一个 `bdsh_path`，就属于内部镜像发布线：
`publish_from_manifest.py` 必须收到显式 `--maintainer-bdsh-root`，普通 operator 应停止并转交
maintainer/CI，而不是向用户或签发人索要源码。
该参数本身不赋予源码访问或发布权限；仓库 ACL 与服务端 policy/role 才是授权边界。

## 拒收/失败速查

| 报错/症状 | 原因与处理 |
|---|---|
| signing scope exceeds authorization | 员工 id 或某个 module 不在白名单(工具会重签 release **全部**资产,模块要**并集**齐)→ 报管理员 |
| 账号相关被拒 | 工具接受精确邮箱或 user UUID；服务端先把邮箱唯一解析为 UUID，再按 operator 的账号范围校验。邮箱不存在/重复或解析后的 UUID 未获授权都会拒绝 |
| 名称列表工具不存在/被拒 | 先部署支持 `list_account_custom_employee_names` 的 Go FDE 后端并给 operator 增加 action；不要回退为私库目录扫描 |
| custom employee display name is already assigned | 同一账号已有不同 employee id 使用规范化后的同名；保留原 id 做升级或改名 |
| prepare/commit data asset revision 被拒 | 目标必须是现有 active release 内的 `data`/`recipe`/`template`，且 account/employee/module/action 均须获服务端 policy 授权；不要索要旧源码绕过 |
| selected employee release contains bdsh_path | 这是内部镜像闭包；转交 maintainer/CI，并由其显式传 `--maintainer-bdsh-root`，不要向普通 operator 索要源码 |
| missing FDE operator account/password | `--account` 不是登录身份。真发必须补目标 endpoint 的 FDE operator 用户名和非回显密码载体；YooDesk、客户、SSH 或服务器密码不能替代。尚未具备时在登录/签名/上传前停止 |
| invalid credentials | 不尝试其他系统的密码，也不把它归因于资产签名。让管理员验证或重置该环境的 FDE operator 注册、active 状态和密码，再复用同一候选 Release |
| 内部 Manifest 报 `current employee editor access is required` | 该线固定为 `direct_signed_release`，不需要 edit 席位。只读检查服务端是否已部署 direct 自动初始化，以及该 employee ID 是否已属于 `approval_required`；不要创建空壳、补编辑席位或切换审批命令 |
| 内部 Manifest 报 `bound YooDesk account publication requires an approved workbench application` | 服务端仍在把直发当旧审批流，或 ID 已被审批制项目占用。修正/部署 direct 服务端或使用正确内部 ID；不要临时创建 application、传 `--publish-application-file` 或改走用户包 |
| dry-run 过、真发签名报错 | 本机 openssl 不支持 ed25519 |
| 发 N 个客户 | release 是**账号级快照**,N 个客户 = 跑 N 次 |
| 客户端拒收 | 以安装版是否支持当前 v2 definition/signature/catalog 能力及结构化 `employee-sync` readback 为准，不写死最低版本号；完整 manifest 发布核对同一设备签名闭包，source-free broker 只签新目标资产和派生 release，设备私钥不可拷到别的机器 |
| 207 桌面报 `device certificate CA signature is invalid` | 先核对桌面构建时固定的 `YOODESK_BUILD_ACCOUNT_URL=https://test.ruov.cn` 与 207 **公开** CA PEM；运行时改 URL 不能替换已打包信任根，不要重签同一 Release，更不能分发 CA 私钥 |
| 输出 `server_active=true server_verified=true` | 先确认同次 `get_release_state` 含 `catalog_ready=true`；缺失或 false 都是服务端失败，不能输出成功。服务端闭合后仍须单独报告桌面物化、新会话工具和最小真实调用；未验证时写 `desktop_materialized=unverified` |
| 重跑命令看到同一 active Release | 区分本轮新激活与既有 Release 读回复核，核对服务端创建/激活时间；不得用本轮验证时间冒充发布时间 |
| 服务端有 Release、本地为空、资产目录已出现 | 查 `employee-sync`；`definition-invalid` 表示 definition schema 不兼容,修源码并发新 release,不要归因于网络或重复强拉 |
| 新 Release 已是 `assets_v1`，新会话仍出现旧 typed CLI/local MCP | 旧 Runtime-v2/Hybrid active pointer 未退役；不要重发同一 Release或手删 runtime store。要求安装包含 Main 退役修复的新包，重启后 `release-sync --force`，再核对 `release` 无 runtime mismatch、全新会话旧工具缺席；有 Task Center 时新开 batch |

### 桌面 Release 源码诊断（按需读取）

当问题涉及 Account catalog 字段进入桌面后丢失、`release-sync` 假成功、
Bridge HTTP 非 2xx 却退出 0，或 catalog 已有员工但人才市场不可见时，必须完整读取
[desktop-release-diagnostics.md](references/desktop-release-diagnostics.md)。

该 reference 负责桌面源码地图、状态语义、最小测试与 OpenCode 独立复核门；本 Skill
仍保留服务端、Account、桌面远端和桌面本地四层真值。源码测试通过不能替代安装版 App 验收，
源码诊断也不得自行发布员工或访问线上 FDE。独立复核只有在结构化 summary 与每条 finding
语义一致且产生完整最终报告时才算通过；模型供应商卡在最终输出时按不完整报告处理，并用全新
会话重跑。

## 能同步但 Release ID / Manifest 为空

看到下面组合时,不要先判定“发布失败”,也不要立刻重发:

- 强制拉取成功,服务器与本地 `content_hash` / 资产闭包 hash 一致;
- 资产逐项 hash 匹配且签名有效;
- 但服务器和本地 `Release ID` 都是空值,界面把 `content_hash` 回退显示在
  `Manifest SHA-256` 位置。

这通常表示**资产链路可用,release 诊断字段在 Account API 层丢失**。Account resolver
仍可能已经按 release entitlement 选中并下发正确 definition 和签名资产,所以员工能同步、
能运行;旧版 Account `EmployeeCatalogItem` / `_safe_custom_item` 没有序列化
`release_id`、`release_manifest_hash`,桌面只能退回 catalog `content_hash` 对比。

按四层真值排查,不要把其中一层替代另一层:

1. **FDE 服务端真值**:对精确账号和员工调用 `get_release_state` +
   `get_employee_mounts`。要求 `serving_path=release`、release `status=active`,
   release / entitlement / card binding 的 `release_id` 完全相同,manifest hash、
   release 资产数和 live cards 闭合。这里已经正确时不要重新发布。
2. **Account catalog 真值**:检查已认证的 catalog/detail 响应是否包含同一个
   `release_id` 和完整 `release_manifest_hash`。FDE 真值正确、Account 响应却为
   `null` 时,核对**服务器实际运行**的 Account 文件/进程,不要只看本地源码。
   运行版必须在响应模型声明两个 nullable 字段,并在 FDERelease 分支从
   `row.release_id` / `row.manifest_hash` 映射。按该环境受审部署流程更新 Account;
   不改数据库、不重发 release 规避、不覆盖 `.env` 或服务器其它热修。
3. **桌面远端真值**:用 Debug Bridge 读远端指纹:
   `node yoodesk/apps/desktop/scripts/bridge.mjs release <employee-id>`。Account 修复后,
   remote 应立即出现 release ID / manifest;若仍为空,先查 Account JWT 指向的
   base URL 和运行实例。
4. **桌面本地真值**:再显式执行
   `node yoodesk/apps/desktop/scripts/bridge.mjs release-sync --force <employee-id>`。
   修复前物化过的 manifest 可能仍无 release 字段;强制拉取后要求 remote/local ID
   和 manifest 全相等,`matchBasis=release_manifest_hash`,
   `match=true`,`synchronized=true`。

同一员工发给两个账号会得到两个账号范围的 release ID;即使资产字节相同,也不要要求它们
共享一个“全局 release ID”。报告结果时分别写清 FDE active release、Account 响应、
桌面 remote 和桌面 local。只有 `content_hash` 时称为 **Catalog Content SHA-256**,
不要把它冒充 Release Manifest SHA-256。

## "发成功了但客户没生效"三连

1. 客户机须**登录且未锁屏**；等待下一次受信同步轮询，或通过安装版 Bridge 显式强制拉取。
   用 `get_release_state` 或 publisher 的 server verification readback 取得每个资产期望 hash，再与客户机
   `shasum -a 256 ~/.yoodesk/custom-employees/assets/<员工id>/<rel_path>` 比较。
2. **已开跑的批任务用启动时冻结的快照**——必须新开一轮任务。
3. 旧会话缓存旧 system prompt——**新开会话**才吃新版。

如果新版同时从 Runtime-v2/Hybrid 退回 `assets_v1`，还要把“旧运行时工具在全新会话中缺席”
列为正向验收条件。只看到新版 profile/config、逐资产 hash、`assetsSynced=true` 或一个普通会话操作
卡片仍不够；旧 active pointer 可以在这些证据全绿时继续给新 sidecar 自动挂载已删除工具。

红线:绝不 `cp` 直改客户机 `~/.yoodesk/custom-employees/assets/`(下次同步被云端签名版覆盖,还可能验签拒)。

## 桌面发布后 Debug Bridge 验证

本 Skill 只使用安装版附带的桌面 Bridge CLI 做 Release 指纹和强制同步读回：

```bash
node yoodesk/apps/desktop/scripts/bridge.mjs release <employee-id>
node yoodesk/apps/desktop/scripts/bridge.mjs release-sync --force <employee-id>
```

不要在 Skill 里复制端口、grant 文件、原始 HTTP/WebSocket 或消息发送协议；这些属于安装版
Bridge 的当前安全契约，必须跟随桌面源码/runbook。手机 USB/adb Bridge 已退役，不得
用桌面 Bridge 模拟；若说的是 Task Center 8782 批次接口，切换到
`$trace-mjs-task-center`。
