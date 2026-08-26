# 接入火山引擎真实余额与月度账单

- 日期：2026-08-26 14:38
- Agent：Codex

## 做了什么

- “我的 → 费用监控”改为官方余额、最近 24 个月账单、分页加载和刷新入口；保留独立的“本机生图费用估算”页面，查询失败不回退成估算金额。
- 使用 `QueryBalanceAcct`（GET）与 `ListBillDetail`（POST，产品/月汇总），固定 HTTPS 官方域名、billing 服务和 cn-beijing 签名区域，禁止请求自动重定向。只实现查询，不调用生图、充值或购买接口。
- 以账户可见范围标注费用，说明可能包含其他产品/应用/关联账号和出账延迟。应付、已付、未付分开显示；金额使用 BigInt 十进制运算并按币种分别汇总，分页未完成明确显示小计，不把缺失金额当作零。
- 余额和账单各自处理错误，覆盖权限、签名/手机时间、限流、超时、服务异常和返回格式错误；不展示原始响应、凭据或签名。切换月份、刷新和退出页面时忽略过期异步结果。
- 项目无后端，本次实现个人 Android 设备直连模式。AK/SK 使用 Android Keystore AES-256-GCM 加密、AtomicFile 原子写入，密文放在 noBackupFilesDir；签名在本机计算，SK 不随 HTTP 请求发送。
- 首次打开费用页或费用凭据页时，将普通配置中的当前/上一组 AK/SK 迁入加密存储，写入并回读核对成功才删除旧值；失败不降级使用明文。支持恢复上一组及清除本机凭据；清除不影响生图 API Key，也能处理无法解密的旧文件。
- AI 服务配置中的 AK/SK 输入替换为独立费用凭据入口；拆出 API 测试流程和日志卡片，原页面缩减至约 400 行，生图配置恢复不再改动费用凭据。修复拆分涉及的异步回调 mounted 检查。
- 将既有传递依赖 crypto 3.0.7 声明为直接依赖。原锁文件要求 Dart >=3.12 / Flutter >=3.44，`flutter pub get` 按本机 Flutter 3.35.5 / Dart 3.9.2 重新解析为兼容版本；包含 SDK 固定依赖及平台插件的降级，不是新增无关依赖。

## 更改的文件

- `lib/features/billing/billing_models.dart:1`：凭据、精确金额、余额、分页账单模型。
- `lib/features/billing/volcengine_signer.dart:5`：火山引擎 HMAC-SHA256 V4 签名。
- `lib/features/billing/billing_service.dart:7`：只读余额和月度账单网络请求、分页校验及安全错误信息。
- `lib/features/billing/billing_credentials_store.dart:7`：串行凭据读写、迁移、恢复与清除。
- `lib/features/billing/billing_controller.dart:6`：刷新/分页/月份切换状态和独立错误处理。
- `lib/features/billing/billing_credentials_page.dart:5`：独立 AK/SK 配置、权限和风险说明。
- `lib/features/billing/billing_monitor_page.dart:6`、`lib/features/billing/billing_widgets.dart:5`：真实费用页面及展示组件。
- `android/app/src/main/kotlin/com/arcglow/arc_reader/BillingCredentialStore.kt:19`：Android 加密存储方法通道；IO/加密使用独立线程。
- `android/app/src/main/kotlin/com/arcglow/arc_reader/MainActivity.kt:16`：注册和释放凭据通道，保留原有文件管理器/音量键功能。
- `lib/features/settings/api_cost_monitor.dart:3`、`lib/features/settings/local_api_cost_estimate.dart:3`：官方费用入口和独立本机估算。
- `lib/features/settings/ai_service_config.dart:3`、`lib/features/settings/ai_connection_test.dart:3`、`lib/features/settings/api_request_logs_card.dart:3`：配置页拆分及费用入口迁移。
- `lib/features/settings/mine_page.dart:53`、`lib/main.dart:13`：入口文案及模块导入/part 注册。
- `pubspec.yaml:43`、`pubspec.lock:1`：crypto 直接依赖与本机 SDK 兼容锁文件。
- `test/billing_service_test.dart:1`、`test/billing_credentials_test.dart:1`、`test/billing_controller_test.dart:1`、`test/billing_signer_test.dart:1`、`test/fixtures/billing_signatures.json:1`：20 项费用相关测试及官方 SDK 签名向量。

## 验证

- 已运行拆分阶段 `dart format`、`flutter analyze --no-pub` 和测试。最初全量检查被另一个并行任务在途的角色页面编译错误阻断，已通知其负责人；该问题消除后重新运行全量检查。
- `flutter test --no-pub`：31 项全部通过（20 项新增费用测试 + 11 项既有测试）。覆盖精确金额/退款、小数精度、只读请求及固定目标、独立权限错误、空数据/异常数据、分页、超时、响应脱敏、凭据迁移失败/并发/清除、月份竞态、页面销毁、凭据保存/遮蔽、320 宽度及 1.6 倍字体布局。
- 两个签名向量由官方 Python SDK `volcengine==1.0.228` 的 `SignerV4` 在固定 UTC 时间和虚构 AK/SK 下生成，Dart GET/POST 签名逐字节一致；测试没有真实密钥或真实计费请求。
- `dart analyze lib/features/billing test/billing_service_test.dart test/billing_credentials_test.dart test/billing_controller_test.dart test/billing_signer_test.dart`：No issues found。
- `flutter analyze --no-pub`：无 error，保留项目其他模块现有 45 条 warning/info，因此全项目 analyze 退出码仍为 1；未宣称全项目零告警。
- `git diff --check`：通过，仅提示已有工作区文件的换行转换。
- `flutter build apk --debug --no-pub`：构建通过；最终复构建结果和交付包校验见下方补记。
- 未安装/操作用户手机，未做真实账户的成功查询、权限验证或 Android Keystore 的实机读写验证。使用前应在安装版中用仅有 BillingCenterReadOnlyAccess 的 IAM 子用户凭据核对控制台账单；不要在聊天中发送 SK。
- 未提交 git，未修改其他任务负责的角色/关系/世界设定/导航模块。

## 官方依据

- [QueryBalanceAcct](https://api.volcengine.com/api-explorer/debug?action=QueryBalanceAcct&serviceCode=billing&version=2022-01-01)
- [ListBillDetail](https://api.volcengine.com/api-docs/view?action=ListBillDetail&serviceCode=billing&version=2022-01-01)
- [费用中心权限](https://www.volcengine.com/docs/6269/1186807)
- [官方 Python 签名实现](https://github.com/volcengine/volc-sdk-python/blob/main/volcengine/auth/SignerV4.py)
- [Android Keystore 参数](https://developer.android.com/reference/android/security/keystore/KeyGenParameterSpec)

## 最终构建补记

- 最后一次代码调整后，全量 31 项测试再次通过；费用模块及四个费用测试文件静态检查 No issues found。
- 最终 `flutter build apk --debug --no-pub` 成功（assembleDebug 22.4s），复制固定交付包到 `build/app/outputs/flutter-apk/arc-reader-billing-debug.apk`，避免其他任务的后续构建覆盖交付文件。
- 交付包大小：171,559,615 bytes；SHA256：`ff73f6b2476c8cd5d3b906b6ba1c56bad12afabee9baed4318d0bf948b0972d1`。
- 安装和真实账户实测仍未执行；以上完成范围为代码、自动测试及 APK 构建。

## 用户授权安装补记（2026-08-26 14:41）

- 用户明确要求“给我安装”后，向已连接的 PLS120 手机执行 `adb install -r build/app/outputs/flutter-apk/arc-reader-billing-debug.apk`，返回 `Success`。
- 使用覆盖安装，未卸载或清除应用数据；未主动打开应用或操作手机其他页面。
- 安装后读取包信息：`com.arcglow.arc_reader`，versionName `1.0.0`、versionCode `1`，lastUpdateTime `2026-08-26 14:40:58`。
- 手机实际安装的 `base.apk` SHA256 与交付包一致：`ff73f6b2476c8cd5d3b906b6ba1c56bad12afabee9baed4318d0bf948b0972d1`，确认已安装此次费用功能版。
- 本次无代码改动，仅追加安装记录；真实账户费用查询仍待用户在应用中验证。
