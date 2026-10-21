import 'package:flutter/foundation.dart';

/// Swallows only `A RenderFlex overflowed` reports for the rest of the test.
///
/// For tests whose subject is something else (e.g. the bottom inset the shell
/// reports) and that run at a text scale where unrelated rows or headers
/// already overflow. Every other framework error still fails the test.
/// Pass the test's `addTearDown` so the handler is restored.
void ignoreRenderFlexOverflow(void Function(void Function()) addTearDown) {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}
