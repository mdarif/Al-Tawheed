import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/settings/playback_speed_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap({Locale? locale}) => MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PlayerNotifier(
            TawheedAudioHandler(),
            ProgressProvider(),
            DownloadsProvider(),
            ConnectivityProvider.testOnline(),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: PlaybackSpeedSelector()),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  group('speed chips', () {
    testWidgets('Arabic chrome writes the speeds in Arabic', (tester) async {
      await tester.pumpWidget(_wrap(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      // Arabic writes 1.5 as ١٫٥ — the decimal separator (U+066B) differs too,
      // and ١.٥ would read as a half-translated string.
      expect(find.text('٠٫٧٥x'), findsOneWidget);
      expect(find.text('١٫٠x'), findsOneWidget);
      expect(find.text('١٫٢٥x'), findsOneWidget);
      expect(find.text('٢٫٠x'), findsOneWidget);
      expect(find.text('1.0x'), findsNothing);
    });

    // The Urdu edition's default chrome. Untouched by the Arabic work.
    testWidgets('English chrome keeps the Western speeds', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('0.75x'), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);
      expect(find.text('2.0x'), findsOneWidget);
    });

    // Urdu keeps '.' as its decimal separator — only the digits change.
    testWidgets('Urdu chrome localizes the digits but not the separator',
        (tester) async {
      await tester.pumpWidget(_wrap(locale: const Locale('ur')));
      await tester.pumpAndSettle();

      expect(find.text('۱.۲۵x'), findsOneWidget);
      expect(find.text('۲.۰x'), findsOneWidget);
    });
  });
}
