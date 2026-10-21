import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/offline_status_banner.dart';
import 'package:provider/provider.dart';

void main() {
  Widget wrap({
    required bool downloadsEnabled,
    required bool isOffline,
  }) {
    final flags = FeatureFlagsProvider()
      ..setFeaturesJsonForTest({'downloads': downloadsEnabled});

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectivityProvider>(
          create: (_) => isOffline
              ? ConnectivityProvider.testOffline()
              : ConnectivityProvider.testOnline(),
        ),
        ChangeNotifierProvider<FeatureFlagsProvider>.value(value: flags),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          initialLocation: '/lectures',
          routes: [
            GoRoute(
              path: '/lectures',
              builder: (_, __) => const Scaffold(
                body: Column(
                  children: [
                    OfflineStatusBanner(),
                    Expanded(child: Center(child: Text('Lectures'))),
                  ],
                ),
              ),
            ),
            GoRoute(
              path: '/library',
              builder: (_, state) => Scaffold(
                body: Center(
                  child:
                      Text('Library tab=${state.uri.queryParameters['tab']}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('banner hidden when online', (tester) async {
    await tester.pumpWidget(wrap(downloadsEnabled: true, isOffline: false));
    await tester.pumpAndSettle();
    expect(find.byKey(WidgetKeys.offlineStatusBanner), findsNothing);
    expect(find.text('Offline'), findsNothing);
  });

  testWidgets('banner shown when offline and downloads enabled',
      (tester) async {
    await tester.pumpWidget(wrap(downloadsEnabled: true, isOffline: true));
    await tester.pumpAndSettle();
    expect(find.byKey(WidgetKeys.offlineStatusBanner), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
  });

  testWidgets('banner hidden when downloads feature off', (tester) async {
    await tester.pumpWidget(wrap(downloadsEnabled: false, isOffline: true));
    await tester.pumpAndSettle();
    expect(find.byKey(WidgetKeys.offlineStatusBanner), findsNothing);
    expect(find.text('Offline'), findsNothing);
  });

  testWidgets('tapping the banner opens Library > Downloads (IMP-05)',
      (tester) async {
    await tester.pumpWidget(wrap(downloadsEnabled: true, isOffline: true));
    await tester.pumpAndSettle();

    expect(find.text('View Library'), findsOneWidget);

    await tester.tap(find.byKey(WidgetKeys.offlineStatusBanner));
    await tester.pumpAndSettle();

    expect(find.text('Library tab=downloads'), findsOneWidget);
    expect(find.text('Lectures'), findsNothing);
  });

  testWidgets('"View Library" is not underlined (the chevron signals the tap)',
      (tester) async {
    await tester.pumpWidget(wrap(downloadsEnabled: true, isOffline: true));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text('View Library'));
    final decoration = text.style?.decoration;
    expect(decoration == null || decoration == TextDecoration.none, isTrue);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
  });

  testWidgets('the whole banner is a tap target at least 48dp tall',
      (tester) async {
    await tester.pumpWidget(wrap(downloadsEnabled: true, isOffline: true));
    await tester.pumpAndSettle();

    final banner = tester.getRect(find.byKey(WidgetKeys.offlineStatusBanner));
    expect(banner.height, greaterThanOrEqualTo(48));
    // …and the InkWell (what actually receives the tap) fills it.
    final ink = tester.getRect(
      find.descendant(
        of: find.byKey(WidgetKeys.offlineStatusBanner),
        matching: find.byType(InkWell),
      ),
    );
    expect(ink.height, greaterThanOrEqualTo(48));
    expect(ink.width, banner.width);
  });

  testWidgets('the label stays vertically centred in the taller target',
      (tester) async {
    await tester.pumpWidget(wrap(downloadsEnabled: true, isOffline: true));
    await tester.pumpAndSettle();

    final banner = tester.getRect(find.byKey(WidgetKeys.offlineStatusBanner));
    final label = tester.getRect(find.text('Offline'));
    expect(label.center.dy, closeTo(banner.center.dy, 1));
  });
}
