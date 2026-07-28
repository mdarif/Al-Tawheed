import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Converts user-driven scroll updates into immersive chrome intents.
///
/// Reading forward hides surrounding chrome; reversing direction shows it again.
/// Tiny jitter is accumulated/reset by direction so chrome only moves after a
/// deliberate drag, and programmatic scrolls are ignored except at the top.
class ScrollImmersionDetector {
  ScrollImmersionDetector({this.threshold = 24});

  final double threshold;

  double _accum = 0;
  bool _hidden = false;

  bool? update(ScrollNotification notification) {
    if (notification.metrics.pixels <=
        notification.metrics.minScrollExtent + 4) {
      _accum = 0;
      if (_hidden) {
        return _setHidden(false);
      }
      return null;
    }

    if (notification is UserScrollNotification) {
      return switch (notification.direction) {
        ScrollDirection.reverse when !_hidden => _setHidden(true),
        ScrollDirection.forward when _hidden => _setHidden(false),
        _ => null,
      };
    }

    if (notification is! ScrollUpdateNotification) return null;
    if (notification.dragDetails == null) return null;

    final delta = notification.scrollDelta ?? 0;
    if (delta == 0) return null;
    if (delta.sign != _accum.sign) _accum = 0;

    _accum += delta;
    if (_accum >= threshold && !_hidden) {
      return _setHidden(true);
    }
    if (_accum <= -threshold && _hidden) {
      return _setHidden(false);
    }
    return null;
  }

  bool _setHidden(bool hidden) {
    _hidden = hidden;
    return hidden;
  }
}
