import 'package:integration_test/integration_test_driver.dart';

/// Driver for the on-device performance benchmarks. Needed because
/// `flutter test integration_test/` can't run in profile mode — realistic
/// frame timings require `flutter drive --profile`:
///
///   flutter drive \
///     --driver=test_driver/perf_driver.dart \
///     --target=integration_test/performance_test.dart \
///     --profile -d DEVICE_ID
///   (or: make perf-test DEVICE=...)
///
/// The default [integrationDriver] writes each scenario's `watchPerformance`
/// summary to `build/integration_response_data.json`; the test also prints
/// PERF[...] lines and asserts the frame budget inline.
Future<void> main() => integrationDriver();
