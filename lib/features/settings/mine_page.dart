part of '../../main.dart';

class Mine extends StatelessWidget {
  const Mine({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      const Text(
        'READER SETTINGS',
        style: TextStyle(
          color: gold,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
      const Text(
        '我的',
        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 18),
      card(
        Column(
          children: [
            ListTile(
              leading: const Icon(Icons.palette_outlined, color: gold),
              title: const Text('阅读偏好'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReadingPreferencesPage(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.key_outlined, color: gold),
              title: const Text('AI 服务配置'),
              subtitle: const Text(
                '配置 AI 生图 API',
                style: TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiServiceConfigPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined, color: gold),
              title: const Text('费用监控'),
              subtitle: const Text(
                '按 API 请求记录估算图片费用',
                style: TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ApiCostMonitorPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined, color: gold),
              title: const Text('错误日志'),
              subtitle: const Text(
                '记录错误原因、堆栈和发生位置，便于 agent 定位',
                style: TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppErrorLogPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.storage_outlined, color: gold),
              title: const Text('数据管理'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DataManagementPage()),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
