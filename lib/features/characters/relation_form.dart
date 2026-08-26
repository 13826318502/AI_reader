part of '../../main.dart';

Future<_CharacterRelation?> showAddRelationDialog({
  required BuildContext context,
  required String fromName,
  required String fromImage,
}) => showDialog<_CharacterRelation>(
  context: context,
  builder: (dialogContext) =>
      _AddRelationDialog(fromName: fromName, fromImage: fromImage),
);

class _AddRelationDialog extends StatefulWidget {
  final String fromName;
  final String fromImage;

  const _AddRelationDialog({required this.fromName, required this.fromImage});

  @override
  State<_AddRelationDialog> createState() => _AddRelationDialogState();
}

class _AddRelationDialogState extends State<_AddRelationDialog> {
  final toName = TextEditingController();
  final relation = TextEditingController();

  @override
  void dispose() {
    toName.dispose();
    relation.dispose();
    super.dispose();
  }

  void _submit() {
    final target = toName.text.trim();
    final label = relation.text.trim();
    if (target.isEmpty || label.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写对方角色和关系说明')));
      return;
    }
    if (target == widget.fromName) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('对方角色不能与当前角色相同')));
      return;
    }
    Navigator.pop(
      context,
      _CharacterRelation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        fromName: widget.fromName,
        fromImage: widget.fromImage,
        toName: target,
        toImage: 'assets/ai_portrait.png',
        relation: label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('手动添加角色关系'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前角色：${widget.fromName}'),
          const SizedBox(height: 14),
          TextField(
            controller: toName,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '对方角色',
              hintText: '例如：顾长安',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: relation,
            decoration: const InputDecoration(
              labelText: '关系说明',
              hintText: '例如：朋友、师徒、宿敌',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('添加关系')),
    ],
  );
}
