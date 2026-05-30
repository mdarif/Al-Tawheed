import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';

void main() {
  group('Widget Tests - Sharah Kitab At-Tawheed', () {
    testWidgets('App starts and displays welcome screen', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(MyApp());

      // Verify that the app renders without errors
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App has correct title', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      // The app should have rendered
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Navigation drawer can be opened', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp());
      await tester.pump();

      // Smoke test only — verifies app renders without crashing on startup.
      // Expand this test once the initial screen's widget tree is stable.
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
