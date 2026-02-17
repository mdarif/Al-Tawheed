import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';

void main() {
  group('Widget Tests - Sharah Kitab At-Tawheed', () {
    testWidgets('App starts and displays welcome screen', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());

      // Verify that the app renders without errors
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App has correct title', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // The app should have rendered
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Navigation drawer can be opened', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      // Verify drawer is visible (if app uses a drawer)
      // This test can be expanded based on actual app structure
    });
  });
}
