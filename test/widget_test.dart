// Widget tests for Al-Tawheed V2.
// MyApp requires async AudioService init, so these tests target
// individual screens wrapped in a minimal MaterialApp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/screens/welcome.dart';
import 'package:myapp/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: child,
    );

void main() {
  group('Widget Tests - Sharah Kitab At-Tawheed', () {
    testWidgets('App starts and displays welcome screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(WelcomeScreen()));
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Welcome screen has correct title',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(WelcomeScreen()));
      expect(find.textContaining('Sharah Kitab'), findsOneWidget);
    });

    testWidgets('Welcome screen has START LISTENING button',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(WelcomeScreen()));
      expect(find.text('START LISTENING'), findsOneWidget);
    });
  });
}
