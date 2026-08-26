# 修复继续阅读卡顿 / ANR 与作品原文件定位

- 日期：2026-08-26 15:08
- Agent：Codex

## 定位依据

- 手机 `dumpsys activity exit-info com.arcglow.arc_reader` 显示 14:54:32 进程退出原因是 ANR：触摸事件等待约 5001ms 后用户关闭应用；并非普通 Dart 异常。
- 仅在内存中解析作品数据并输出统计：816 章、3,712,054 字符，最长章 8,389 字符；没有输出或落盘完整偏好配置、密钥或小说正文。
- 阅读器原来在 `_init` / LayoutBuilder 内同步排完整本书；详情页每次 build 拼接整本正文。原文件栏只有图标，没有点击处理，导入数据也未保存来源 URI。

## 做了什么

- 阅读器改成当前章优先、预排相邻章，其余章节按需排版。初始化和尺寸/字号变更不再同步遍历全书排版，过期或已退出页面的任务会取消。
- 单次原生文字排版使用约 4096 UTF-16 单元的窗口，窗口在完整字素边界截取；保留末页用于续接，避免跨窗口丢字、拆坏 emoji 或截断换行。异步批次之间让出事件循环。
- 保留真实文字度量、标题占高和文本偏移阅读锚点。尚未排版的章节显示排版状态，不保存占位页为阅读进度；旧书签在对应章完成后恢复，跳转后记录正确章节和页码。
- 阅读进度按正文字符位置计算，不用尚未完成的占位页数量伪造全书页数。旧图片的全书页号锚点需要完整索引时，改为异步补齐后映射；新图片沿用章节/文本偏移锚点。
- 拆出 `reader_loading.dart` 负责加载、分页调度和位置恢复，阅读主文件保持约 300 行。增加加载/排版失败提示与重试，不清除作品和进度。
- 将作品持久化从模型文件拆出。大于约 64KB 的 JSON 集合在 isolate 解析，缓存相同数据的解析结果，避免详情 → 阅读重复解析所有作品；保存时 JSON 编码也放入 isolate。
- 作品详情只截取简介所需前 220 字，字数通过章节长度求和，不再拼接 371 万字正文。
- 导入时保存 FilePicker 返回的原文档 `identifier`（不是缓存路径），申请持久只读访问权限；模型的保存/恢复/复制保留 `sourceUri`。
- 新增可点击的本地文件组件及“打开所在文件夹 / 关联原文件 / 重新关联”。旧记录明确提示缺少来源；用户选择同名原文件后只关联位置，不替换正文、封面或阅读进度。
- Android 独立文件定位通道在工作线程检查文档是否存在/是否有权限，再通过系统文件浏览器 `ACTION_OPEN_DOCUMENT + EXTRA_INITIAL_URI` 定位文件父目录。不存在或授权失效会明确提示，不静默打开无关目录。此功能需要 Android 8+；其他平台明确提示不支持。

## 更改的文件

- `lib/features/reader/reader.dart:12`：分页状态、占位页、任务取消与图片锚点兼容。
- `lib/features/reader/reader_loading.dart:3`：独立加载与按需分页调度。
- `lib/features/reader/reader_pagination.dart:13`：分块排版、异步取消及更小的缓存上限。
- `lib/features/reader/reader_layout.dart:3`：非阻塞排版接入、阅读进度和错误重试。
- `lib/features/reader/reader_bookmarks.dart:3`、`lib/features/reader/reader_navigation.dart:3`：旧书签延迟投影和正确的跳转/进度保存。
- `lib/features/reader/reader_image_actions.dart:73`：尚未排版时不插入错误锚点的图片。
- `lib/core/models/work_models.dart:9`、`lib/core/imported_work_store.dart:3`：模型/存储拆分，来源 URI、isolate 编解码和解析缓存。
- `lib/core/services/source_file_service.dart:4`：原文件定位与权限桥接服务。
- `lib/features/works/book_detail.dart:153`、`lib/features/works/book_source_file.dart:3`：简介性能优化和可操作的文件位置组件。
- `lib/features/works/works.dart:51`：导入保存真实来源 URI。
- `android/app/src/main/kotlin/com/arcglow/arc_reader/SourceFileNavigator.kt:14`：文档来源权限检查与文件浏览器定位。
- `android/app/src/main/kotlin/com/arcglow/arc_reader/MainActivity.kt:17`：注册/释放文件定位通道，保留费用密钥/文件管理器/音量键原有通道。
- `lib/main.dart:2`：仅增加 imports / parts，无新业务堆入入口文件。
- `test/widget_test.dart:1`：扩展现有测试，新增缓存/来源保存、超长章节完整性及取消、816章按需排版、旧书签跳转和原文件入口测试。

## 验证

- 拆分后已运行 `dart format`、`flutter analyze --no-pub` 和现有相关测试。测试初期遇到 isolate 与 widget fake-async 调度差异，调整小数据解析与已解析缓存，并在大书测试中显式等待真实 isolate 工作；未以关闭生产 isolate 绕过测试。
- `flutter test --no-pub`：最终 37 项全部通过（此前 31 项 + 本次 6 项），包括费用功能回归。
- 816章约数百万字测试从第401章偏移1500开始，只发生少于30次有界原生排版调用，未全书排版；既有阅读位置保留。
- 超长章节测试完整重组正文、检查字素边界并验证取消。既有不同宽度/字号、真实换行、标题占高和翻页测试通过。
- 旧书签跳转到尚未排版的第9章第3页后，保存的章节为9、页索引为2。
- 原文件入口测试验证旧记录要求用户关联，已有关联时传递原始文档 URI；缓存和保存测试验证原文、封面和来源不丢失。
- `flutter analyze --no-pub`：无 error；仍有 52 条 warning/info（含既有私有模型 API、弃用和样式提示），退出码为1，不宣称零告警。
- `git diff --check`：通过，仅工作区既有 CRLF 转换提示。
- 中间 APK 构建成功，最终复构建、交付和安装状态见后续补记。
- 尚未获得短暂操作手机页面的回复，未自动点击用户手机或选择原文件；真实性能耗时、厂商文件浏览器对定位参数的支持仍须实机验证。不要将测试结果写成实机已无 ANR。
- 未提交 git；未修改其他任务的角色/世界设定代码。

## 平台依据

- [Android 文档访问与持久权限](https://developer.android.com/training/data-storage/shared/documents-files)
- [EXTRA_INITIAL_URI：文件 URI 对应父目录作为初始位置](https://developer.android.com/reference/android/provider/DocumentsContract#EXTRA_INITIAL_URI)

## 最终交付 / 安装补记（15:10）

- 最终复构建成功：`flutter build apk --debug --no-pub`，assembleDebug 26.4s。
- 固定交付副本：`build/app/outputs/flutter-apk/arc-reader-reading-fix-debug.apk`；SHA256 `63b4b9e5a2289eb491a2d241f4e3037f0d58dfdde9498db8ea5dd977d7efe4d3`。
- 延续此前覆盖安装流程，向已连接 PLS120 安装修复版。首次安装因 USB 断开失败；重新连接后重试 `adb install -r` 返回 Success。
- 读取手机安装包 `base.apk` 的 SHA256，与交付副本完全一致；lastUpdateTime `2026-08-26 15:10:18`，versionName `1.0.0`。
- 未卸载、清除应用数据或改动用户原文件；未自动打开/点击手机页面。安装校验通过不等于已完成真实阅读耗时和系统文件浏览器定位的实机验证，仍需用户实际操作确认。
