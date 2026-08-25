# FDE Runtime And Release Drift Diagnostics

## 何时读取

完整读取本 reference，用于以下症状：

- 权威脚本或提示词已经修改/发布，但安装版员工仍表现为旧版本；
- 38 与 101 的桌面包、Account 后端、FDE endpoint 或签名根可能混用；
- active Release 已更新，但桌面 materialized runtime、Hermes sidecar 工具快照或
  batch `runtime-snapshot` 仍旧；
- 新 active Release 已从 Runtime-v2/Hybrid 回到纯 `assets_v1`，但全新 sidecar 仍自动挂载
  上一版 typed CLI 或 local MCP；
- 旧资源似乎“掉了”、新旧脚本混跑，或只凭员工还能看见就判断包连接正确；
- 暂停并导出短暂成功后又恢复，需要先排除运行时漂移，再转交 Task Center 控制链。

这是运行时/发布身份审计，不替代
[desktop-release-diagnostics.md](desktop-release-diagnostics.md) 的桌面源码投影审计。两者都只读；
不得为了制造一致而修改本地缓存、旧快照或线上 Release。

## 八层真值账本

任何“已生效”结论都必须记录下面八层。未知层写 `unverified`，不得用另一层代替：

| 层 | 必记身份 | 能证明什么 | 不能证明什么 |
| --- | --- | --- | --- |
| 1. 权威资产源 | `yoodesk_fde` commit、`yoodesk-dzhyg` gitlink/commit、每个 source path + SHA-256 | 本轮受审输入 | server 已激活、客户机已更新 |
| 2. bdsh 兼容镜像 | 仅 manifest 声明 `bdsh_path` 的 path + SHA-256 | 过渡镜像与权威源一致 | FDE Release、安装版 proxy 已更新 |
| 3. 环境身份 | 用户指定环境、Account URL、FDE URL、update feed、FDE CA public-key fingerprint | 发布和桌面包指向同一部署 | 某员工在该部署可调用 |
| 4. active signed Release | canonical account UUID、release ID、manifest hash、asset hashes、entitlement/mount readback | 该账号服务端闭包 active | Account 透传、桌面物化 |
| 5. 桌面构建与运行 | source commit、DMG/App hash、version/arch、build-time backend、安装路径、运行进程 identity | 当前进程确实来自目标包 | materialized runtime 与 Release 相等 |
| 6. 桌面物化 | Bridge remote/local release ID、manifest、`assetsSynced`、逐资产 expected/local hash、签名状态 | 安装版已取得并验过当前 Release | 已打开 sidecar/batch 已热换 |
| 7. 会话工具快照 | 新 conversation ID、Hermes runtime session、materialization 后的 `tools/list` 和最小可调用 smoke | 新 sidecar 看见当前工具 schema | 旧会话也被热插工具 |
| 8. 批次冻结快照 | batch ID、startedAt、snapshot attestation、每个文件 SHA-256、writer identity | 该批次实际执行的不可变代码 | 当前 active Release 的最新代码，除非 hash 相等 |

同一员工可因历史 catalog、另一环境的账号数据、尚未 GC 的本地 profile/资产或旧会话仍然可见。
因此“101 包还能看到 38 员工”不是后端身份。必须从 build-time 常量、安装包、运行进程和当前
Account/Release readback 证明环境，不能从 DMG 文件名、shell 临时环境变量或人才市场卡片反推。

## 先判断真正 owner

不要把所有 `.mjs` 都当成同一种热更新边界：

| 变更 owner | 交付方式 | 生效门 |
| --- | --- | --- |
| 员工 definition/SOUL/card/选中的 runtime asset | 完整 signed FDE Release | server readback → desktop materialization → 新会话；批任务再开新 batch |
| signed employee-local MCP 的 YAML、schema、dispatch、同 Release runtime | 完整 signed FDE Release；先用 `$author-fde-browser-mjs` 验证闭包 | materialization 后新 sidecar `tools/list` + 真实工具 smoke |
| App bundled 全局 `web-automation` proxy、共享 Node/browser runtime | bdsh authoritative desktop change + rebuild/install | 新包/安装进程身份 + 新 sidecar；只改 FDE proxy mirror 无效 |
| Desktop Main、IPC、Task Center Registry/controls、Renderer | bdsh desktop change + rebuild/install | 源码测试和安装版验收；FDE Release 不能替代 |

必须先读员工实际绑定的 MCP catalog 和安装版工具 schema。`web_automation_proxy.mjs` 这个文件名
本身不能决定 owner：employee-local signed MCP 可随 Release 更新；App 全局 proxy 则必须重包。

## 权威源到镜像只能单向、定向同步

内部资产的权威源是 `yoodesk-dzhyg`。`bdsh_path` 只是兼容镜像：

1. 只在权威 `yoodesk-dzhyg` asset 中实现并测试；
2. 从父 bdsh 根运行 scoped dry-run；
3. 只用多个 `--only <exact-file>` 做 source → mirror 写入；
4. 运行 strict validator，并对本轮每个文件直接 `cmp`；
5. 审查 status/diff，禁止把无关 WIP 带入 Release。

```bash
cd /Users/admin/crf/bdsh
python3 scripts/sync_fde_to_bdsh.py --dry-run \
  --only meituan_review_batch_driver.mjs
python3 scripts/sync_fde_to_bdsh.py --write \
  --only meituan_review_batch_driver.mjs
python3 scripts/validate_fde_sync.py --strict
cmp yoodesk_fde/yoodesk-dzhyg/runtime-scripts/meituan_review_batch_driver.mjs \
  mcp-servers/meituan_review_batch_driver.mjs
```

禁止从 `mcp-servers/` 反向覆盖权威资产，禁止宽范围 sync 覆盖用户 WIP，也禁止把
`yoodesk-dzhyg/proxy-mirror/web_automation_proxy.mjs` 当成安装版全局 proxy 的热更新入口。

## 38/101 环境硬门

发布或打包前先写出 `requestedEnvironment`，再固定环境身份：

- 38 自建桌面变体需要 build-time
  `YOODESK_BUILD_ACCOUNT_URL=https://yoodesk.gmxlab.ai`；运行时临时设置同名变量不能修正已经
  打错的包；
- 自建 FDE 还必须在构建时使用该环境的
  `YOODESK_BUILD_FDE_CA_PUBLIC_KEY_PEM`，只带 public key，绝不复制 CA private key；
- 38 FDE 发布 endpoint 是当前 Guide 规定的
  `https://yoodesk.gmxlab.ai/fde-mcp/mcp`，并使用环境独立 key-store；
- 未注入 self-hosted backend 的默认桌面包可能指向另一部署。以当前桌面 packaging guide、
  编译产物和安装版 readback 为准，不把历史默认值复制成永久 Skill 常量；
- Account URL、FDE URL、update feed 或 FDE CA fingerprint 任一层与请求环境不同，立即
  fail-closed。此时不得发布员工、上传 update feed 或用“员工还能用”放行包。

FDE-only runtime 修订不需要因此重包；只有环境错误或 owner 位于 App bundle/Main/IPC/Renderer
时才需要桌面构建。相反，重包也不能替代 signed Release 和 materialization。

## Runtime-v2/Hybrid → assets_v1 退役迁移

这是普通 hash 漂移之外的**工具负闭包**：新版签名闭包不仅要加入新资产，还必须停止给新会话
挂载已经从 manifest 删除的 Runtime Module。先从 publisher/server readback 对比连续两版 Release：

1. 上一版 manifest 的 `runtime_modules` 非空，或桌面上一版 delivery mode 为
   `runtime_plan_v2` / `hybrid`；
2. 当前 active Release 是 release/v1/`assets_v1`，不再声明这些 Runtime Modules；
3. 当前 asset hashes、definition/SOUL、entitlement 和 mounts 均属于新版。

若满足上述条件，桌面安装版必须在提交新签名资产闭包之后退役该员工的旧 active runtime
pointer。退役只阻止**新 lease**：不可变旧 Release、已获取 session/task/batch lease 和合法历史
快照继续保留，不能为了清理工具而删除 runtime store、lease 或 snapshot。发布 Skill 不直接修改
这些生成状态；缺少主程序能力时，第一处漂移是 `desktop_runtime_retirement_missing`，owner 为 bdsh
Desktop Main，需要提交、重建、安装并重启新包，而不是重发相同 FDE Release。

安装版验收顺序：

1. `bridge.mjs release <employee-id>`：remote/local Release identity 和资产逐项一致；若
   `runtimeIntegrity.active=true` 且指向旧 Release，必须 `match=false`，不得放行；
2. 在含退役修复的安装包上执行一次 `release-sync --force`，再读 `release`，要求没有旧 active
   runtime mismatch；`assetsSynced=true` 本身不是充分证据；
3. 新建 conversation，记录新的 runtime session，核对实际启动/`tools/list`：当前 profile 引用的
   employee-local MCP 存在，上一版删除的 typed CLI/local MCP **缺席**；只看磁盘 `config.yaml`
   不算工具快照；
4. 对当前工具做最小无副作用或受权真实调用。若员工生产 Task Center schema-v2，再用新会话创建
   新 batch，要求返回真实 `batchId` 且任务中心显示业务阶段；普通 `conversation_operation` 不是
   batch 证据；
5. 旧会话/旧 batch 仍看到旧工具是预期 lease/snapshot 行为，不得用它们验新版，也不得热插或
   直接改写。

全新会话仍加载旧工具时，结论是 `stale_runtime_pointer`（新包尚未执行退役）或
`desktop_runtime_retirement_missing`（安装包不具备修复），不是 `materialization_stale`，前提是
新版 Release 与资产物化身份已经一致。停止重复发布、停止等待旧会话自愈，并保留 conversation ID、
runtime session ID、旧工具名、`release` 指纹和安装包 commit 供 Main 回归。

## 只读漂移检查器

先用正式 publisher/readback 和安装版 Bridge 取得服务端与桌面指纹，再运行 canonical Skill
附带的检查器。JSON 文件只能含 release fingerprint，不含 bearer token、密码、私钥或资产正文：

```bash
python3 skill-is-all-you-need/skills/fde-publishing/scripts/inspect-fde-runtime-drift.py \
  --employee-id agency-ops-meituan-review-reply \
  --asset-root yoodesk-dzhyg \
  --manifest yoodesk-dzhyg/manifests/fde_modules.json \
  --bdsh-root /Users/admin/crf/bdsh \
  --release-fingerprint-json /path/to/ignored/bridge-release.json \
  --expected-account-url https://yoodesk.gmxlab.ai \
  --observed-account-url https://yoodesk.gmxlab.ai \
  --expected-fde-url https://yoodesk.gmxlab.ai/fde-mcp/mcp \
  --observed-fde-url https://yoodesk.gmxlab.ai/fde-mcp/mcp \
  --require-complete --json
```

它逐项比较：

```text
authoritative source → optional bdsh mirror
                     → Bridge remote expected asset hash
                     → Bridge local materialized hash/signature
```

默认还要求 manifest 选中的员工资产路径集合与 Bridge Release 资产集合完全相等，防止已删除的
旧脚本继续留在 active closure 中；仅在显式 `--rel-path` 做定点调查时，集合门缩小为“所选路径
必须全部存在”，不能据此宣称完整 Release 已闭合。

检查一个已存在批次时追加 `--batch-root <exact-batch-dir>`，并从受审 producer 的冻结文件清单为
每个文件重复传 `--snapshot-rel-path runtime/<file>`。旧 producer 若写入有效的
`.yoodesk-runtime-snapshot.json`，检查器可直接用其 file list/signature；两种证据都没有时，即使
现存文件逐个通过 attestation，也只能报 `snapshot.integrity=unverified` / `incomplete`，不得把任意
非空子集当成完整快照。完整 attestation 可以包含未被本批次选中的其他 Release 资产，这本身不是
缺失。

默认 `--snapshot-policy historical`：已证明完整的快照自身必须与其 attestation 一致，但与当前
Release 不同会标成 `expected_historical` 和 `freshBatchRequired=true`，不会把合法历史批次误判为
损坏。验证新版只能对发布后新建的批次使用 `--snapshot-policy fresh --require-complete`；此时任何
旧 hash 或未证明的 producer 文件集合都阻断放行。

状态含义：

- `pass`：本次要求的证据全部闭合；
- `incomplete`：没有发现漂移，但仍有 `unverified` 层；带 `--require-complete` 时 exit 2；
- `blocked`：发现 `different`、`missing`、`invalid` 或不安全路径，exit 1；
- `firstDivergence`：沿环境/源/镜像/Release/物化/快照检查的第一处阻断，不是修复动作；
- `readyForFreshBatch` 只表示当前 Release 链允许**新开**一轮，绝不表示旧 batch 已更新。

检查器不验证 Hermes tool snapshot，也不替代 FDE 设备证书的密码学验证；前者必须用新 sidecar
工具列表与最小调用证明，后者使用 Bridge `signatureValid` 和 publisher/server readback。

## 旧会话与旧批次规则

- materialization 完成后，旧 Hermes session 的工具 schema 仍是旧快照；新建 sidecar/会话，禁止
  热插工具到旧 schema；
- Runtime-v2/Hybrid → `assets_v1` 时，新 sidecar 必须同时证明当前工具存在和已删除旧工具缺席；
- running/paused batch 始终恢复原 `runtime-snapshot`。不要覆盖、补丁或删除其文件；
- 历史快照与当前 Release 不同是正常历史身份。要验证新版，必须新建 batch；
- 有真实发送副作用时，不能通过“重开整批”重放已确认成功项。先安全结束/导出旧批次，使用其
  ledger 冻结已完成项，再由受审 retry/resume 合约决定后续工作；
- 不删除 `~/.yoodesk/custom-employees/assets`、profile、manifest 或 snapshot 来强迫同步。

## 暂停导出不是漂移时的转交

若 source、mirror、active Release、materialized runtime 和该 batch snapshot 的 hash 全部闭合，
但“暂停并导出”后同一 batch 又运行，或产物只落盘没有进入原聊天，这不是 FDE 版本漂移。
切换到 `$trace-mjs-task-center`，检查 control adapter、scheduler retention、writer/descendant cleanup
和 conversation artifact delivery。

该场景的完成证据至少包括：

1. 同一个 `batchId` 的 pause request 与 `control.status=completed`；
2. 最终状态持续为 paused，writer 和全部 worker descendants 已退出；
3. CSV/XLSX/待处理产物的 mtime 晚于 pause request，且内容可读；
4. 产物真正投递到原 conversation，而不是只打印磁盘路径；
5. 至少覆盖调度器下一个 admission 窗口的 bounded sampling 内没有 auto-resume，也没有 replacement
   batch；只有明确用户继续指令才能恢复。

一次 control ACK、短暂 paused、一个 PID 消失或文件存在都不是闭环。

## 报告模板

最终报告按层输出，不使用笼统的“已更新”：

```json
{
  "requestedEnvironment": "gmxlab-38",
  "source": {"commit": "", "assetHashes": {}},
  "mirror": {"status": "equal|not_applicable|unverified|different"},
  "serverRelease": {"releaseId": "", "manifestHash": "", "verified": false},
  "desktop": {"package": "", "installedVersion": "", "accountUrl": ""},
  "materialization": {"releaseId": "", "manifestHash": "", "allAssetsMatch": false},
  "sidecar": {"conversationId": "", "runtimeSessionId": "", "toolsVerified": false},
  "batch": {"batchId": "", "snapshotStatus": "unverified"},
  "firstDivergence": null,
  "liveBoundaryUnproven": []
}
```

只有需要的层实际有证据才写 `verified=true`。源码测试、签名包、安装启动、materialization、
fresh tools/list 和真实业务 smoke 始终是不同 claim。
