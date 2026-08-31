import 'package:flutter_test/flutter_test.dart';
import '../tool/patrol_result.dart';

void main() {
  test('accepts a positive Patrol total', () {
    final result = parsePatrolResult('log\nTotal: 6 tests\n');

    expect(result.total, 6);
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
