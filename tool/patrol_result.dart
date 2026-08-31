import 'dart:io';

/// The parsed summary emitted by Patrol after a native test run.
final class PatrolResult {
  const PatrolResult({required this.total});

  final int total;
}

/// A Patrol invocation that cannot be accepted as a release-gate result.
final class PatrolResultError implements Exception {
  const PatrolResultError(this.message, {this.commandExitCode});

  final String message;
  final int? commandExitCode;

  @override
  String toString() => message;
}

// Patrol's reporter prefixes the summary with a note emoji. ANSI colour
// sequences can wrap the whole line when output is attached to a terminal.
final _ansiEscape = RegExp('\x1B(?:\\[[0-?]*[ -/]*[@-~]|[@-_])');
final _summary = RegExp(
  r'^\s*(?:📝\s*)?Total:\s*(\d+)\s*(?:tests?)?\s*$',
  caseSensitive: false,
);

/// Parses and validates Patrol's final summary.
///
/// A native run is accepted only when it contains exactly one numeric
/// `Total:` summary and that total is positive. Missing, malformed, and zero
/// summaries fail closed rather than turning a discovery regression into a
/// green release gate.
PatrolResult parsePatrolResult(String output) {
  final summaryLines = output
      .split(RegExp(r'\r?\n'))
      .map((line) => line.replaceAll(_ansiEscape, ''))
      .where((line) => line.contains('Total:'))
      .toList(growable: false);

  if (summaryLines.isEmpty) {
    throw const PatrolResultError(
      'Patrol result is missing the final "Total: N" summary.',
    );
  }
  if (summaryLines.length != 1) {
    throw PatrolResultError(
      'Patrol result has ${summaryLines.length} "Total:" summaries; expected exactly one.',
    );
  }

  final match = _summary.firstMatch(summaryLines.single);
  if (match == null) {
    throw const PatrolResultError(
      'Patrol result has a malformed "Total:" summary.',
    );
  }

  final total = int.tryParse(match.group(1)!);
  if (total == null) {
    throw const PatrolResultError(
      'Patrol result has a non-numeric "Total:" summary.',
    );
  }
  if (total < 1) {
    throw const PatrolResultError(
      'Patrol discovered 0 tests; at least one test is required.',
    );
  }
  return PatrolResult(total: total);
}

/// Validates a completed command while retaining its original failure status.
///
/// Command failures take precedence over parsing, so a Patrol process that
/// exits with (for example) 73 never gets rewritten as a generic parser error.
PatrolResult validatePatrolResult(
  String output, {
  required int commandExitCode,
}) {
  if (commandExitCode != 0) {
    throw PatrolResultError(
      'Patrol command failed with exit code $commandExitCode.',
      commandExitCode: commandExitCode,
    );
  }
  return parsePatrolResult(output);
}

Future<void> main(List<String> args) async {
  if (args.length != 2 || !args.first.startsWith('--exit-code=')) {
    stderr.writeln(
      'Usage: dart run tool/patrol_result.dart --exit-code=<status> <log-file>',
    );
    exitCode = 64;
    return;
  }

  final commandExitCode =
      int.tryParse(args.first.substring('--exit-code='.length));
  if (commandExitCode == null) {
    stderr.writeln('Invalid Patrol exit code: ${args.first}');
    exitCode = 64;
    return;
  }

  final output = await File(args[1]).readAsString();
  try {
    final result = validatePatrolResult(
      output,
      commandExitCode: commandExitCode,
    );
    stdout.writeln('Patrol gate accepted: Total: ${result.total}');
  } on PatrolResultError catch (error) {
    stderr.writeln(error.message);
    exitCode = error.commandExitCode ?? 1;
  }
}
