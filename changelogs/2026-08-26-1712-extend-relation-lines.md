# 延长少量人物关系的连线距离

- 日期：2026-08-26 17:12
- Agent：Codex

## 做了什么

- 根据真机当前“洛棠—沈砚舟”页面，确认单条关系时节点间距不足。
- 对只有 1～2 个关系节点的布局采用更大的纵向半径，让连线更长、箭头和“爱人”等关系文字更容易辨认。
- 保持 3 个及以上关系节点的环形布局规则不变，避免多人物页面超出屏幕。

## 更改的文件

- `lib/features/characters/relations.dart:405-423`：按关系节点数量动态计算布局半径。

## 验证

- 真机读取当前关系图截图 `review/phone_relation_current.png` 作为调整依据。
- `dart format lib/features/characters/relations.dart`
- `flutter analyze --no-pub`：无 error；保留项目既有 warning/info。
- `flutter test --no-pub`：37 项测试全部通过。
