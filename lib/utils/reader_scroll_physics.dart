import 'package:flutter/material.dart';

/// Smooth reader scrolling that refuses rubber-band overscroll at true edges.
///
/// This mirrors the Al Quran reader feel: normal scrolling keeps a soft,
/// bouncing-style spring, but pulling beyond the first/last content edge is
/// clamped so the whole reading surface does not drag down on iOS.
class ReaderClampEdgesPhysics extends BouncingScrollPhysics {
  const ReaderClampEdgesPhysics({super.parent});

  @override
  ReaderClampEdgesPhysics applyTo(ScrollPhysics? ancestor) =>
      ReaderClampEdgesPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
        mass: 0.5,
        stiffness: 70,
        ratio: 1.0,
      );

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.pixels &&
        position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    if (value > position.pixels &&
        position.pixels >= position.maxScrollExtent) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }
}
