# 仙侠作品测试数据直传

日期：2026-08-26

## 做了什么

- 创建并导入《九霄问道录》六章仙侠测试作品，包含九名角色。
- 通过手机已配置的图片生成 API 生成封面及四张角色图，并传入 APP 沙盒目录；其余角色复用角色图以控制调用次数。
- 直接更新 APP 的 SharedPreferences，写入地域、力量体系、时代设定及细分百科条目。
- 写入多中心人物关系数据，包含同一对角色的多重关系和交叉关系，用于验证复杂关系图。
- 未操作文件选择器或模拟手机点击；仅使用 ADB 数据传输和启动校验。

## 文件列表

- `review/xianxia_test_novel.txt:1`：测试小说文本。
- `review/generate_xianxia_images.ps1:1`：调用已配置图片 API 并下载测试图片。
- `review/prepare_xianxia_seed.ps1:1`：生成测试设定、角色、关系和 SharedPreferences 数据。
- `review/SeedPrefs.java:1`：编码 Flutter SharedPreferences 字符串列表。
- `review/xianxia_images/`：生成的封面和角色图片。

## 验证方式

- 5 张图片已通过 ADB 写入 `/data/user/0/com.arcglow.arc_reader/app_flutter/xianxia_images/`，文件大小与本地生成文件一致。
- SharedPreferences 已写入 `imported_works`、角色、关系和世界百科键。
- `adb shell monkey -p com.arcglow.arc_reader 1` 启动成功，当前 Activity 为 `com.arcglow.arc_reader/.MainActivity`。
- 最近日志未发现 APP 的 Flutter 异常或崩溃。
