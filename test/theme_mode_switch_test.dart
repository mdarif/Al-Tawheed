import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await PreferencesService.instance.init();
  });

  Widget wrap(Widget child, {ThemeMode themeMode = ThemeMode.dark}) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider()..load(),
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('ThemeModeSwitch shows current mode label and adaptive switch',
      (tester) async {
    await tester.pumpWidget(
      wrap(const ThemeModeSwitch(), themeMode: ThemeMode.dark),
    );

    expect(find.text('Dark mode'), findsOneWidget);
    expect(find.text('Light mode'), findsNothing);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  testWidgets('ThemeModeSwitch shows Light mode when light theme is active',
      (tester) async {
    await tester.pumpWidget(
      wrap(const ThemeModeSwitch(), themeMode: ThemeMode.light),
    );

    expect(find.text('Light mode'), findsOneWidget);
    expect(find.text('Dark mode'), findsNothing);
  });

  testWidgets('ThemeModeSwitch toggles ThemeProvider to light',
      (tester) async {
    await tester.pumpWidget(wrap(const ThemeModeSwitch()));

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final provider = tester
        .element(find.byType(ThemeModeSwitch))
        .read<ThemeProvider>();
    expect(provider.themeMode, ThemeMode.light);
  });
}
