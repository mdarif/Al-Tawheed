import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/settings/theme_mode_selector.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.init();
  });

  Widget wrap(Widget child) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider()..load(),
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('ThemeModeSelector shows Light, Dark, and System options',
      (tester) async {
    await tester.pumpWidget(wrap(const ThemeModeSelector()));

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
  });

  testWidgets('ThemeModeSelector updates ThemeProvider on tap',
      (tester) async {
    await tester.pumpWidget(wrap(const ThemeModeSelector()));

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    final provider = tester
        .element(find.byType(ThemeModeSelector))
        .read<ThemeProvider>();
    expect(provider.themeMode, ThemeMode.light);
  });
}
