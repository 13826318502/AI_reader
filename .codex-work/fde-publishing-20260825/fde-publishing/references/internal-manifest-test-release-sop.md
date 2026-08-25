# 内部 Manifest 员工测试发布 SOP

## 适用范围

只用于 `yoodesk-dzhyg/manifests/fde_modules.json` 已登记的内部第一方或受审员工完整发布。
典型对象包括美团回评员工和周报运营专家。用户本地 `fde-package.json`、FDE 工作台审批员工、
单文档修订和账号下架都不走本 SOP。

内部 Manifest 的固定发布模式是 `direct_signed_release`：

- 首次激活由服务端自动创建员工项目，不先建空壳；
- 不要求员工 `edit` 席位；
- 不创建或提交 FDE 工作台 application；
- 不传 `--publish-application-file`；
- 仍要求有效的 FDE operator 账号密码、精确账号范围、标准 `asset_signer` 设备证书、完整闭包
  验签和写后读回。

不要因为服务器报权限或审批错误，就把内部 Manifest 临时改走 `approval_required`。两条发布线
是员工项目的治理身份，不是失败后的重试选项。

## 0. 先填写发布单，缺一项就不运行真发

在命令前先输出下面这些非敏感字段：

```text
release_lane=internal_manifest
publication_mode=direct_signed_release
employee_id=<exact-id>
environment=<development-207|gmxlab-38|production-101|reviewed-other>
fde_url=<reviewed-https-endpoint>
account_anchor=<one-email-or-user-uuid>
fde_operator=<operator-email>
credential_carrier=<interactive|getpass-file|owner-env|protected-ci|missing>
approval_application=not_used
edit_seat=not_required
mirror_mode=<cloud_only|maintainer_bdsh>
```

`account_anchor` 是 Release 的账号归属锚点；它不是 FDE 登录名，也不会自动提供 FDE 密码。
`fde_operator` 才是调用发布服务的身份。目标 YooDesk 账号、YooDesk App 登录密码、SSH 密码、
服务器 root 密码和客户业务账号密码都不能替代 FDE operator 密码。

真实发布前，`fde_operator` 和 `credential_carrier` 必须已经确定。`credential_carrier=missing` 时
原样停止并报告：

```text
BLOCKED: 缺少 <fde_url> 的 FDE operator 凭据。需要 operator 用户名，以及非回显交互密码或
owner-only password file。目标 YooDesk 账号、YooDesk 登录密码、SSH/服务器密码都不能替代。
尚未登录、签名、上传或激活 Release。
```

不要先试目标账号密码，也不要等服务器返回 `invalid credentials` 才询问。

允许的密码承载方式只有：

1. 人在可写 PTY 中让 `getpass` 非回显读取；
2. 显式 `--fde-user` 加仓库外 owner-only 单行密码文件
   `--fde-password-file <path>`；文件必须是当前用户拥有的普通文件，不是软链接，Windows ACL
   或 POSIX mode 不能让其他用户读取；
3. owner 已配置的受保护 `.env`；
4. 受控 CI 中成对的 `FDE_MCP_USER` / `FDE_MCP_PASSWORD`。

密码不进入命令参数、聊天复述、日志、员工资产、测试或 Git。Agent 不用 `cat`、`source` 或打印
密码文件来“验证”。

## 1. 固定环境，不能只写“发到测试服”

| 环境 | FDE HTTPS endpoint | key-store 规则 |
|---|---|---|
| development-207 | `https://test.ruov.cn/fde-mcp/mcp` | 使用只属于 207 CA 的目录，例如 `~/.yoodesk/fde-signing-207` |
| gmxlab-38 | `https://yoodesk.gmxlab.ai/fde-mcp/mcp` | 使用只属于 38 CA 的目录，例如 `~/.yoodesk/fde-signing-38` |
| production-101 | `https://api.softcompower.com/fde-mcp/mcp` | 使用只属于 101 CA 的目录，例如 `~/.yoodesk/fde-signing-101` |

其他环境必须由负责人给出受审 HTTPS endpoint 和独立 key-store。不要从 Account URL、服务器 IP、
旧聊天或另一环境的命令猜 endpoint。不同环境不能共用证书缓存目录。

## 2. 本地只读预检

从 canonical Skill 所属的同一个 `yoodesk_fde` checkout 运行：

```bash
python3 tools/fde_workflow_identity.py --require-asset-gitlink

python3 tools/validate_manifest.py \
  --manifest yoodesk-dzhyg/manifests/fde_modules.json \
  --asset-root yoodesk-dzhyg \
  --strict \
  --employee-id <employee-id>
```

先查看 scoped closure 是否含 `bdsh_path`：

- 全部 `cloud_only` 且没有 `bdsh_path`：不传 `--maintainer-bdsh-root`；
- 任一条含 `bdsh_path`：只有 maintainer/CI 能使用真实 mirror checkout，并在后续两条命令都传
  `--maintainer-bdsh-root <absolute-bdsh-root>`。

浏览器/MJS 员工还要运行 canonical authoring inspector。Runtime Module 员工先准备或复验 sealed
artifact cache。不能删资产、缩小闭包或改成 `cloud_only` 来绕过预检。

## 3. Dry-run 和真发

Dry-run 只验证本地闭包、definition、Release 计算和已有证书；它不登录、不执行服务端名称预检，
也不证明 FDE 密码正确。没有当前环境的缓存证书时，dry-run 会明确停止，这不表示服务器发布失败。

以 207 为例：

```bash
python3 tools/publish_from_manifest.py \
  --employee-id <employee-id> \
  --account <account-email-or-user-uuid> \
  --fde-user <fde-operator-email> \
  --fde-url https://test.ruov.cn/fde-mcp/mcp \
  --key-store-dir <owner-only-207-key-store> \
  --maintainer-bdsh-root <absolute-bdsh-root-if-required> \
  --dry-run
```

真发使用同一 checkout、employee、account、endpoint、key-store 和 mirror 参数，去掉 `--dry-run`，
并通过非回显交互或增加下面的密码文件参数提供密码：

```text
--fde-password-file <owner-only-password-file>
```

不要增加 `--publish-application-file`，不要去工作台创建申请，也不要先给员工分配编辑席位。

## 4. 失败只按原发布线修，不自动换线

| 报错/现象 | 本 SOP 的处理 |
|---|---|
| `missing FDE operator account` | 补显式 `--fde-user`；不要把 `--account` 值当 operator。 |
| `missing FDE operator password` | 补非回显密码载体；不要试 YooDesk、SSH 或客户密码。 |
| `invalid credentials` | FDE 登录资料不存在、密码错误或已停用。停止重试，让管理员验证/重置该环境的 FDE operator；资产签名尚不能据此判错。 |
| `current employee editor access is required` | 对内部 Manifest 来说不是“去申请编辑席位”。先只读确认服务端已部署 direct 初始化逻辑，并确认该 employee 项目不是既有 `approval_required`。不要换成用户包或审批命令。 |
| `bound YooDesk account publication requires an approved workbench application` | 当前服务端仍按旧审批规则处理直发，或 employee ID 已被审批制项目占用。部署/修复 direct 服务端或使用正确内部 employee ID；不创建临时 application。 |
| `selected employee release contains bdsh_path` | 补 maintainer mirror 参数或转交有仓库 ACL 的 maintainer；普通 operator 不拿私库。 |
| `requested ... scope exceeds authorization` / `forbidden` | 管理员补精确 account、employee、module、action 范围；不能删闭包资产“适配权限”。 |
| `signing certificate lacks asset_signer` | 用当前 operator policy 刷新标准设备证书；不恢复回评专用 capability/role。 |
| `server_active=true server_verified=true` | 只表示服务端闭合，不能写“桌面已验收”。继续第 5 节。 |

发生网络超时或返回不确定时，先对同一个确定性 Release 做 readback/reconcile，不重新改版本、不盲目
多次激活。若输出的 Release 已经 active，要区分“本轮新激活”与“读回已有 active Release”；核对
服务端 Release 创建/激活时间，不能用本轮验证时间冒充发布时间。

## 5. 发布后按四层交付

测试结论固定拆成：

1. `server_release`：本次是新激活还是已有 Release 复核，Release ID、manifest hash、active、
   entitlement、全部 assets 与 card mounts 是否闭合，并要求 `get_release_state.catalog_ready=true`。
   该字段必须证明 project、owner deployment、employee membership、agency binding、version 与
   entitlement 六项关系全部 ready；字段缺失或 false 时不得写 `server_verified=true`。若内容已 active
   但关系不完整，publisher 应跳过重复上传并幂等重放同一 `activate_release` 修复后再读回；
2. `desktop_materialization`：精确目标电脑、当前登录账号、remote/local Release 与 manifest、
   `assetsSynced`、`allMatch`、`signaturesValid`；
3. `fresh_conversation_catalog`：新会话是否出现当前员工工具，记录 logical tool 到实际注册名；
4. `callable_smoke`：一次无副作用的真实最小调用及结果。

桌面尚未验证时必须写 `desktop_materialized=unverified`，不能说“无需桌面检查”或“登录后自然会有”。

如果 207 桌面出现 `device certificate CA signature is invalid`，而服务器 Release 已验证，不要重签
同一资产。先核对桌面构建时是否固定：

```text
YOODESK_BUILD_ACCOUNT_URL=https://test.ruov.cn
YOODESK_BUILD_FDE_CA_PUBLIC_KEY_PEM=<207 的公开 CA PEM>
```

运行时只改 Account URL 不能替换已经打进安装包的 CA 信任根。公开 CA 可以进入构建输入，CA 私钥
绝不能离开服务器。修正构建后再在精确目标桌面同步并开新会话。

## 6. 可交付的最终报告模板

```text
发布线：internal_manifest / direct_signed_release
环境与端点：<environment> / <fde_url>
员工：<employee-id>
账号归属锚点：<account>
FDE operator：<operator>（密码载体：<carrier>，不输出密码）
本地闭包：<pass|blocked>，cards=<n>，assets=<n>，mirror=<mode>
服务端：<newly_activated|existing_release_verified|repaired_visibility|blocked>，release=<id-or-none>，catalog_ready=<true|false|missing>
桌面：<verified|unverified|blocked>，target=<machine/build>
新会话工具：<verified|unverified|blocked>
最小真实调用：<verified|unverified|blocked>
下一步：<one exact action>
```
