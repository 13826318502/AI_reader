import 'package:flutter/material.dart';
import 'billing_credentials_store.dart';
import 'billing_models.dart';

class BillingCredentialsPage extends StatefulWidget {
  const BillingCredentialsPage({super.key, this.store});
  final BillingCredentialsStore? store;
  @override
  State<BillingCredentialsPage> createState() => _BillingCredentialsPageState();
}

class _BillingCredentialsPageState extends State<BillingCredentialsPage> {
  late final store = widget.store ?? BillingCredentialsStore();
  final ak = TextEditingController();
  final sk = TextEditingController();
  bool busy = true;
  bool obscure = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await store.load();
      if (!mounted) return;
      ak.text = value?.accessKey ?? '';
      sk.text = value?.secretKey ?? '';
    } catch (value) {
      if (mounted) error = _message(value);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _message(Object value) =>
      value is BillingException ? value.message : '凭据操作失败，请重试。';

  Future<void> _save() async {
    final accessKey = ak.text.trim();
    final secretKey = sk.text.trim();
    if (accessKey.isEmpty ||
        secretKey.isEmpty ||
        accessKey.length > 256 ||
        secretKey.length > 512 ||
        RegExp(r'[^\x21-\x7e]').hasMatch(accessKey + secretKey)) {
      setState(() => error = '请完整填写 AK 和 SK，密钥内部不能有空格或换行。');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await store.save(BillingCredentials(accessKey, secretKey));
      if (mounted) Navigator.pop(context, true);
    } catch (value) {
      if (mounted) setState(() => error = _message(value));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await store.restorePrevious();
      if (!mounted) return;
      ak.text = value.accessKey;
      sk.text = value.secretKey;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已恢复并保存上一组费用查询凭据')));
    } catch (value) {
      if (mounted) setState(() => error = _message(value));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除费用查询凭据？'),
        content: const Text('会删除本机当前和上一组 AK / SK，不影响生图 API Key，也不会停用云端密钥。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await store.clear();
      if (mounted) Navigator.pop(context, true);
    } catch (value) {
      if (mounted) setState(() => error = _message(value));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    ak.dispose();
    sk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('费用查询凭据')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          '火山引擎 · 只读账单',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          '使用 IAM 子用户的 Access Key ID 和 Secret Access Key，不是方舟生图 API Key。请仅授予 BillingCenterReadOnlyAccess，不需要付款或管理员权限。',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: ak,
          enabled: !busy,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          decoration: const InputDecoration(
            labelText: 'Access Key ID（AK）',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: sk,
          enabled: !busy,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          decoration: InputDecoration(
            labelText: 'Secret Access Key（SK）',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: obscure ? '显示 SK' : '隐藏 SK',
              onPressed: () => setState(() => obscure = !obscure),
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton(onPressed: busy ? null : _save, child: const Text('加密保存')),
        OutlinedButton(
          onPressed: busy ? null : _restore,
          child: const Text('恢复上一组费用凭据'),
        ),
        TextButton(
          onPressed: busy ? null : _clear,
          child: const Text('清除本机费用凭据'),
        ),
        const SizedBox(height: 12),
        const Text(
          '个人设备直连模式\nAK / SK 使用 Android Keystore 加密保存，旧版当前及历史凭据将在首次打开此功能时迁移。SK 仅在本机参与签名，不发送给接口；签名请求只发往火山引擎官方域名。\n\n手机被 root 或受到恶意控制时仍有泄露风险。请勿填写主账号密钥或把自己的密钥分发给其他用户；多人使用应改为服务端保管凭据。\n\n这里只查询余额和账单，不会充值、购买或生成测试图片。',
          style: TextStyle(fontSize: 12, height: 1.6),
        ),
      ],
    ),
  );
}
