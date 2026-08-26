# API 费用监控真实性说明

- 日期：2026-08-26 14:08
- Agent：Codex

## 做了什么

- 无代码改动。
- 核查费用监控页面和 API 调用实现，确认当前费用是本机请求日志乘以手动填写的单价，只能作为估算。
- 确认生图 API 使用的 API Key 与火山引擎费用中心账单查询不是同一套鉴权能力；真实账单需要接入火山引擎费用中心或方舟用量 OpenAPI，并使用具备权限的 Access Key/Secret Key 签名鉴权。

## 更改的文件

- 无代码文件改动；新增本说明 changelog。

## 验证

- 阅读 `lib/features/settings/api_cost_monitor.dart`：确认 `estimatedUsd = successful.length * price`。
- 阅读 `lib/core/services/ai_service.dart`：确认当前只保存 API 请求日志，不请求账单或余额接口。
- 参考火山引擎费用中心 OpenAPI 文档：账单查询接口包括 `ListBill`、`ListBillDetail` 和 `QueryBalanceAcct`；火山 OpenAPI 使用 Access Key/Secret Key 签名鉴权。
