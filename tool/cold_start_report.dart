import 'dart:convert';
import 'dart:io';

import 'package:myapp/utils/startup_measurement.dart';

Future<void> main(List<String> args) async {
  final expectedCohort = _option(args, '--cohort');
  final expectedSurface = _option(args, '--surface');
  final expectedSamples = int.tryParse(_option(args, '--samples') ?? '');
  if (expectedCohort == null ||
      expectedSurface == null ||
      expectedSamples == null) {
    stderr.writeln(
      'Usage: dart run tool/cold_start_report.dart '
      '--cohort=<cohort> --surface=<surface> --samples=<count>',
    );
    exitCode = 2;
    return;
  }

  final lines = <String>[];
  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    lines.add(line);
  }
  try {
    final measurements = StartupMeasurement.parseBatch(
      lines,
      cohort: expectedCohort,
      surface: expectedSurface,
      expectedCount: expectedSamples,
    );
    final values = measurements.map((sample) => sample.elapsedMillis).toList()
      ..sort();
    final median = StartupMeasurement.medianMillis(measurements);
    stdout.writeln(
      'COLD_START_SUMMARY cohort=$expectedCohort samples=${values.length} '
      'median_ms=${median.toStringAsFixed(median == median.roundToDouble() ? 0 : 1)} '
      'min_ms=${values.first} max_ms=${values.last}',
    );
  } on FormatException catch (error) {
    stderr.writeln('Invalid cold-start batch: ${error.message}');
    exitCode = 1;
  }
}

String? _option(List<String> args, String name) {
  final prefix = '$name=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
  }
  return null;
}
