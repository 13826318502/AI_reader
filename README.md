# AI Reader

一个基于 Flutter 的移动端 AI 小说阅读与创作工作室。

## 当前功能

- 本地 TXT / MD 小说导入
- 自动解析章节并显示真实章节数量
- 作品详情、目录和阅读器同步导入内容
- AI 生图配置与真实 API 测试
- Seedream 4.5 / 4.0 配置支持
- AI 生成图片保存到本机 `AI生成图片` 文件夹
- 支持从系统文件管理器或 MT 管理器打开图片目录
- 阅读主题、书签、搜索和作品管理

## 运行

```bash
flutter pub get
flutter run
```

构建 Android Debug APK：

```bash
flutter build apk --debug
```

## AI 图片配置

进入 `我的 → AI 服务配置`，填写自己的 API Key。Seedream 4.5 的模型 ID 和接口地址以火山方舟控制台当前显示为准。API Key 只在本机配置页面保存，不能提交到代码仓库。

## 项目文档

- [AI 看小说 APP 开发文档](AI看小说APP_开发文档.md)
- [起点读书参考与设计取舍](起点读书参考与设计取舍.md)

## 注意

本项目是本地优先的 Flutter MVP。跨设备同步、账号体系和服务端数据库尚未接入。
