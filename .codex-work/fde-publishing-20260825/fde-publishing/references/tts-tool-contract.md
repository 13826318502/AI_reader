# FDE 员工使用 YooDesk TTS 的契约

当用户要给 cloud custom employee 增加文字转语音、旁白、角色台词、播报或配音能力，或员工
发布后看不到 TTS 工具、不能生成声音时，完整读取本 reference。它约束的是 **FDE 员工如何绑定和
使用 YooDesk 已内置的 TTS 能力**；不授权把供应商调用、密钥或网关实现迁进员工 Release。

## 先确定所有权

| 对象 | 权威所有者 | FDE 能否热更新 |
|---|---|---|
| 员工 `employee.yaml`、SOUL、卡片以及 `lu_tts` 绑定 | FDE 员工权威源与签名 Release | 可以，重新发布完整员工闭包 |
| `lu_tts` MCP catalog、`lu_tts_mcp.py`、Python runtime 打包 | YooDesk Desktop / bdsh | 不可以，需要 App 源码修改、重建和安装 |
| loopback capability 注入、`/v1/audio/speech`、LuAPI 路由和价格 | YooDesk Desktop Main 与 Go gateway | 不可以，需要 App 或服务端部署 |
| 供应商 API key、base URL、临时下载地址 | 服务端受保护配置 | 绝不能进入员工包、SOUL、卡片或用户消息 |

内部 maintainer 在 bdsh checkout 中以这些文件为实现权威；普通 FDE operator 没有该 checkout 时
不得猜实现或索要私库：

- `<bdsh-root>/mcp-servers/lu_tts_mcp.py`
- `<bdsh-root>/yoodesk/content/mcp/servers/lu_tts.yaml`
- `<bdsh-root>/yoodesk/services/llm-gateway-go/internal/gateway/tts.go`

## 员工闭包如何绑定

在权威 `employee.yaml` 的现有 `mcp` 数组中加入唯一 server id `lu_tts`：

```yaml
mcp: [lu_tts]
```

已有其它 MCP 时保留并追加，例如 `mcp: [web_search, lu_tts]`。不要把
`mcp_lu_tts_generate_speech` 当成另一个 server id，也不要把 App 内置的 `lu_tts_mcp.py` 或
`lu_tts.yaml` 复制成 FDE asset/Runtime Module。仅因使用 TTS 不需要把员工的 filesystem 或 network
权限扩大为 `full`；音频由受审 MCP 原子写入 YooDesk outputs。

在 SOUL 或技能卡中使用运行时暴露的 Hermes 工具名 `mcp_lu_tts_generate_speech`。其稳定身份是
server `lu_tts`、method `generate_speech`；某些工具检查器可能显示为 `lu_tts.generate_speech`。

## 两阶段调用是硬门

任何语音生成都先调用一次预览，`confirmed` 必须为 `false`：

```json
{
  "input": "需要朗读的完整文本",
  "voice": "Cherry",
  "model": "qwen3-tts-flash",
  "language_type": "Auto",
  "confirmed": false
}
```

预览成功必须返回 `ok=true`、`done=false`、`confirmation_required=true`，并回显完整文本、模型、
音色、语言及可选风格。把这些设置展示给用户；只有用户明确确认这组精确设置后，才用**完全相同的
参数**再次调用并设置 `confirmed=true`。用户修改文本、模型、音色、语言、风格或输出名后，必须重新
走 `confirmed=false` 预览。初始的“帮我生成语音”请求不能代替这次设置确认。

真实提交失败、超时、响应丢失或结果含 `automatic_retry_allowed=false` 时禁止自动重试，因为上游
可能已经生成并计费。先原样说明失败，并检查已有 outputs 和服务端审计；需要再次提交时让用户明确
决定。

## 参数契约

- 默认值：`model=qwen3-tts-flash`、`voice=Cherry`、`language_type=Auto`。
- 支持的精确模型名：`qwen-tts`、`qwen3-tts-flash`、`qwen3-tts-instruct-flash`、
  `qwen3-tts-vd-2026-01-26`、`qwen3-tts-vc-2026-01-22`。不得改写、别名化或自动回退。
- 除 `qwen-tts` 外，当前 MCP 对输入施加最多 600 个字符的硬门；更长内容先由用户确认分段方案，
  不要静默截断。
- `language_type` 只接受 `Auto`、`Chinese`、`English`、`German`、`Italian`、`Portuguese`、
  `Spanish`、`Japanese`、`Korean`、`French`、`Russian`。
- `instructions` 与 `optimize_instructions` 只适用于 `qwen3-tts-instruct-flash`；显式
  `optimize_instructions=false` 是有效设置，不能在第二次调用时丢失。
- `voice` 必须非空。自定义 voice id 与创建它的精确模型绑定，不能跨模型复用。
- `output_name` 可省略；使用时只能给普通文件名，实际后缀由返回的 audio media type 决定。

## 成功与发布验收必须分层

按顺序保留证据，前一层不能替代后一层：

1. 权威员工 definition 的 `mcp` 数组含 `lu_tts`，SOUL/卡片遵守两阶段确认和不自动重试规则。
2. 当前发布器对完整闭包 dry-run/本地兼容性校验通过，随后才按本 Skill 的账号范围流程签名发布。
3. 服务端 immutable Release、entitlement、mount 和桌面 materialization readback 指向同一 Release。
4. 安装版 App 已包含 `lu_tts` catalog/runtime；强制同步后新建会话，实际 tools catalog 中出现
   `mcp_lu_tts_generate_speech`。旧会话的工具快照不能作为新版验收。
5. 新会话先完成 `confirmed=false` 预览，取得用户确认，再完成一次 `confirmed=true` 真实生成。
6. 成功结果必须同时含 `ok=true`、`done=true`、精确 `model`/`voice`/`language_type`、audio
   `media_type`、`size_bytes>0` 和 `output_path=outputs/<filename>`。
7. 验证同一 YooDesk output root 下文件真实存在且字节数大于 0，最终用
   `MEDIA:<output_path>` 返回可渲染的音频文件卡。只看到工具成功文案、路径字符串或 Release 同步
   不能证明声音已生成。

## 失败分流

| 症状 | 归属与处理 |
|---|---|
| 全新会话没有 `mcp_lu_tts_generate_speech` | 先核对签名 definition 是否绑定 `lu_tts`；已绑定则检查安装版 App 的 MCP catalog/runtime。App 未内置时必须重建安装，重复发布员工无效。 |
| `YooDesk speech gateway capability is not configured` 或拒绝非 loopback gateway | Desktop Main 的短期 capability/loopback 注入缺失；修 App 运行时，不把 URL/Token 填进员工资产。 |
| gateway HTTP 503、提示价格未配置或模型不可用 | Go gateway 的模型路由、价格或供应商配置问题；修目标环境服务端并做受审部署，不改员工 SOUL 绕过。 |
| gateway HTTP 502、重定向位置不安全、空音频或非音频响应 | Go gateway/供应商响应处理问题；保留错误和审计证据，不自动重试，不用供应商临时 URL 直连。 |
| 模型、语言、voice、instructions 或长度校验失败 | 修正精确参数并重新做 `confirmed=false` 预览；不得静默换模型、音色、语言或截断文本。 |
| `confirmed=true` 后结果不确定 | 视为可能已计费；先查 outputs/服务端审计，禁止自动再次提交。 |
| 返回成功但文件不存在或为 0 字节 | 验收失败；不要回复 `MEDIA:`，定位 App output root、写盘或返回体问题。 |

FDE 热更新能改变“哪个员工可使用 TTS、员工怎样调用”，不能补齐 App 内置 MCP、loopback capability、
Go gateway 路由、供应商价格或密钥。报告时始终写清失败发生在 Release、桌面工具物化、预览确认、
网关生成还是本地音频落盘哪一层。
