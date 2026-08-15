import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cybe_app/core/widgets/cybe_logo.dart';

void main() {
  group('CybeLogo Widget Tests', () {
    testWidgets('renders CybeLogo.appBar with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: CybeLogo.appBar(),
            ),
          ),
        ),
      );

      expect(find.text('CYBE'), findsOneWidget);
      expect(find.byIcon(Icons.security_rounded), findsOneWidget);
    });

    testWidgets('renders CybeLogo.hero with title and subtitle', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CybeLogo.hero(
              title: 'CYBE',
              subtitle: 'SECURITY SUITE',
            ),
          ),
        ),
      );

      expect(find.text('CYBE'), findsOneWidget);
      expect(find.text('SECURITY SUITE'), findsOneWidget);
      expect(find.byIcon(Icons.security_rounded), findsOneWidget);
    });

    testWidgets('renders CybeLogo.iconOnly without text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CybeLogo.iconOnly(),
          ),
        ),
      );

      expect(find.text('CYBE'), findsNothing);
      expect(find.byIcon(Icons.security_rounded), findsOneWidget);
    });
  });
}
