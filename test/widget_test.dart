import 'package:flutter_test/flutter_test.dart';
import 'package:marketing_dashboard/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TeamplyApp());
    expect(find.byType(TeamplyApp), findsOneWidget);
  });
}
