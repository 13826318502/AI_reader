# 错误日志修复与作品详情角色卡片布局

- 日期：2026-08-26 14:18
- Agent：Codex（修复日志错误并优化角色卡片）

## 做了什么

- 读取已连接 PLS120 手机的应用错误记录，确认阅读正文底部溢出、角色详情图片右侧溢出 466px、新增角色 TextEditingController 提前释放，以及失效组件的焦点回调异常；保留历史错误日志，不通过清空日志掩盖问题。
- 角色图片使用明确的尺寸/比例约束：列表头像 72×96，详情头像 88×120，大图保持 3:4；长名字和简介限制显示行数，卡片高度随字体自然扩展。
- 作品详情角色区改为手机单列、宽屏双列，自适应可用宽度；标题、全部角色和新增入口合并排布，预览最多四位角色，其余通过全部角色查看。
- 新增角色弹窗改为独立 StatefulWidget，在 State.dispose 中释放输入控制器；图片选择完成后检查 mounted，防止关闭弹窗后的异步更新，并增加滚动及图片读取失败提示。焦点回调异常可能由先前弹窗异常连带触发，仍需真机完整操作验证。
- 阅读分页按真实正文行度量、换行、章节标题和系统字体缩放计算，使用真实视口减去页面内边距；分页边界保持完整 Unicode 字素，避免表情和代理对截断。
- 增加有容量和字符总量限制的分页缓存，降低重复打开章节时的排版开销；沉浸模式临时工具栏覆盖显示，不因展开工具栏反复改变正文分页；常驻工具栏仍占用布局高度。
- 新阅读进度、书签与插图锚点记录正文偏移，在重新排版时保持对应文本位置，同时兼容旧页码记录。图片页按剩余空间约束图片；翻页组件处理页数/初始位置变化与空页数。
- 修复删除书签后的异步 context 使用及已关闭书签面板的刷新回调。
- 按职责拆分原约 1200 行 reader.dart 为状态与正文、分页、布局、导航、书签、插图操作、模型和插图存储；拆分原 553 行 character_pages.dart 为角色列表、卡片、详情及大图页，并分离角色模型/存储/新增弹窗。当前这些页面文件均低于约 500 行，main.dart 只增加模块接入。
- 保留工作区原有及并行任务的关系图、世界设定、AI 配置与纸张纹理改动，这些不属于本记录实现范围；未进行 git commit/push。

## 更改的文件

- `lib/features/works/book_detail.dart:11`：使用独立角色区域，保留原有新增和存储流程。
- `lib/features/works/book_characters_section.dart:3`：自适应角色区域和预览数量控制。
- `lib/features/characters/character_card.dart:3`：角色卡尺寸、文字约束及点击入口。
- `lib/features/characters/character_detail_page.dart:3`：独立详情页，头像尺寸与可滚动大图弹窗。
- `lib/features/characters/character_card_page.dart:3`：独立角色大图页及图片比例。
- `lib/features/characters/character_pages.dart:3`：保留全部角色列表职责。
- `lib/features/characters/character_model.dart:3`：提取角色数据模型。
- `lib/features/characters/character_store.dart:3`：保留角色持久化和图片复制职责。
- `lib/features/characters/add_character_dialog.dart:3`：独立弹窗状态与安全释放、异步防护。
- `lib/features/reader/reader_pagination.dart:13`：真实文本分页、字素边界与有界缓存。
- `lib/features/reader/reader.dart:46`：视口分页、重新排版定位和正文/插图渲染。
- `lib/features/reader/reader_layout.dart:3`：阅读器页面和工具栏布局。
- `lib/features/reader/reader_bookmarks.dart:3`：书签及正文偏移持久化与异步保护。
- `lib/features/reader/reader_navigation.dart:3`：目录、偏好设置等导航及面板生命周期检查。
- `lib/features/reader/reader_image_actions.dart:3`：插图操作和文本位置锚点。
- `lib/features/reader/reader_models.dart:3`：阅读书签、扁平页及插图模型。
- `lib/features/reader/reader_image_store.dart:3`：提取插图持久化服务。
- `lib/core/models/work_models.dart:1`：将插图模型和存储移到阅读器模块。
- `lib/shared/reader_widgets.dart:145`：同步翻页组件状态并防护空页数。
- `lib/main.dart:13`：导入分页模块、接入拆分后的 part 文件。
- `test/widget_test.dart:1`：补充角色布局、弹窗生命周期、正文完整性及缩放分页回归测试。

## 验证

- 修改前回归测试复现角色图片越界、短段落/长标题导致的正文溢出；结构拆分后再次运行 format/analyze/test，保留相同失败用于确认拆分未改变行为。
- `dart format`：已格式化本次修改与拆分文件。
- `flutter analyze --no-pub`：无 error；当前共享工作区报告 44 项 warning/info（含并行任务与项目已有提示），并非零 lint。
- `flutter test --no-pub`：11 项测试通过。覆盖 0/1/5 位角色、320/360/768 宽度、2 倍字体卡片、弹窗退场期间控制器仍可用、9 组正文尺寸/缩放组合、正文拼接不丢字、工具栏/翻页及缩放后进度偏移保持。
- 约 318 万字、816 个章节的临时本地分页基准：行度量方案约 6.6 秒（冷排版、Windows Flutter 测试环境，不代表手机性能）；基准脚本位于忽略目录 build，未作为正式测试或产品文件提交。
- `flutter build apk --debug --no-pub`：最终调试 APK 构建成功，输出 `build/app/outputs/flutter-apk/app-debug.apk`。
- `git diff --check`：通过。
- 真机：已安装首轮修复包并确认能启动、进入作品详情。由于手机持续切换到其他应用，已停止输入操作；角色区最终截图、阅读器连续翻页及焦点异常的完整真机回归尚未完成。最终性能优化包已构建，尚未覆盖安装；没有将首轮安装当作最终包验证。

## 追加：用户确认安装（2026-08-26 14:19）

- 用户明确要求安装后，使用 `adb -s 3L1F9EE72MR3VRDE install -r build/app/outputs/flutter-apk/app-debug.apk` 将 14:17 构建的最终调试包覆盖安装到 PLS120；命令返回 `Success`。未卸载应用或清除数据。
- 比较本地 APK 与手机实际安装的 base.apk 的 SHA-256，完全一致：`2d4b3926546feee85b35bc3f33f2c2255dabdd2d5914cd81272f6453b78689ce`。
- Android 包信息确认：`com.arcglow.arc_reader`，版本 `1.0.0`，最后更新时间 `2026-08-26 14:19:36`。
- 无代码改动，仅追加本记录；未切换手机前台界面，也未将安装成功视为完整真机功能回归。
