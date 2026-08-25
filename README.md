# ARC Reader

ARC Reader 是一个基于 Flutter 的移动端 AI 小说阅读应用，面向本地小说导入、沉浸式阅读、作品设定浏览和 AI 图片创作场景。

项目采用本地优先设计：小说内容、阅读进度、书签、AI 服务配置和图片生成记录默认保存在设备本地，不依赖账号系统或自建后端即可运行。

## 功能概览

### 书架与作品管理

- 列表/网格查看作品，显示封面、章节数和阅读状态。
- 点击作品进入详情页，查看简介、章节目录和阅读进度。
- 详情页右上角三点菜单可以删除本地导入作品。
- 书架长按作品卡片可以删除本地导入作品。
- 内置示例作品仅用于演示，不允许删除。

### 本地作品导入

导入流程分为两个步骤：

1. 点击上方“选择本地文件”，选择 TXT 或 MD 文件。
2. 等待章节解析和预览完成后，点击下方“导入作品”确认保存。

导入页提供“取消导入”，可以取消当前待确认的文件选择并重新选择。确认后的作品会保存到本地，并映射到书架、作品详情、目录和阅读器。

支持的文本格式：

- `.txt`
- `.md`

章节标题支持常见中文格式，例如“第 1 章”“第一章”“第十二回”，也支持 `Chapter 1` 格式。无法识别章节标题时，整份文本会作为一个“正文”章节处理。

### 沉浸式阅读

- 应用启动时锁定竖屏，避免阅读过程中跟随传感器翻转。
- 进入阅读页默认隐藏标题和工具栏，点击正文后显示控制栏。
- 支持左右翻页和章节目录切换。
- 正文按页切分，超出当前页面的内容进入下一页，不使用正文区域内部滚动。
- 每个章节第一页显示章节编号和章节标题。
- 支持阅读进度、亮度调节、日间/夜间主题和阅读偏好。

### 书签与搜索

- 右上角菜单提供“添加书签”和“全局搜索”。
- 当前页添加书签后，菜单项变为“删除书签”。
- 已添加书签的页面右上角显示红色“书签”标记。
- 下拉阅读页面可以切换当前页书签状态。
- 目录的“书签”页支持长按删除，删除前会弹出确认框。
- 全局搜索初始不显示结果，输入关键词后搜索作品、章节和正文片段，并高亮关键词。

### AI 图片

- 阅读过程中的 AI 生图。
- 作品级 AI 图片集合。
- 场景、人物、物品三类图片分类。
- 根据参考图生成或从零生成。
- 角色头像和角色全身图生成。
- 本地图片导入到作品图片集合。
- 生成图片保存到设备的 `AI生成图片` 文件夹。
- 支持从文件管理器打开图片目录。

所有生图入口共用“我的 → AI 服务配置”中的 API 配置。生成结果支持图片 URL 和 Base64 响应；导入参考图后会读取图片字节并转换为带 MIME 类型的 Base64 Data URL，随参考图生成请求发送。

### AI 服务配置

配置页支持 Provider、API Base URL、API Key、模型名称、Seedream 4.5/4.0 模型选择、连通性测试、请求日志和 AI 图片缓存管理。

API Key 只应保存在本机配置中，不要写入源码、提交到 Git 或放进作品导出文件。

## 技术栈

- Flutter / Dart 3.9+
- Material 3
- `shared_preferences`：本地配置、导入作品、阅读状态和书签
- `file_picker`：选择小说和图片文件
- `http`：调用图片生成 API
- `path_provider`：管理 AI 图片目录
- `sqflite` / `archive`：为后续本地数据和数据管理能力预留

## 项目结构

```text
lib/
├─ main.dart                        # Flutter 启动入口
├─ app.dart                         # 应用主题和底部导航
├─ core/
│  ├─ app_theme.dart                # 主题色、浅色/深色模式
│  └─ common.dart                   # 公共导出和基础依赖
├─ models/
│  └─ imported_work.dart            # 导入作品和章节模型
├─ pages/
│  ├─ shelf_page.dart               # 书架
│  ├─ works_page.dart               # 本地作品导入
│  ├─ book_detail_page.dart         # 作品详情和目录
│  ├─ reader_page.dart              # 沉浸式阅读器
│  ├─ search_page.dart              # 全局搜索
│  ├─ ai_image_page.dart            # 阅读中的 AI 生图
│  ├─ book_ai_gallery_page.dart     # 作品 AI 图片集合和生成
│  ├─ characters_page.dart          # 角色与角色卡
│  ├─ worlds_page.dart              # 设定集/世界观
│  ├─ mine_page.dart                # 我的
│  ├─ ai_service_config_page.dart   # AI 服务配置
│  └─ reading_preferences_page.dart # 阅读偏好
├─ services/
│  └─ ai_services.dart              # AI 调用、图片缓存和请求日志
└─ widgets/
   └─ common_widgets.dart           # 公共 UI 组件
```

## 本地数据

当前本地保存：

- 最近一次确认导入的作品和章节正文。
- 当前作品的阅读章节和页码。
- 章节书签状态。
- AI Provider、Base URL、模型和 API Key。
- AI API 请求日志。
- AI 图片缓存目录中的生成图片。

当前导入模型以最近一次本地导入作品为主。后续如果需要同时管理多本导入作品，建议将 `latest_imported_work` 升级为作品列表或 SQLite 表结构。

## 开发与构建

检查环境并安装依赖：

```bash
flutter doctor
flutter pub get
```

运行开发版本：

```bash
flutter run
```

静态检查和测试：

```bash
flutter analyze
flutter test
```

构建 Android Debug APK：

```bash
flutter build apk --debug
```

APK 输出位置：

```text
build/app/outputs/flutter-apk/app-debug.apk
```

安装到已连接的 Android 手机：

```bash
adb devices
adb install -r -d --no-streaming build/app/outputs/flutter-apk/app-debug.apk
adb shell monkey -p com.arcglow.arc_reader 1
```

## AI API 配置

进入：

```text
我的 → AI 服务配置
```

填写 Provider、API Base URL、API Key 和图片模型名称，保存后先执行 API 测试，再从角色详情、阅读页或作品 AI 图片集合发起生成。

注意：

- 不要提交真实 API Key、Cookie、设备日志或个人文件。
- API 地址需要与图片生成接口格式匹配。
- Seedream 模型使用火山方舟图片生成接口。
- 参考图字段是否可用取决于服务商接口实现。
- 图片 URL 可能有有效期，应用会尝试将生成结果保存到本地缓存目录。

## 已知限制

- 当前是本地优先 MVP，暂未接入账号、云同步和服务端数据库。
- 当前本地导入以最近一次导入记录为主，尚未完成多作品数据库管理。
- 部分角色、世界观和关系图仍使用演示数据，需要后续接入导入作品的完整设定数据。
- 不同 AI 服务商对 Base URL、参考图字段和响应格式的要求可能不同。
- API Key 当前保存在本地偏好设置中，正式发布版本应迁移到系统安全存储。
- Android 打开图片目录依赖设备支持的文件管理应用。

## 设计原则

- 阅读优先：阅读页面默认保持沉浸和安静。
- 本地优先：没有账号也可以完成导入、阅读和状态保存。
- 原作与 AI 内容分离：AI 生成内容不覆盖原始小说正文。
- 可恢复操作：删除、取消导入和清理缓存都提供明确反馈。
- 统一配置：所有图片生成入口共享同一套 AI 服务配置。
- 移动端优先：页面布局以 Android 手机屏幕为主要验收环境。

## 相关文档

- [AI 看小说 APP 开发文档](AI看小说APP_开发文档.md)
- [起点读书参考与设计取舍](起点读书参考与设计取舍.md)
- [UI 目标稿目录](assets/ui_targets/)

## 提交安全

提交代码前请确认：

- 没有提交 API Key、Cookie、设备日志或个人文件。
- 没有提交 `build/`、`.dart_tool/` 等构建产物。
- 生成图片和本地小说文件不应直接提交到仓库。
