# FDE 签发前跨机器物化门

## 核心边界

发布涉及另一台电脑、换机、重装、远程客户机，或出现“原机能用但新机不能用”时，完整读取本
reference。这里的签发前硬门检查的是目标电脑能否物化**当前 active Release**，不是声称未签名的
候选 Release 已经物化。

候选 Release 不能在签名前正式物化：桌面 `CustomEmployeeAssetMaterializer` 的输入就是带 Release
attestation、资产签名和设备证书的服务端 Release。不得伪造“候选已预物化”证据，也不得把
publisher 的本地闭包/Definition 校验叫作桌面物化。当前 `--dry-run` 也会在本地生成设备签名；
要求签名前先过跨机器基线时，必须在调用它之前检查目标机。

本门避免的是这次事故：目标机连当前已发布版本都没有物化时，不再继续签下一版掩盖交付链路问题。
候选版本签名后仍要另过一次精确 Release 的目标机/金丝雀物化门。

## 签发前：先证明目标机交付基线

1. 固定精确目标电脑、目标账号、员工 ID、预期服务器环境，以及服务端当前 active Release `R0`
   的 release ID、manifest hash、完整资产数/路径/hash、entitlement 和 live mounts。资产数从
   `R0` 计算，不能写死；本次回评事故恰好是 26/26 项缺失。
2. 如需桌面 Bridge，先加载 `$operate-desktop-debug-bridge`，在目标电脑用安装版 CLI 读取
   `status`。确认 App 已解锁、`logged_in`、服务器绑定正确，当前账号与 publisher/readback 的
   canonical account UUID 是同一账号。不得拿签发机、原机或同版本 App 的输出代替。
3. 只读执行 `bridge.mjs release <employee-id>`，记录 remote/local release ID、manifest hash、
   资产总数和缺失数。`R0` 必须满足 remote/local 身份相等、`assetsSynced=true`、
   `allMatch=true`、`signaturesValid=true`、`synchronized=true`、缺失数为 0，且员工 profile 已创建。
4. 若 remote 是 `R0`，但 local 为空/旧版/资产不全，先把
   `pre_sign_target_baseline=failed` 作为第一处分歧。确认账号与服务器绑定后，只允许一次受控
   `bridge.mjs release-sync --force <employee-id>`，随后重读 `release` 和结构化
   `employee-sync code/message`。任何 HTTP 非 2xx、CLI 非零或结构化错误都算失败。
5. 只有 `R0` 在每台声明的目标电脑都通过后，才能调用会生成设备签名的
   `publish_from_manifest.py`、`publish_user_employee.py` 或其 `--dry-run`。目标机离线、锁屏、
   未登录或 Bridge 不可用时，记录 `target_baseline_materialized=unverified`；只要本次目标包含
   跨机器交付，就不得调用发布器。

`persona profile not installed: <employee-id>` 发生在 MCP/业务工具启动前，是目标机 profile/资产
物化硬失败。看到它就停止签发和业务重试；不得换 employee ID、复制旧机 profile，或再签一份相同
内容碰碰运气。

新员工没有 `R0` 时，签前基线对该员工记为 `not_applicable`，不能冒充 `true`。这类候选只能在
本地闭包/Definition/运行时制品门通过后签名，然后立刻进入下述签后金丝雀门；如果用户要求“签名前
必须证明该候选正式物化”，当前协议无法满足，停止并说明需要新增 draft-preview/两阶段激活能力。

## 签名后：候选 Release 单独验收

1. 保存候选 `R1` 的 release ID、manifest hash 和完整资产 hash；服务端 readback 只证明
   `server_verified`，不继承 `R0` 的桌面结果。
2. 在精确目标机或用户指定金丝雀上同步并重读 `R1`，要求 remote/local 身份相等、完整资产和签名
   全绿、缺失数为 0、profile 存在。失败时保留 `R1` 为未通过验收的不可变 Release，不继续签 `R2`。
3. 创建绑定精确员工 ID 的全新 direct conversation，核对实际 tools catalog。默认只做无副作用
   smoke；回评流程使用 preview 或 draft/no-send，除非用户另行授权真实发送。
4. 批任务必须由新会话创建新 batch，并返回真实 `batchId`。旧 batch 的 `runtime-snapshot` 是冻结
   历史，不能证明 `R1` 已物化，也不能手改。

## 本次案例如何判定

本次回评指纹是：服务端 `R0` 正确，目标机 local Release 为空、26/26 项资产缺失，正式员工新单聊
报 `persona profile not installed`。这应在下一次签发开始前直接得到
`pre_sign_target_baseline=failed`，不得生成下一版签名。一次受控同步后，同一个 `R0` 的
Release/Manifest、资产 hash 和签名全部一致，随后全新正式员工会话能创建真实批次。因此它是目标机
账号水合/交付基线缺口，不是包字节本身“不可物化”。

## 禁止的捷径与报告字段

- 不从可用机器复制 assets、员工/浏览器 profile、token、device key store 或 runtime snapshot。
- 不直接编辑/删除目标机物化缓存，不靠重装 App、重复强拉或重复签发制造成功。
- 不用原机成功、同版本 App、单点 `synchronized=true` 或消息 `accepted` 代替目标机证据。

最终分别报告 `server_verified`、`target_baseline_materialized`、`candidate_signed`、
`candidate_materialized`、`fresh_conversation_bound` 和 `live_smoke`，每项只写
`true`、`false`、`unverified` 或 `not_applicable`，并给出 `first_divergence`。后一项不得由前一项推导。
