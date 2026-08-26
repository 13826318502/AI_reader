part of '../../main.dart';

Future<_WorkCharacter?> showAddCharacterDialog(BuildContext context) =>
    showDialog<_WorkCharacter>(
      context: context,
      builder: (_) => const _AddCharacterDialog(),
    );

class _AddCharacterDialog extends StatefulWidget {
  const _AddCharacterDialog();
  @override
  State<_AddCharacterDialog> createState() => _AddCharacterDialogState();
}

class _AddCharacterDialogState extends State<_AddCharacterDialog> {
  final _name = TextEditingController();
  String? _selectedImage;
  String? _imageError;
  bool _picking = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() {
      _picking = true;
      _imageError = null;
    });
    try {
      final image = await CharacterStore.pickAndCopyImage();
      if (!mounted) return;
      setState(() {
        if (image != null) _selectedImage = image;
      });
    } catch (error, stack) {
      await AppErrorLogStore.append(
        error: error,
        stack: stack,
        source: 'CharacterImagePicker',
      );
      if (!mounted) return;
      setState(() => _imageError = '图片读取失败，请重新选择');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('新增角色'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: '角色姓名 *'),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _picking ? null : _pickImage,
          icon: const Icon(Icons.image_outlined),
          label: Text(
            _picking
                ? '正在读取图片…'
                : _selectedImage == null
                ? '选择角色图片 *'
                : '重新选择图片',
          ),
        ),
        if (_imageError != null)
          Text(
            _imageError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_selectedImage != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 100,
              height: 120,
              child: AiImagePreview(image: _selectedImage!),
            ),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed:
            _name.text.trim().isEmpty || _selectedImage == null || _picking
            ? null
            : () => Navigator.pop(
                context,
                _WorkCharacter(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: _name.text.trim(),
                  role: '角色',
                  intro: '请在角色卡中补充角色资料。',
                  image: _selectedImage!,
                ),
              ),
        style: FilledButton.styleFrom(backgroundColor: gold),
        child: const Text('添加'),
      ),
    ],
  );
}
