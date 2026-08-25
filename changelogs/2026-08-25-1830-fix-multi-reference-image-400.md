# 修复多参考图生图 400：多图改发字符串数组 + 日志记录详细错误

- 日期：2026-08-25 18:30
- Agent：opencode

## 做了什么

1. 排查：通过 adb 读取手机端 `FlutterSharedPreferences.xml` 中的 API 请求日志，确认最近生图全部返回 `HTTP 400`（模型 `doubao-seedream-4-5-251128`，火山方舟）。
2. 复现定位：用同一 API Key/URL 直接 curl 请求火山方舟接口——
   - 无参考图：HTTP 200 成功；
   - 单张参考图（`image` 为字符串）：成功；
   - 多张参考图（`image` 为 `[{"image","text"}]` 对象数组）：返回 `400 InvalidParameter: The parameter image specified in the request is not valid`；
   - 多张参考图改为**纯字符串数组** `["data:...","data:..."]`：HTTP 200 成功。
3. 修复 `AiImageService.generate`：多张参考图不再发送 `{"image","text"}` 对象数组，改为直接发送字符串数组（顺序即导入顺序）。
4. 改进请求日志：原来日志只记 `HTTP 400`，现改为同时保存接口返回的详细错误 message，便于以后排查。

## 更改的文件

- `lib/main.dart`：
  - `AiImageService.generate` 多参考图请求体构建（约 218-224 行）
  - `AiImageService.generate` 日志记录错误明细与 StateError 复用同一错误信息（约 265-300 行）

## 验证

- 通过 curl 直接对火山方舟接口验证：字符串数组格式返回 200 并生成图片。
- `flutter analyze`：0 error。
- 已重新构建 release APK 并 `adb install -r` 覆盖安装到手机（保留 App 数据）。
- 手动测试点：作品页「AI 生成图片 → 根据参考图生成」选择多张参考图后生成，应成功；失败时「API 请求日志」会显示接口返回的具体错误文字。
