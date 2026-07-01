import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/settings/theme_mode_switch.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  Widget wrap(Widget child, {ThemeMode themeMode = ThemeMode.system}) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider()..load(),
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('ThemeModeSwitch shows Dark mode label in dark theme',
      (tester) async {
    await tester.pumpWidget(
      wrap(const ThemeModeSwitch(), themeMode: ThemeMode.dark),
    );

    expect(find.text('Dark mode'), findsOneWidget);
    expect(find.text('Light mode'), findsNothing);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  testWidgets('ThemeModeSwitch shows Light mode label in light theme',
      (tester) async {
    await tester.pumpWidget(
      wrap(const ThemeModeSwitch(), themeMode: ThemeMode.light),
    );

    expect(find.text('Light mode'), findsOneWidget);
    expect(find.text('Dark mode'), findsNothing);
  });

  testWidgets('ThemeModeSwitch toggling on sets ThemeProvider to dark',
      (tester) async {
    await tester.pumpWidget(
      wrap(const ThemeModeSwitch(), themeMode: ThemeMode.light),
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final provider = tester
        .element(find.byType(ThemeModeSwitch))
        .read<ThemeProvider>();
    expect(provider.themeMode, ThemeMode.dark);
  });

  testWidgets('ThemeModeSwitch toggling off sets ThemeProvider to light',
      (tester) async {
    await tester.pumpWidget(
      wrap(const ThemeModeSwitch(), themeMode: ThemeMode.dark),
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final provider = tester
        .element(find.byType(ThemeModeSwitch))
        .read<ThemeProvider>();
    expect(provider.themeMode, ThemeMode.light);
  });
}
