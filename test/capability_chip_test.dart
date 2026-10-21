import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/capability_chip.dart';

Widget _host({
  required Locale locale,
  required double width,
  double textScale = 1,
  required Widget child,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: Align(
        alignment: AlignmentDirectional.topStart,
        // A width an edition-switcher row can hand a chip on a small phone.
        // Align loosens the slot's tight width, as Wrap does for its chips.
        child: SizedBox(
          width: width,
          child: Align(alignment: AlignmentDirectional.topStart, child: child),
        ),
      ),
    ),
  );
}

void main() {
  group('CapabilityChip', () {
    testWidgets('renders its icon and label', (tester) async {
      await tester.pumpWidget(
        _host(
          locale: const Locale('en'),
          width: 300,
          child: const CapabilityChip(
            icon: Icons.headphones_rounded,
            label: 'Audio',
          ),
        ),
      );

      expect(find.text('Audio'), findsOneWidget);
      expect(find.byIcon(Icons.headphones_rounded), findsOneWidget);
    });

    testWidgets('hugs its content when there is room', (tester) async {
      await tester.pumpWidget(
        _host(
          locale: const Locale('en'),
          width: 300,
          child: const CapabilityChip(
            icon: Icons.headphones_rounded,
            label: 'Audio',
          ),
        ),
      );

      expect(tester.getSize(find.byType(CapabilityChip)).width, lessThan(120));
    });

    for (final locale in [const Locale('ar'), const Locale('ur')]) {
      testWidgets(
        'stays inside a narrow slot at 2x text in $locale',
        (tester) async {
          // A long label in a slot narrower than its natural width: the chip
          // must give way (wrap) rather than overflow its parent.
          const label = 'وضع الدراسة والمراجعة للدروس المسموعة';
          await tester.pumpWidget(
            _host(
              locale: locale,
              width: 140,
              textScale: 2,
              child: const CapabilityChip(
                icon: Icons.school_rounded,
                label: label,
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byType(CapabilityChip)).width,
            lessThanOrEqualTo(140),
          );
        },
      );
    }
  });
}
