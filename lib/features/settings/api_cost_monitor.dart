part of '../../main.dart';

class ApiCostMonitorPage extends StatelessWidget {
  const ApiCostMonitorPage({super.key});
  @override
  Widget build(BuildContext context) => BillingMonitorPage(
    localEstimateBuilder: (_) => const LocalApiCostEstimatePage(),
  );
}
