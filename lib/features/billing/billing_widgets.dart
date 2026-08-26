import 'package:flutter/material.dart';
import 'billing_controller.dart';
import 'billing_models.dart';

class BillingNotice extends StatelessWidget {
  const BillingNotice(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(message, style: const TextStyle(height: 1.5)),
  );
}

String _time(DateTime time) {
  String two(int v) => v.toString().padLeft(2, '0');
  final t = time.toLocal();
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

class BillingBalanceCard extends StatelessWidget {
  const BillingBalanceCard({
    super.key,
    required this.balance,
    required this.updated,
  });
  final BillingBalance balance;
  final DateTime updated;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('账户可用余额', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '${balance.currency} ${balance.available}',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('现金余额：${balance.currency} ${balance.cash}'),
          Text('欠费金额：${balance.currency} ${balance.arrears}'),
          const SizedBox(height: 8),
          Text('查询时间：${_time(updated)}', style: const TextStyle(fontSize: 11)),
        ],
      ),
    ),
  );
}

class BillingSummaryCard extends StatelessWidget {
  const BillingSummaryCard({super.key, required this.controller});
  final BillingController controller;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.page!.hasMore ? '已加载账单 · 应付小计' : '已返回账单 · 应付合计',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          ...controller.payableByCurrency.entries.map(
            (entry) => Text(
              '${entry.key} ${entry.value}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          if (controller.rows.isEmpty) const Text('暂无金额'),
          const SizedBox(height: 8),
          Text(
            '已加载 ${controller.rows.length} 条${controller.page!.total >= 0 ? ' / 共 ${controller.page!.total} 条' : ''} · 按产品 / 月汇总',
          ),
          const Text(
            '应付、已付、未付分别显示，不将折后金额或本地估算当作实际扣款。',
            style: TextStyle(fontSize: 11, height: 1.5),
          ),
          if (controller.billsUpdated != null)
            Text(
              '查询时间：${_time(controller.billsUpdated!)}',
              style: const TextStyle(fontSize: 11),
            ),
        ],
      ),
    ),
  );
}

class BillingRowCard extends StatelessWidget {
  const BillingRowCard({super.key, required this.row});
  final BillingRow row;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.product,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (row.category.isNotEmpty)
            Text(row.category, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 8),
          Text('应付：${row.currency} ${row.payable}'),
          Text('已付：${row.currency} ${row.paid}'),
          Text('未付：${row.currency} ${row.unpaid}'),
        ],
      ),
    ),
  );
}
