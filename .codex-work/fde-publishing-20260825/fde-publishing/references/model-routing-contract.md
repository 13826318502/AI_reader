# FDE 员工模型绑定与 Go Gateway 路由契约

这份参考用于创建或更新带 `employee.yaml model.default` 的 FDE 员工。它只覆盖文本模型绑定；
生图、Embedding、OCR、Coding Plan 和 FDE 内部 OpenCode 模型各有独立入口，不能因为都叫
“模型”而复用员工文本模型字段。

## 1. 当前真实调用链

```text
signed employee.yaml model.default
  -> account catalog: definition.model.default + item.model
  -> Desktop Main: 只信 active immutable Release
  -> Main-issued foreground/background capability: effectiveModel
  -> Desktop LLM proxy: 覆盖子进程传入的文本 model
  -> authenticated GET /v1/models: 验证 public model id 已挂载
  -> Go Gateway Config.RouteFor(publicModel)
  -> callOpenAIUpstream: base URL/key/upstream_model 全部由服务器选择
  -> provider-specific request/response adapter + billing settlement
```

FDE Release 只签一个公开模型 ID。它不拥有 provider URL、API key、默认路由、别名、费率或
上游实际模型名。`model.provider` 是可选目录元数据，不能作为路由输入或授权证明。

未声明 `model` 的 Release 使用桌面产品默认模型。声明后，桌面必须同时看到：当前账号可用的
active Release、匹配的 signed definition/catalog projection，以及 Gateway `/v1/models` 中完全相同
的 public id。任一不满足都失败，不得静默换成默认模型。

## 2. 当前 Go 转发方法

生产服务是 `yoodesk/services/llm-gateway-go`。文本路由目前由服务端注册表驱动：

- `YOODESK_LLM_MODEL_ROUTES_FILE` 或 `YOODESK_LLM_MODEL_ROUTES` 加载 JSON；
- key 是大小写不敏感的 public model id；
- 每项配置 `base_url`、`${ENV}` 形式的 `api_key`、可选 `upstream_model` 和 `provider`；
- `Config.IsAllowedModel` 只放行默认模型或已成功装载的 route；
- `Config.MountedModels` 生成 `/v1/models`；
- `callOpenAIUpstream` 根据 `RouteFor` 选择 base URL/key 并重写上游模型名；
- 定价准入、额度、usage 与结算仍经过同一 `handleOpenAIProxy`，不是每个 provider 各做一套。

这对普通 OpenAI-compatible 文本模型已经是配置化扩展：如果协议没有差异，新增模型不需要改
FDE 或桌面，只需完成服务端 route、secret、rate card、测试和部署。

当前耦合点是 provider 行为仍散落在通用路径：MiniMax 的 system prompt、think scrub/split，
以及 Qwen thinking 判断分别出现在 normalization/response 代码中。继续用 `if provider == ...`
扩展会让路由、协议适配和计费语义逐渐混在一起。

## 3. 后续模块化目标

保持一个 `ModelRegistry` 作为唯一解析入口，并把路由数据与协议适配拆开：

```go
type TextModelRoute struct {
    PublicModel   string
    ProviderID    string
    AdapterID     string
    BaseURL       string
    APIKey        string
    UpstreamModel string
    Capabilities  TextCapabilities
    BillingScope  string
    Required      bool
}

type TextProviderAdapter interface {
    Prepare(api string, route TextModelRoute, body map[string]any) (map[string]any, error)
    TransformJSON(route TextModelRoute, raw []byte, reasoningSplit bool) ([]byte, error)
    TransformSSE(route TextModelRoute, raw []byte, reasoningSplit bool) ([]byte, error)
}
```

建议模块边界：

1. `model_registry.go`：读取、规范化、去重并校验 public id、URL、credential reference、adapter、
   capabilities 和 billing scope；只返回已解析的不可变 registry。
2. `text_adapters/openai.go`：无供应商特例的 OpenAI-compatible 默认实现。
3. `text_adapters/minimax.go`：中文 system nudge、think split/scrub，仅在该 adapter 内。
4. `text_adapters/qwen.go`：thinking capability 与 DashScope 特有字段，仅在该 adapter 内。
5. `text_router.go`：只做 public id 查表、默认选择、allowlist 和 upstream endpoint 选择；不判断
   provider 名称。
6. `text_proxy.go`：统一认证、定价准入、quota、请求发送、usage 解析与结算；通过 adapter hook
   处理协议差异。

注册表条目应显式区分 `provider_id`、`adapter_id` 与 `billing_scope`。三者目前可能同名，但不是
同一个概念：provider 用于观测，adapter 决定线协议，billing scope 决定费率。不要再用一个
`provider` 字符串同时驱动三种行为。

## 4. 配置与启动安全

- 配置文件只允许 `${ENV_NAME}` credential reference，不允许 literal secret。
- URL 必须是绝对 HTTPS；loopback HTTP 只给受审本地测试，不允许公网投产。
- `required: true` 的 route 若缺 secret、adapter、rate card 或 URL，生产启动应失败；可选 route
  可以跳过，但必须出现在非敏感健康状态里并说明原因。
- `/v1/models` 只列成功解析、具备凭据且完成 pricing preflight 的 route；配置文件里“写了”不等于
  已挂载。
- 增加非敏感 `/internal/model-routes/health` 或等价启动快照，至少返回 public id、adapter、
  provider、upstream-model hash、loaded/skipped 和 reason，禁止返回 URL、header 或 credential。
  101/38 的同步检查应比较这个生效快照，而不是只比较 JSON 文件。
- registry 在一次进程生命周期内保持不可变。若以后支持热加载，必须先完整解析新快照，再原子
  交换；失败保留旧快照并报警，不能半更新。

## 5. 新增一个文本模型的闭环

1. 先确定稳定 public model id；FDE、桌面和客户只看到它。
2. 在 Go registry 加 route；若不是普通 OpenAI-compatible，再实现独立 adapter 和契约测试。
3. 在服务器受保护环境配置 credential；不得把值放入 Git、FDE 包或桌面。
4. 同一变更补 Account active rate card 的全部计费维度；缺定价必须 fail-closed。
5. 跑 registry、request transform、stream/non-stream、usage/settlement、unknown-model 和 missing-secret
   测试。
6. 部署目标环境，读非敏感 route health，并用已认证 `/v1/models` 确认 public id 真正出现。
7. 再把该 public id 写入员工 `employee.yaml model.default`，发布命令传同值 `--model`，生成新的
   immutable Release。
8. 分别验证 server Release、桌面 materialization、新会话 capability 和一次真实模型调用。

仅完成第 2 步的 JSON 修改、仅完成第 7 步的 FDE 发布，或看到旧会话仍能回答，都不能证明新模型
路由已上线。
