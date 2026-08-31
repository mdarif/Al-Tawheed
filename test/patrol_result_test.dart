import 'package:flutter_test/flutter_test.dart';
import '../tool/patrol_result.dart';

void main() {
  test('accepts a positive Patrol total', () {
    final result = parsePatrolResult('log\n📝 Total: 6\n');

    expect(result.total, 6);
  });

  test('accepts an ANSI-colored Patrol formatter summary', () {
    final result = parsePatrolResult('\x1B[32m📝 Total: 6\x1B[0m\n');

    expect(result.total, 6);
  });

  test('accepts the plain Total formatter summary', () {
    expect(parsePatrolResult('Total: 6 tests').total, 6);
  });

  test('rejects zero discovered tests', () {
    expect(
      () => parsePatrolResult('Total: 0'),
      throwsA(isA<PatrolResultError>()),
    );
  });

  test('rejects a missing summary', () {
    expect(
      () => parsePatrolResult('Patrol completed without a summary'),
      throwsA(isA<PatrolResultError>()),
    );
  });

  test('rejects a malformed summary', () {
    expect(
      () => parsePatrolResult('Total: unknown'),
      throwsA(isA<PatrolResultError>()),
    );
  });

  test('preserves a nonzero Patrol command status', () {
    try {
      validatePatrolResult('Total: 4', commandExitCode: 73);
      fail('expected PatrolResultError');
    } on PatrolResultError catch (error) {
      expect(error.commandExitCode, 73);
    }
  });
}
