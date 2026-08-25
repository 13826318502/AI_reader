# AI 生成图片支持导入多张参考图

- 日期：2026-08-25 16:30
- Agent：opencode

## 做了什么

- 将作品级 AI 生图（`BookAiGeneratePage`）的参考图导入由单张改为多张：文件选择器开启 `allowMultiple`，多次选择可继续追加，并支持逐张删除。
- 参考图缩略图以 `Wrap` 网格展示，左上角显示按导入顺序的编号徽标（1、2、3…），右上角提供删除按钮，便于提示中按顺序引用图片（如“第一张图片的人物按照第二张图片的姿势”）。
- `AiImageService.generate` 的 `referenceBase64` 参数改为 `referenceImages`（`List<String>`）：
  - 单张参考图时沿用原格式 `body['image'] = <data url>`。
  - 多张参考图时按导入顺序发送为数组 `[{"image": <data url>, "text": "参考图N"}, ...]`，`text` 字段用于模型区分每张图片的次序。
- 界面新增使用提示文字，说明多张参考图按编号区分。
- 更新 README 中 AI 图片功能说明。

## 更改的文件

- `lib/main.dart:185`：`AiImageService.generate` 签名与多图请求体构建。
- `lib/main.dart:4389`：新增 `_ReferenceImage` 数据结构。
- `lib/main.dart:4402`：`_BookAiGeneratePageState` 参考图列表、`_pickReference` 多选追加、`_removeReference` 删除。
- `lib/main.dart:4452`：`_generate` 改为传入 `referenceImages` 列表。
- `lib/main.dart:4530`：参考图多图缩略图 UI 与使用提示。
- `lib/main.dart:4647`：新增 `_ReferenceThumb` 缩略图组件。
- `README.md:56`：功能说明更新。

## 验证

- `flutter analyze` 通过（0 error，仅存既有 info/warning，与本次改动无关）。
- 手动测试点：进入作品 AI 生成图片页 → 选“根据参考图生成”→ 一次选择多张图片，确认缩略图带顺序编号、可继续添加/删除；生成请求中单张走原 `image` 字段、多张走数组格式。
