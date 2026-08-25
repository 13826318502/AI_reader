# Runtime Module 分层增量传输

## 何时读取

当员工携带 typed CLI、本地 stdio MCP、适配脚本、npm/npx 包或其他大依赖，且请求涉及
“只更新脚本”“强制拉取”“不要重复传 node_modules”“Runtime Module v2 完整性”时，完整读取本
reference。它定义发布闭包、网络传输和运行时挂载的边界；不能用手改物化目录或放宽签名校验代替。

## 完整 Release 不等于整包重传

每次员工变更仍生成一个完整、不可变、设备签名的 release/v2 manifest。增量发生在 CAS blob
层，而不是对 Release 做不完整 patch：

```text
完整 source closure ──签名──▶ 新 release/v2 manifest
                                 │
                    每个 resolved artifact 的 blob SHA-256
                                 │
                 ┌───────────────┴────────────────┐
                 ▼                                ▼
          CAS 已有相同 SHA                    CAS 没有该 SHA
      upload_required=false              只上传/下载这个新 blob
```

因此“强制拉取”必须重新协商、校验并原子激活目标 Release，但不得绕过 CAS 把相同 SHA 的大 blob
再下载一次。服务器、publisher cache 和设备 cache 都以内容摘要为复用单位。

## 按变更频率拆层

凡是“小脚本经常改、大 npm 闭包很少改”的 Runtime Module，必须至少拆成两个签名 module：

1. 稳定依赖层：`kind=runtime_library`，用 `publisher_fetch` 固定 package、lockfile、exact version
   和 sha512 integrity；它包含 `node_modules`，但不能被直接当 CLI 启动。
2. 小执行层：`kind=cli` 或 `kind=local_mcp`，用 `inline_assets`/raw 或小 ZIP，只包含受审适配脚本；
   在 source descriptor 中用排序去重的 `runtime_dependencies` 引用稳定依赖层。
3. manifest 必须把两层绑定到同一员工、同一完整 Release。required consumer 不得依赖 optional
   library；optional consumer 在依赖层对当前目标不可用时必须一起省略。
4. 依赖路径只能由 Desktop Main 从同一已验证 Release 的 artifact root 计算，并通过
   `runtime-dependency-roots-v1` 注入隔离 host。脚本不得猜 `~/.yoodesk`、开发 checkout、全局 npm
   或另一个 Release 的路径；沙箱只增加这些精确只读根。
5. consumer 声明了 `runtime_dependencies` 后仍必须是 `inline_assets`。把 npm package 再放回
   consumer 会重新耦合两个变更域，validator 必须拒绝。

`runtime_library` 在这里是不可直接启动的只读依赖层。它被 supported typed CLI/stdio MCP 的
固定 host 消费，不代表桌面获得了任意 library execution、通用 Node import 或 shell 权限。

## 脚本单改验收

用同一 builder policy 和 cache 分别构建变更前、变更后 artifact set。只有适配脚本内容变化时，
必须同时证明：

- dependency blob 不变：dependency module 的 `module_digest`、目标 `blob_sha256`、
  `tree_sha256` 和 size 全部不变；
- consumer module digest 和目标脚本 blob 发生预期变化；
- consumer blob 足够小，且没有 `node_modules`、package tarball 或 package-manager 产物；
- publisher 对稳定 blob 的 `begin_runtime_blob_upload` 返回 `upload_required=false`，没有
  `upload_runtime_blob_chunk`；只对新脚本 blob发送 chunk；
- 桌面第二次 prepare 命中稳定 CAS，只下载新脚本 blob（只调用该 blob 的下载授权/下载）；随后仍校验完整
  release/module/resolved/blob/tree 闭包并原子切换；
- macOS host 的 dependency root 来自该 Release，适配脚本能解析到真实 CLI；缺少
  `runtime-dependency-roots-v1` 的旧客户端必须省略 optional consumer 或拒绝 required consumer，
  不能退回全局 `npx`；
- 设置页完整性同时报告 Runtime Module v2、typed CLI 与本地 stdio MCP 的存在/校验结果。

如果 package version、lockfile、integrity、平台依赖或 builder policy 改变，大依赖 blob 变化并传输
一次是正确行为。不能为了保住旧 SHA 跳过依赖更新。

## 运行态边界

- 新 Release 的 materialization 不热换已打开会话或 batch 的 lease；验收用新会话、新工具快照，
  批任务用新 batch。
- 聊天在 force sync 期间可以继续显示和排队，但新会话/新 runtime 启动必须等待原子切换；旧会话
  继续使用自己的冻结 Release，不能看到半新半旧目录。
- 不删除或编辑 `~/.yoodesk/custom-employees/assets`、CAS、active pointer 或
  `runtime-snapshot` 来制造命中或更新证据。
- Application、本地源码测试、服务端 active Release、桌面物化和真实工具调用是五个独立门；
  在 Application 跑顺前不要用 DMG 代替调试。
