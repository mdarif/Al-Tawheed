import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden-only setup. Call from `setUpAll` in each golden suite.
///
/// Deliberately NOT a `flutter_test_config.dart`: that file wraps the WHOLE
/// `test/` tree, and initialising the widget binding there forces every pure
/// `test()` file onto the widget binding — whose HTTP stub returns 400, which
/// broke the download tests that talk to a localhost server. Scoped here, it
/// only ever runs under `--run-skipped` on the `golden`-tagged suites.
Future<void> configureGoldens() async {
  await _loadFonts();
  goldenFileComparator = _TolerantGoldenComparator(
    // basedir = <package>/test/golden/, so goldens resolve as
    // `matchesGoldenFile('goldens/<name>.png')`.
    Uri.parse('${Directory.current.path}/test/golden/config.dart'),
  );
}

/// The pubspec fonts, loaded from the bundled asset so RTL text renders with the
/// real faces instead of blank Ahem boxes — the whole point of a script golden.
Future<void> _loadFonts() async {
  const families = {
    'NotoNaskhArabic': 'assets/fonts/NotoNaskhArabic-Regular.ttf',
    'NotoNastaliqUrdu': 'assets/fonts/NotoNastaliqUrdu-Regular.ttf',
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
}

/// A [LocalFileComparator] that passes when the pixel difference is within
/// [_kGoldenTolerance] rather than demanding a byte-exact match — so sub-pixel
/// AA drift between a dev's Mac and the macOS CI runner doesn't flap, while a
/// real glyph/layout regression (which moves whole blocks) still fails.
class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile);

  static const double _kGoldenTolerance = 0.005; // 0.5% of pixels

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _kGoldenTolerance) {
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}
