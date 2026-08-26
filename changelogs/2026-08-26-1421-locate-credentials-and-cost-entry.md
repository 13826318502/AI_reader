# 核对 AK/SK 与费用查询入口

- 日期：2026-08-26 14:21
- Agent：Codex

## 做了什么

- 无代码改动。核对用户提到的 Secret Access Key 费用查询功能入口。
- 确认 AK/SK 填写位置为“我的 → AI 服务配置”，位于 API Key 下方；费用页面入口为“我的 → 费用监控”。
- 确认现有 AK/SK 仅接入配置加载、保存、恢复，尚无真实账单/余额查询请求；费用监控仍用本地成功请求数乘以填写单价估算。向用户明确区分填写密钥与实际费用接口已接通。

## 更改的文件

- `changelogs/2026-08-26-1421-locate-credentials-and-cost-entry.md:1`：新增核查记录。

## 验证

- 阅读 `lib/features/settings/mine_page.dart:38` 与 `:52`，确认页面路由。
- 阅读 `lib/features/settings/ai_service_config.dart:551`，确认 AK/SK 输入框；搜索全项目中对应配置键的引用，均在配置页内。
- 阅读 `lib/features/settings/api_cost_monitor.dart:38`，确认费用为本地估算。
- 本次仅查询和记录，未运行构建或测试，未操作手机或读取实际密钥值。

## 追加：真实费用接口如何开通

- 无代码改动。查阅火山引擎官方文档，确认费用中心 OpenAPI 已公开开放，无需额外申请；使用 IAM 授权与 AK/SK 鉴权。
- 推荐创建专门的 IAM 查询用户：只查账单使用 `BillingCenterBillReadOnlyAccess`；同时查余额可使用 `BillingCenterReadOnlyAccess`，不授予管理或支付权限。
- 用户的密钥可在“访问控制 → 用户 → 用户详情 → 密钥”创建。应用侧仍需实现余额 `QueryBalanceAcct` 和账单 `ListBill` / `ListBillDetail` 的实际查询，现有录入框不会自动完成接入。
- 建议将长期 SK 保存在后端并由后端签名请求，避免将主账号密钥交给客户端或写入聊天/源码。
- 官方来源：https://www.volcengine.com/docs/6269/1165275 （API 概览）；https://www.volcengine.com/docs/6269/1186807 （费用权限）；https://www.volcengine.com/docs/6257/64983 （IAM 访问密钥管理）。本次未创建身份、修改账号权限或发送费用查询请求。
