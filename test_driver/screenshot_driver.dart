import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver for the Play Store screenshot capture harness.
///
/// Persists each `binding.takeScreenshot(name)` PNG to
/// `docs/play-store/v3/raw/<name>.png`. Run with:
///
///   flutter drive \
///     --driver=test_driver/screenshot_driver.dart \
///     --target=integration_test/screenshots_test.dart \
///     -d DEVICE_ID
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (
      String name,
      List<int> bytes, [
      Map<String, Object?>? args,
    ]) async {
      final dir = Directory('docs/play-store/v3/raw');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      File('${dir.path}/$name.png').writeAsBytesSync(bytes);
      return true;
    },
  );
}
