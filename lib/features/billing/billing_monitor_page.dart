import 'package:flutter/material.dart';
import 'billing_controller.dart';
import 'billing_credentials_page.dart';
import 'billing_widgets.dart';

class BillingMonitorPage extends StatefulWidget {
  const BillingMonitorPage({
    super.key,
    required this.localEstimateBuilder,
    this.controller,
  });
  final WidgetBuilder localEstimateBuilder;
  final BillingController? controller;
  @override
  State<BillingMonitorPage> createState() => _BillingMonitorPageState();
}

class _BillingMonitorPageState extends State<BillingMonitorPage> {
  late final controller = widget.controller ?? BillingController();

  @override
  void initState() {
    super.initState();
    controller.refresh();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _configure() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BillingCredentialsPage(store: controller.store),
      ),
    );
    if (mounted) await controller.refresh();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('费用监控'),
        actions: [
          IconButton(
            tooltip: '刷新官方费用',
            onPressed: controller.loading ? null : () => controller.refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.refresh(),
        child: ListView(
          padding: const EdgeInsets.all(18),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const Text(
              '火山引擎官方账单',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '这里显示 AK 所属账户可见的费用，可能包含其他应用、产品或关联账号，并非本 APP 专属费用。账单更新有延迟，当月数据不是最终结算结果。',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: controller.loading || controller.loadingMore
                  ? null
                  : _configure,
              icon: const Icon(Icons.key_outlined),
              label: const Text('配置费用查询 AK / SK'),
            ),
            if (controller.loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const Text('正在查询官方数据…'),
            ],
            if (controller.credentialError != null)
              BillingNotice(controller.credentialError!),
            if (!controller.loading &&
                !controller.configured &&
                controller.credentialError == null)
              const BillingNotice(
                '尚未配置完整的费用查询凭据。填写 AK / SK 后即可查询；生图 API Key 不能替代。',
              ),
            if (controller.balanceError != null)
              BillingNotice('余额查询失败\n${controller.balanceError}'),
            if (controller.balance != null)
              BillingBalanceCard(
                balance: controller.balance!,
                updated: controller.balanceUpdated!,
              ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: controller.month,
              decoration: const InputDecoration(
                labelText: '账期（最近 24 个月）',
                border: OutlineInputBorder(),
              ),
              items: controller.months
                  .map(
                    (month) =>
                        DropdownMenuItem(value: month, child: Text(month)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) controller.refresh(selectedMonth: value);
              },
            ),
            const SizedBox(height: 12),
            if (controller.billError != null)
              BillingNotice('账单查询失败\n${controller.billError}'),
            if (controller.page != null) ...[
              BillingSummaryCard(controller: controller),
              if (controller.hasWarning)
                const BillingNotice('官方接口提示部分查询条件被忽略或调整，请在费用中心核对汇总口径。'),
              if (controller.rows.isEmpty)
                const BillingNotice('该账期暂未返回账单记录，不代表没有消费。请考虑出账延迟并在费用中心核对。'),
              ...controller.rows.map((row) => BillingRowCard(row: row)),
              if (controller.page!.hasMore)
                OutlinedButton(
                  onPressed: controller.loadingMore
                      ? null
                      : controller.loadMore,
                  child: Text(
                    controller.loadingMore
                        ? '正在加载…'
                        : controller.billError == null
                        ? '加载更多账单'
                        : '重试加载更多',
                  ),
                ),
            ],
            if (controller.billError != null &&
                controller.page == null &&
                !controller.loading)
              OutlinedButton(
                onPressed: () => controller.refresh(),
                child: const Text('重试查询'),
              ),
            const SizedBox(height: 18),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('本机生图费用估算'),
              subtitle: const Text('独立的请求数 × 手动单价，不是官方账单'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: widget.localEstimateBuilder),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
