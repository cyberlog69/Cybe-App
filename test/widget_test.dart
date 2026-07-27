import 'package:flutter_test/flutter_test.dart';
import 'package:cybe_app/main.dart';

void main() {
  testWidgets('CybeApp smoke test', (WidgetTester tester) async {
    // Build app widget
    await tester.pumpWidget(const CybeApp());
    expect(find.byType(CybeApp), findsOneWidget);
  });
}
