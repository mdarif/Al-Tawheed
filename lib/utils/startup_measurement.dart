/// A machine-readable startup marker emitted by the profile build.
class StartupMeasurement {
  const StartupMeasurement({
    required this.cohort,
    required this.surface,
    required this.elapsedMillis,
  });

  final String cohort;
  final String surface;
  final int elapsedMillis;

  String get machineLine =>
      'COLD_START_INTERACTIVE cohort=$cohort surface=$surface '
      'elapsed_ms=$elapsedMillis';

  /// Parses either the Dart line or the Android logcat line. Prefixes such as
  /// `I/TawheedStartup:` are intentionally accepted because logcat adds them.
  static StartupMeasurement? tryParse(String line) {
    if (!line.contains('COLD_START_INTERACTIVE')) return null;
    final fields = <String, String>{};
    for (final match in RegExp(r'\b([a-z_]+)=([^\s]+)').allMatches(line)) {
      fields[match.group(1)!] = match.group(2)!;
    }
    final surface = fields['surface'];
    final elapsed = int.tryParse(fields['elapsed_ms'] ?? '');
    if (surface == null || surface.isEmpty || elapsed == null || elapsed < 0) {
      return null;
    }
    return StartupMeasurement(
      cohort: fields['cohort'] ?? 'unspecified',
      surface: surface,
      elapsedMillis: elapsed,
    );
  }

  static double medianMillis(Iterable<StartupMeasurement> samples) {
    final values = samples.map((sample) => sample.elapsedMillis).toList()
      ..sort();
    if (values.isEmpty) {
      throw ArgumentError.value(samples, 'samples', 'must not be empty');
    }
    final middle = values.length ~/ 2;
    if (values.length.isOdd) return values[middle].toDouble();
    return (values[middle - 1] + values[middle]) / 2.0;
  }
}
