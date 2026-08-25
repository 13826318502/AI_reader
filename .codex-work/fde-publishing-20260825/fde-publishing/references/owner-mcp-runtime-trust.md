# Owner MCP 标准运行时信任链

## 目的

`meituan-review-web-automation*` 前缀只选择回评业务能力，不是授权机制。Desktop 不维护员工 ID
白名单，也不再使用回评专用的 Debug Bridge capability、发布者角色或设备证书角色。精确
`employeeId -> ownerCatalogId` 权限来自标准 FDE v2 Release 的验签结果与 MCP Registry
resolver-authored owner/Release provenance。

这意味着新增员工 ID 无需修改 Desktop，也不需要寻找包含
`signedFdeOwnerMcpRuntimeAuthorization` 的安装包或手写 capabilities JSON。

## 当前信任链

发布器和 Desktop 必须共同保持以下不变量：

1. `employee.yaml.mcp` 中受保护前缀的 catalog 与 Release 内已签名 `mcp_yaml.id` 完全一致，
   且最多一个；同名前缀、SOUL、卡片或 profile 元数据本身不授予权限。
2. `mcp_yaml` 与其引用的 runtime 脚本都在同一个完整、不可变 FDE v2 Release 闭包中。
3. 每个可执行资产具有 SHA-256、v2 资产签名和 CA 认证的设备证书。
4. 设备证书包含标准 `asset_signer` 角色，并精确覆盖当前 employee 与每个 module scope。
5. Desktop 仅在完整验签、物化和 runtime 提交成功后，把 resolver-authored
   employee/catalog/Release provenance 交给 MCP Registry；伪造的 inline/profile catalog
   或另一员工的 owner tuple 不能获得能力。
6. 卸载、撤销或新 Release 不再绑定该 catalog 时，运行时权限随已验证的 owner/Release
   provenance 一起失效。

发布器的本地成功证据应包含：

```text
owner_mcp_trust=fde-v2-owner-release-provenance protected_owner_catalog="..." required_signing_role=asset_signer
```

## 已退役合同

以下项目已经退役，不得重新引入兼容层或把它们作为 0.4.2-101 的升级条件：

- `signedFdeOwnerMcpRuntimeAuthorization`；
- `yoodesk.fde/desktop-runtime-authorization/v1`；
- `signed-owner-mcp-v1`；
- `--desktop-capabilities-file`；
- `meituan_review_runtime_publisher`；
- `meituan_review_runtime_authorizer`。

旧 capabilities JSON 不能代替标准 Release 物化证据。当前 Desktop 不再广告回评专用授权合同是
预期行为，不表示缺少安装包。

## 发布与验收

发布前仍需完成 Definition、完整资产闭包、员工/catalog 精确绑定和签名证书 scope 校验。跨机器
发布还要按
[pre-sign-cross-machine-materialization-gate.md](pre-sign-cross-machine-materialization-gate.md)
证明每台目标机当前 active Release 的交付基线；不要用另一台机器或版本号替代。

发布后分别读取：

1. 服务端 active Release、manifest、entitlement、资产和 card mounts；
2. 精确目标 Desktop 的远端/本地 Release 指纹、全部资产 hash 与 `signaturesValid=true`；
3. 全新会话中由当前 resolver provenance 投影出的 tools catalog；
4. 一次安全的最小真实调用，浏览器员工还需验证精确 profile/账号边界。

如果出现 `MEITUAN_REVIEW_RUNTIME_IDENTITY_MISMATCH`，不要补员工白名单，也不要重新要求专用证书
角色。依次核对当前 Release 是否完整物化、签名资产是否属于同一 employee/module scope、签名
`mcp_yaml.id` 是否与 `employee.yaml.mcp` 精确一致，以及新会话是否确实使用当前 Release 的
resolver-authored provenance。旧 Desktop 若不支持标准 FDE v2 owner/Release provenance，应按
安装版发布流程升级；判断依据是物化与运行读回，不是已退役的 capabilities 字段。
