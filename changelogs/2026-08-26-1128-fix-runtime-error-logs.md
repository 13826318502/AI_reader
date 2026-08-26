# 修复运行时错误日志中的问题

- 日期：2026-08-26 11:28
- Agent：Codex

## 做了什么

- 根据真机错误日志定位并修复 Flutter 启动时的 `Zone mismatch`，将 binding 初始化、错误处理和 `runApp` 放入同一个 zone。
- 将标签输入弹窗改为自管理 `TextEditingController` 的 StatefulDialog，避免弹窗退出动画期间继续使用已释放的 controller，并解决关闭弹窗后的失效 widget 焦点回调。
- 为标签弹窗增加最大高度和内部滚动，避免键盘弹出、已有标签较多时出现底部 `RenderFlex overflow`。
- 保留原有错误日志记录能力，便于后续继续收集真实问题。

## 更改的文件

- `lib/main.dart`：修复启动 zone、标签弹窗 controller 生命周期和弹窗布局溢出。
- `changelogs/2026-08-26-1128-fix-runtime-error-logs.md`：记录错误定位与验证结果。

## 验证

- `flutter analyze --no-pub`：无编译错误；仅保留项目既有 lint/deprecation 提示。
- `flutter test --no-pub`：全部测试通过。
- `flutter build apk --debug`：构建成功。
- 已安装到 `PLS120` 真机，进入“我的 → 阅读偏好”并滚动设置页面，ADB 日志未出现 `Zone mismatch`、`RenderFlex overflow`、`Failed assertion` 或崩溃。
