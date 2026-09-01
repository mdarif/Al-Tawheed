import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/widgets/missing_edition_guard.dart';

Widget _wrap({
  required SeriesProvider series,
  String initialLocation = '/lectures',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/lectures',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Lectures'))),
      ),
      GoRoute(
        path: '/edition-missing',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Edition missing'))),
      ),
    ],
  );
  return MultiProvider(
    providers: [ChangeNotifierProvider.value(value: series)],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MissingEditionGuard(
        router: router,
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  testWidgets(
      'auto-navigates away from /lectures once the saved edition goes '
      'missing — not just from Welcome', (tester) async {
    // A returning user already sitting on /lectures (the common case — most
    // returning users never see WelcomeScreen at all), whose saved edition
    // then turns out not to be in the manifest.
    await PreferencesService.instance.saveSelectedSeriesId('tawheed-ar');
    final series = SeriesProvider()..load(true, definitive: true);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();
    expect(find.text('Lectures'), findsOneWidget);
    expect(find.text('Edition missing'), findsNothing);

    // Manifest fetch completes without the saved edition (BLK-06).
    await series.loadManifest();
    await tester.pumpAndSettle();

    expect(find.text('Edition missing'), findsOneWidget);
    expect(find.text('Lectures'), findsNothing);
    expect(series.selectedSeriesId, 'tawheed-ar');
  });

  testWidgets('does not navigate away when the saved edition resolves fine',
      (tester) async {
    await PreferencesService.instance.saveSelectedSeriesId('tawheed-ur');
    final series = SeriesProvider()..load(true, definitive: true);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    await series.loadManifest();
    await tester.pumpAndSettle();

    expect(find.text('Lectures'), findsOneWidget);
    expect(find.text('Edition missing'), findsNothing);
  });
}
