import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

export 'startup_measurement.dart';
import 'startup_measurement.dart';

// This is deliberately a library-level clock. It starts when the application
// isolate loads, before main() performs plugin and provider initialization.
// A stopwatch around app.main() would omit exactly the work a cold-start
// measurement is meant to include.
final Stopwatch _startupClock = Stopwatch()..start();

/// Captures the first frame where a startup landing surface is painted and
/// interactive. The marker is intentionally a widget seam rather than a
/// finder for translated text or a catalog tile that may be absent.
class StartupInteractiveMarker extends StatefulWidget {
  const StartupInteractiveMarker({
    super.key,
    required this.surface,
    required this.child,
  });

  final String surface;
  final Widget child;

  @override
  State<StartupInteractiveMarker> createState() =>
      _StartupInteractiveMarkerState();
}

class _StartupInteractiveMarkerState extends State<StartupInteractiveMarker> {
  bool _marked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markIfPainted());
  }

  void _markIfPainted() {
    if (!mounted || _marked) return;
    final renderObject = context.findRenderObject();
    if (renderObject == null || !renderObject.attached) return;
    _marked = true;
    StartupMetrics.markInteractive(widget.surface);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Process-start-to-interactive measurement state.
abstract final class StartupMetrics {
  static const _channel = MethodChannel('com.almarfa.tawheed/startup');

  static Completer<StartupMeasurement> _interactive =
      Completer<StartupMeasurement>();
  static StartupMeasurement? _measurement;
  static String _cohort = 'unspecified';

  static StartupMeasurement? get measurement => _measurement;
  static String get cohort => _cohort;

  /// Set by the integration harness before app.main(). Production keeps the
  /// neutral value; the value is only a label and never affects app behavior.
  static void setCohortForTest(String cohort) {
    if (cohort.trim().isNotEmpty) _cohort = cohort.trim();
  }

  static Future<StartupMeasurement> get interactive => _interactive.future;

  static void markInteractive(String surface) {
    if (_measurement != null) return;
    final measurement = StartupMeasurement(
      cohort: _cohort,
      surface: surface,
      elapsedMillis: _startupClock.elapsedMilliseconds,
    );
    _measurement = measurement;
    _interactive.complete(measurement);

    // The Android side measures from Activity.onCreate using elapsedRealtime,
    // which is the value the cold-start runner consumes. Keep the Dart line as
    // a useful fallback and for the integration test's own assertion.
    if (kProfileMode) {
      developer.log(measurement.machineLine, name: 'TawheedStartup');
      if (defaultTargetPlatform == TargetPlatform.android) {
        unawaited(
          _channel.invokeMethod<void>('startupInteractive', <String, String>{
            'cohort': measurement.cohort,
            'surface': measurement.surface,
          }).catchError((_) {}),
        );
      }
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _measurement = null;
    _cohort = 'unspecified';
    // A test reset is only used before a marker is emitted. Replacing the
    // completer keeps isolated widget tests from inheriting a completed future.
    _interactive = Completer<StartupMeasurement>();
  }
}
