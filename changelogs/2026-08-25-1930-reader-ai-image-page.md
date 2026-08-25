# 阅读器新增 AI 图片页：生图/图库导入插入当前小说

- 日期：2026-08-25 19:30
- Agent：opencode

## 做了什么

1. 阅读界面新增「AI 图片」入口（原「AI生图」工具栏按钮），点击弹出底部面板，两个操作：
   - **生成新图片并插入本书**：进入 `BookAiGeneratePage`（新增 `insertMode`），生成成功后直接返回图片路径给阅读页并插入为新的阅读页，不再跳转到图库页。
   - **从 AI 图片库导入**：进入 `BookAiGalleryPage`（新增 `pickMode`），点击任意一张图片即返回并插入为新的阅读页。
2. 插入的图片作为当前小说的一个独立阅读页：数据模型 `_ReaderFlatPage` 把正文页与插入的图片页统一拼成全局分页表，翻页可自然翻过图片页，图片页归属插入位置所在章节（章节标题/进度/书签跟随）。
3. 图片页持久化：新增 `_AiImagePageEntry` / `AiImagePageStore`，按书存储（`ai_image_pages_<书名>`），记录图片路径与插入锚点（位于哪一页正文之后）；插入位置以当前阅读页为锚点。
4. 图片页右上角提供删除图标，可移除该图片页（确认弹窗后跳回锚点正文页）。
5. 书签逻辑适配：图片页不支持添加书签；书签仍按（章节，正文页）定位，`_flatIndexOfTextPage` 处理插入图片后的全局页码映射。
6. flat 分页表加入缓存（`_flatCache`），图片页增删或作品加载时失效，避免每次构建重建全表。

## 更改的文件

- `lib/main.dart`：
  - 新增 `_AiImagePageEntry` / `AiImagePageStore`（约 3784-3843 行）
  - 新增 `_ReaderFlatPage`（约 1417-1435 行）
  - `_ReaderPageState`：分页模型重构、`_flatPages` 缓存、`_insertImagePage` / `_confirmRemoveImagePage` / `_showAiImageActions`、`_loadImagePages`（约 1450-1660 行）
  - `_buildPage` 渲染图片页（约 1700-1760 行）
  - `BookAiGeneratePage` 新增 `insertMode`（约 4650-4662 行，生成成功分支约 4595-4605 行）
  - `BookAiGalleryPage` 新增 `pickMode`，隐藏底部操作栏、图片可点击返回（约 4390-4440 行）
  - 阅读器工具栏「AI生图」改为「AI图片」并接入 `_showAiImageActions`

## 验证

- `flutter analyze`：0 error（仅 3 个既有 unused warning）
- `flutter test`：All tests passed
- 已构建 release APK（`build/app/outputs/flutter-apk/app-release.apk`）
- 手动测试点（手机连接后可测）：阅读页点「AI图片」→ 生成新图片或从图库选图 → 该图片作为新页插入当前位置；前后翻页可翻过图片页；图片页删除图标可移除；图片页不可加书签；正文书签/阅读进度不受影响。
