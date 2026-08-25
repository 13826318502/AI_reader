# FDE 员工 CRUD 与资产维护 Runbook

这份 Runbook 面向没有历史会话、从空目录启动的同事、OpenCode、小模型和其他 Agent。
它回答四件事：怎样创建员工、怎样查当前状态、怎样修改员工、怎样从一个账号下架员工。
这里的“删除”是撤销一个精确账号的可见性与挂载，不是抹掉不可变 Release、资产或审计历史。

## 0. 先建立身份与权限边界

1. 用 Skill 工具加载 canonical `fde-publishing`，从加载结果中的 `SKILL.md` 路径向上三级定位
   `yoodesk_fde` 根目录。`.codex/skills` 与 `.claude/skills` 只是 loader。
2. 完整读取根目录的 `AGENTS.md`、`FDE_PUBLISH_GUIDE.md` 和本文件。任一读取失败都停止，
   不从当前空目录、旧聊天或复制版 Skill 猜命令。
3. 从同一个根目录运行
   `python3 tools/fde_workflow_identity.py --require-asset-gitlink`。OpenCode 使用
   `tools/opencode_fde.sh` 启动，让发布和撤销 CLI 在凭据前核对仓库根、HEAD、canonical Skill
   SHA-256、完整 Skill/reference/operator-contract hash、发布工具链 hash 与资产 gitlink。
   Skill 来自一个 checkout、CLI 或资产来自另一个 checkout 时停止，
   不因凭据文件恰好位于旧 checkout 就切换工具。
4. 先说清对象属于哪一条线：

   | 目标 | 唯一入口 | 源码/Git 边界 |
   | --- | --- | --- |
   | 普通 FDE 用户创建或完整更新自己的员工 | `tools/publish_user_employee.py --package-dir` | 普通本地目录，不读写 GitHub |
   | 内部第一方或受审员工的完整闭包 | `tools/publish_from_manifest.py` | `yoodesk-dzhyg/crf` 是权威资产源 |
   | active Release 中一个既有 `data`、`recipe` 或 `template` 文档 | `tools/revise_data_asset.py` | 只上传新文档字节，不下载旧 Release 源码 |
   | 从一个精确账号下架 release-backed 员工 | `tools/revoke_release.py` | 先 dry-run，再用确认的 Release ID 执行 |
   | 查询源码闭包 | `tools/validate_manifest.py --employee-id` | 只读本地 manifest 与选中资产 |
   | 查询服务端/桌面实际状态 | 受权 MCP readback + 桌面 `bridge.mjs release` | 服务端、物化和新会话分别取证 |

5. Git push、服务端 Release 激活、桌面物化和真实调用是四个独立动作。用户只要求把源码上传到
   GitHub 时，不得顺手登录 FDE、签发 Release 或声称桌面已经更新。

任何真实服务端写入前都必须具备：当前 FDE 身份的有效 YooDesk 服务端绑定、精确员工或本地包身份、显式受审 HTTPS
endpoint、当前工作流允许的凭据承载方式、dry-run/名称预检结果以及用户对该次写入的明确授权。
不得提供目标账号选择、使用 `*`、猜密码或把计划写成完成。低层 CLI 的 `--account` 只允许填入
登录返回的 canonical `account_id` 作为一致性断言，不是发布目标输入。

## 1. 先查，再决定增删改

### 1.1 查权威源码与完整闭包

内部员工先从 manifest 反查，不要只看员工目录：

```bash
rg -n '"<employee-id>"|bind_employee.*<employee-id>|employee_id.*<employee-id>' \
  yoodesk-dzhyg/manifests/fde_modules.json

python3 tools/validate_manifest.py \
  --manifest yoodesk-dzhyg/manifests/fde_modules.json \
  --asset-root yoodesk-dzhyg \
  --employee-id <employee-id>
```

浏览器/MJS 员工还要运行：

```bash
node skill-is-all-you-need/skills/author-fde-browser-mjs/scripts/validate-browser-mjs-compat.mjs \
  --asset-root yoodesk-dzhyg \
  --employee-id <employee-id> \
  --json
```

`subscriptionReady=true` 只证明源码 wiring、语法、依赖闭包与工具暴露兼容；不证明服务器激活、
桌面物化、登录态或真实网页结果。选中闭包只要有一个 `bdsh_path`，内部 maintainer/CI 在发布前
还必须传真实 `--bdsh-root` 做 strict mirror 比较；完全 `cloud_only` 的闭包应比较 0 个 mirror。

### 1.2 查服务端、桌面和运行中任务

按层读取，不要互相替代：

1. 服务端：唯一账号解析、active `release_id`、manifest hash、entitlement、完整 asset hashes、
   card mounts；优先使用 publisher 写后的 `get_release_state` 与 `get_employee_mounts` readback。
2. 桌面：先核对 Bridge `account`，再读取 `bridge.mjs release <employee-id>`；强拉
   `release-sync --force` 是写动作，不属于默认只读查询。
3. 新会话：物化完成后开全新会话读取新的 tools catalog，分别记录 MCP `tools/list` 逻辑名与
   会话实际注册名，再做一次最小真实调用。employee-local MCP 可能被命名空间化为
   `mcp_<employee>_<catalog>_<hash>`；按 description/input schema 映射，不能因裸名不同误报缺失。
4. 已开始 batch：它持有自己的 `runtime-snapshot`。旧 batch 与当前 Release hash 不同通常是
   预期冻结，不得手改 snapshot；验新版要新建 batch。

涉及换机、重装、另一台客户电脑或“原机能用但目标机不能用”时，完整读取
[pre-sign-cross-machine-materialization-gate.md](pre-sign-cross-machine-materialization-gate.md)。
在调用 `publish_from_manifest.py` / `publish_user_employee.py`（包括会在本地生成签名的
`--dry-run`）前，先让每台目标电脑的当前 active Release 通过基线物化门。当前 Release
尚未物化时先修交付链路，不得靠签发下一版掩盖；签发机或原机成功不能代替目标机证据。

新员工 ID 绑定 `meituan-review-web-automation*` 时还要完整读取
[owner-mcp-runtime-trust.md](owner-mcp-runtime-trust.md)：不要追加 Desktop 员工白名单，也不要恢复
已退役的专用 capabilities、发布者角色或证书角色。发布器在签名/上传前验证员工/catalog 唯一精确
绑定，并使用标准 `asset_signer`、v2 资产签名、employee/module scope 与 resolver-authored
owner/Release provenance。目标机证据仍通过当前 Release 的物化、验签和全新会话读回取得。

本地 `~/.yoodesk/custom-employees/assets/...` 和 `~/.yoodesk/outputs/.../runtime-snapshot/...`
只是生成副本，不是员工源码。

## 2. 创建员工

### 2.1 普通 FDE 用户创建自己的员工

普通目录至少包含 `employee.yaml`、`SOUL.md`、`fde-package.json`，以及 package manifest 明确列出的
cards 与 assets。目录不需要 `.git`，也不得为了发布而加入 `yoodesk-dzhyg`：

```text
my-employee/
├── employee.yaml
├── SOUL.md
├── fde-package.json
├── cards/<card>.yaml
└── assets/runtime/<runtime-file>
```

若用户指定员工模型，先把公开模型 ID 写入权威 definition：

```yaml
model:
  default: MiniMax-M3
```

正式入口：

```bash
python3 tools/publish_user_employee.py \
  --package-dir /absolute/path/to/my-employee \
  --employee-id <employee-id> \
  --model <same-public-model-id> \
  --account <canonical-account-id-returned-by-login> \
  --fde-user <operator@example.com> \
  --fde-url https://<reviewed-host>/fde-mcp/mcp \
  --key-store-dir <endpoint-specific-owner-only-directory> \
  --dry-run
```

先读当前 `--help` 与 `FDE_PUBLISH_GUIDE.md` 的本地包 schema；不要从内部 manifest 猜
`fde-package.json`。确认后才去掉 `--dry-run`。这个入口不得接收 manifest、asset-root、
maintainer mirror 或 GitHub 参数。`--model` 是对签名 `employee.yaml model.default` 的一致性断言，
不是运行时覆盖；缺失或不一致必须在登录前停止。未声明模型时省略该参数并保留桌面默认。员工包
不得携带 provider URL、API key 或服务端路由，目标模型还必须出现在所连 Gateway 的
`/v1/models` 中。

### 2.2 内部作者创建受审员工

先给对象分配全局唯一且稳定的 `employee-id`，并在 `yoodesk-dzhyg` 创建完整源闭包：

内部员工不需要先在 FDE Console 创建空壳或分配编辑席位。`publish_from_manifest.py` 提交完整签名
闭包后，服务端在首次 `activate_release` 事务中自动创建
`publication_mode=direct_signed_release` 项目并同时激活 Release、entitlement 与 card mounts。
后续迭代继续使用相同 employee ID；既有 `approval_required` 工作台员工不能被这条直发路径覆盖。

| 业务对象 | 权威路径/字段 | 修改时要一起检查 |
| --- | --- | --- |
| 员工身份与挂载 | `employees/<id>/employee.yaml` | `id`、版本、MCP 列表、权限、显示信息、可选 `model.default` |
| 员工行为 | `employees/<id>/SOUL.md` | 工具边界、确认规则、真实完成证据 |
| 技能卡 | `skill-cards/<card>.yaml` | 唯一 card ID、`bind_employee`、工具名与参数契约 |
| MCP catalog | `mcp-servers/<catalog>.yaml` | source/command、环境、暴露工具与 employee binding |
| 确定性 runtime | `runtime-scripts/` | 入口、同级 helper、依赖闭包、结果/错误契约 |
| 可执行模块 | `runtime-modules/<module>/` | descriptor、源码、lock/integrity、目标平台 |
| 发布闭包 | `manifests/fde_modules.json` | employee/card/assets/runtime_modules、publish target、rel_path |
| 变更说明和测试 | `CHANGELOG.md` 与聚焦测试 | 业务语义、兼容/迁移、真实验收边界 |

浏览器员工必须先使用 `$author-fde-browser-mjs`；需要 Task Center 时再使用
`$trace-mjs-task-center`。优先复用已有 `browser_run_task` 或
`browser_parallel_run_task`，只有固定、脆弱、安全敏感或需要耐久状态的流程才增加自定义 MJS。
新 proxy 工具名/schema/dispatch 需要 bdsh 桌面源码与重建，不能靠 FDE Release 热更新出来。

内部纯云员工的 manifest 条目全部声明 `cloud_only: true` 且不写 `bdsh_path`。需要兼容镜像的员工
保留精确 `bdsh_path`；不得为方便发布把镜像资产伪装成纯云，也不得给真正纯云的闭包硬加 bdsh。

## 3. 修改员工

### 3.1 先确定真正 owner

- 改身份、SOUL、卡片、MCP、脚本或新增路径：修改权威源码并发布一个完整新闭包。
- 仅替换 active Release 中已经存在的文档型 `data`/`recipe`/`template`：使用
  `revise_data_asset.py` 的 hash-only broker；不能用它改脚本、MCP、definition、SOUL、card
  或创建新路径。
- 改 app-bundled Main/Hermes/proxy 能力：修改 bdsh 产品源码并重建桌面 App；只改员工资产不会
  产生新的宿主能力。
- 改生成缓存或旧 batch snapshot：方向错误，回到权威源修复。

### 3.2 合并未提交 WIP 的业务规则

不要对整个文件使用 `ours` 或 `theirs`。对每个相关文件先比较：当前远端 `crf`、WIP 基点、
WIP 内容和当前业务契约，然后只移植仍成立的语义。特别注意：

- WIP 可能基于旧员工版本，直接覆盖会回退已经上线的安全门、工具 schema 或 macOS/Windows
  兼容修复；modified 不等于更新。
- 同一条规则可能已经以更完整形式进入远端；此时不重复合并。
- 共享 runtime 的一次修改可能同时进入多个员工的 `publish_targets`。必须用 manifest 计算影响面，
  不能只看发起问题的员工目录。
- 保留所有无关 dirty files；在隔离 worktree 中工作并显式暂存本任务路径。

### 3.3 三个真实修改模式

#### 美团回评：确定性批次与冻结快照

权威内部 ID 是 `agency-ops-meituan-review-reply`。它由 employee、SOUL、绑定卡片、员工 MCP、
review launcher/driver/worker 和共享浏览器 runtime 组成。修改 batch driver、profile 或共享 proxy
后必须发布完整选中闭包，等待桌面物化，再用新会话和新 batch 验证；旧 batch 的
`runtime-snapshot` 不热换。READY/ACK/COMMITTED、durable terminal state 和真实发送/草稿证据
分别取证。

`agency-ops-meituan-review-reply-crf` 是曾由账号所有者通过 standalone `--package-dir` 发布的
用户自有身份，不是 `yoodesk-dzhyg` 的内部员工 ID。不得把 materialized copy 或这个 standalone
包反向提交到资产仓；要改它时回到所有者本地包流程。

#### ChatCut：员工资产与桌面 handoff 分层

`crf-chatcut-video-director` 的员工侧闭包包含 employee、SOUL、卡片、Hosted MCP catalog 与可选
runtime module。编辑器自动打开依赖工具返回的受信 `browserHandoff`/干净 URL 候选和 YooDesk
Main/Hermes 的消费能力。员工资产可以更新提示与 Hosted MCP binding，但若 Main 没有自动打开
能力，必须改并重建桌面；不能让员工打印链接或要求用户手点来冒充自动 handoff。验收要分别看到
受信 handoff、`autoOpened=true`、真实 media `assetId` 和可编辑时间线结果。

#### 门店专员：复用回评浏览器 resolver

`crf-meituan-store-specialist` 复用回评的共享 `browser_session_profile` 与 web automation 闭包，
而不是复制一套 Camoufox 启动器。最近的 Dock/皮肤修复因此落在共享 browser resolver、精确员工
profile skin、员工版本/卡片/MCP 与 manifest closure；不能只替换原始 Camoufox 图标，也不能只改
materialized runtime。门店浏览器显示 YooDesk 品牌只证明窗口身份，真实上架仍需页面上的保存、
上架状态、商品 ID 或链接。

三位员工的当前权威路径与 lane 见
`yoodesk-dzhyg/EMPLOYEE_ASSET_INVENTORY.md`。

## 4. 删除/下架与再次更新

先做只读预演：

```bash
.venv/bin/python tools/revoke_release.py \
  --employee-id <employee-id> \
  --account <canonical-account-id-returned-by-login> \
  --fde-user <operator@example.com> \
  --fde-url https://<reviewed-host>/fde-mcp/mcp \
  --dry-run --json
```

确认输出中的 canonical account UUID、employee ID 和 current release ID 后，真实命令只增加：

```text
--release-id <exact-confirmed-current-release-id> --json
```

如果 current release 在确认后变化，乐观锁必须阻止误删新版本。成功只撤销该账号的 entitlement、
release binding 与 card mounts，保留不可变 Release/资产/审计。随后等待桌面 remote catalog 不再
出现该员工；GC 宽限期内本地缓存仍存在不代表员工仍可调用，禁止手工删缓存伪造下架。

更新员工不是覆盖旧 Release：重新装配、签名和激活完整闭包会创建新的不可变 Release，并保留历史。

## 5. 内部资产的 Git 顺序

先在干净隔离 worktree 中提交资产仓，再提交工具仓 gitlink 与文档：

```bash
git -C yoodesk-dzhyg status --short
git -C yoodesk-dzhyg diff --check
git -C yoodesk-dzhyg add <only-reviewed-asset-paths>
git -C yoodesk-dzhyg commit -m "feat(fde): update reviewed employee assets"
git -C yoodesk-dzhyg push origin HEAD:crf

git status --short
git add yoodesk-dzhyg <only-related-tool-doc-test-paths>
git commit -m "docs(fde): document context-free employee CRUD"
git push origin HEAD:preview
```

第二个提交中的 gitlink 必须精确指向刚推到 `quanttides-design/yoodesk-dzhyg:crf` 的 commit。
推送后用 `git ls-remote` 和本地 `git rev-parse` 核对两个远端 head；不要只相信 push 文本。

如果闭包含 `bdsh_path`，发布前还要由 maintainer/CI 做定向 source → mirror 同步和 strict 校验。
发现 mirror 里有独立业务 WIP 时停止覆盖，先按业务语义合回权威资产源。GitHub 资产上传成功本身
不等于 mirror 已同步，也不等于服务端 Release 已激活。

## 6. 完成判据

按用户实际授权停在正确层：

- 仅创建/修改源码：聚焦测试、manifest closure、兼容性 inspector 通过。
- 仅上传 GitHub：再证明 asset `crf` head 与 FDE `preview` gitlink/head 一致。
- 要发布：增加精确账号的 Release/entitlement/mount readback。
- 要桌面生效：增加物化 hash、全新会话 tools catalog。
- 要跨机器迁移可用：签发前先证明每台目标机已物化当前 active Release；签发后再证明候选
  Release 的完整资产物化、精确员工新会话和安全最小调用。目标机不可达时不得签发下一版。
- 要证明业务可用：增加一次真实工具/网页/产物结果；浏览器弹出、工具受理、PID 或 UI 成功提示
  都不是最终业务证据。
