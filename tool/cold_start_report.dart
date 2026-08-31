import 'dart:convert';
import 'dart:io';

import 'package:myapp/utils/startup_measurement.dart';

Future<void> main() async {
  final measurements = <StartupMeasurement>[];
  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final measurement = StartupMeasurement.tryParse(line);
    if (measurement != null) measurements.add(measurement);
  }
  if (measurements.isEmpty) {
    stderr.writeln('No valid COLD_START_INTERACTIVE measurements found.');
    exitCode = 1;
    return;
  }

  final byCohort = <String, List<StartupMeasurement>>{};
  for (final measurement in measurements) {
    byCohort.putIfAbsent(measurement.cohort, () => []).add(measurement);
  }
  for (final entry in byCohort.entries) {
    final values = entry.value.map((sample) => sample.elapsedMillis).toList()
      ..sort();
    final median = StartupMeasurement.medianMillis(entry.value);
    stdout.writeln(
      'COLD_START_SUMMARY cohort=${entry.key} samples=${values.length} '
      'median_ms=${median.toStringAsFixed(median == median.roundToDouble() ? 0 : 1)} '
      'min_ms=${values.first} max_ms=${values.last}',
    );
  }
}
