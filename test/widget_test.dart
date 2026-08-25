import 'package:flutter_test/flutter_test.dart';
import 'package:arc_reader/main.dart';

void main() {
  testWidgets('阅读端显示书架入口', (tester) async {
    await tester.pumpWidget(const ArcReaderApp());
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('我的书架'), findsOneWidget);
  });
}
