# 修复错误日志、清理历史和多关系线

日期：2026-08-26

## 做了什么

- 根据手机错误日志定位并修复设定集编辑弹窗关闭动画期间提前释放 `TextEditingController` 的问题，避免“controller 已释放”“错误 build scope”和依赖残留异常。
- 数据管理中的“清空阅读记录”改为“清理历史”，一次清理阅读记录、API 请求历史和错误日志历史，并增加确认提示。
- 同一对角色的多条关系线间距从 16 调整为 30，关系标签改为沿各自关系线居中，减少线条和文字重叠。

## 更改文件

- `lib/features/worlds/worlds.dart:509`：延后设定编辑控制器释放。
- `lib/features/settings/data_management.dart:67`：合并历史清理逻辑和界面文案。
- `lib/features/characters/relations.dart:623-642`：分离多关系线及标签。

## 验证方式

- 从手机 SharedPreferences 中读取并分析了 3 条实际 Flutter 错误日志。
- `flutter analyze`：无 error。
- `flutter test`：37 项全部通过。
- `flutter build apk --debug`：构建成功。
- APK 已安装到手机，`MainActivity` 启动成功。
