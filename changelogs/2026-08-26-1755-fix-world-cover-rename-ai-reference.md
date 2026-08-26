# 设定集、作品改名与 AI 参考图功能

日期：2026-08-26

## 做了什么

- 设定集作品选择列表改为显示作品真实封面，和书架、作品详情保持同步。
- 书架长按作品新增“更改小说名字”，并迁移角色、世界设定、阅读进度、书签和阅读器图片页等按书名保存的数据；AI 图片归属也同步改名。
- AI 生图结果不再使用请求 prompt 作为图片名称，统一显示为“AI生成图片”。
- 上传参考图新增“从 AI 生图导入”，可直接从当前作品的 AI 图片库选择生成图片作为参考图；选择模式会显示该作品的全部 AI 图片分类。

## 更改文件

- `lib/core/models/work_models.dart:25`：作品模型支持修改标题。
- `lib/core/imported_work_store.dart:78`：作品改名及关联数据迁移。
- `lib/features/worlds/worlds.dart:171`：设定集显示作品封面。
- `lib/features/shelf/shelf.dart:150`：长按改名入口及改名对话框。
- `lib/features/ai/ai_gallery.dart:70`：AI 图片标签和改名同步；参考图选择模式显示全部分类。
- `lib/features/ai/ai_generate.dart:29`：从 AI 图片库导入参考图。

## 验证方式

- `flutter analyze`：无 error。
- `flutter test`：37 项全部通过。
- `flutter build apk --debug`：构建成功。
- APK 已安装到 Android 手机，`MainActivity` 启动成功。
