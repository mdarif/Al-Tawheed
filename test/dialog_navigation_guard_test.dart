import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against dialog navigation bugs under go_router.
///
/// Always use [showConfirmDialog] from lib/widgets/confirm_dialog.dart.
/// Popping with the caller's BuildContext empties the route stack.
void main() {
  test('lib/ does not use raw showDialog outside confirm_dialog.dart', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'Run tests from project root');

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('confirm_dialog.dart')) continue;

      final content = entity.readAsStringSync();
      if (content.contains('showDialog')) {
        violations.add(entity.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Use showConfirmDialog (lib/widgets/confirm_dialog.dart) instead '
          'of showDialog in: ${violations.join(', ')}',
    );
  });
}
