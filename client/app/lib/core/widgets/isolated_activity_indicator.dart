import "package:flutter/material.dart";

import "../extensions/build_context_x.dart";

/// A spinner for long-lived "agent is working" states, isolated behind its
/// own [RepaintBoundary].
///
/// Material's indeterminate [CircularProgressIndicator] repaints every frame
/// for as long as it is visible. Painted inline it dirties the nearest
/// enclosing repaint boundary, so on the session chat screen — where these
/// indicators stay visible for entire agent turns — every vsync re-rasterized
/// a large slice of the screen, measurably dominating the screen's battery
/// cost. The boundary confines each repaint to the spinner's own small layer;
/// the rest of the screen stays cached and is only re-composited.
///
/// Honours the OS reduce-motion preference by rendering a static arc.
class IsolatedActivityIndicator extends StatelessWidget {
  final double strokeWidth;
  final Color color;

  /// Sweep of the arc drawn when reduce-motion disables the animation.
  static const _staticArcSweep = 0.75;

  const IsolatedActivityIndicator({
    super.key,
    required this.strokeWidth,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CircularProgressIndicator(
        value: context.isReducedMotion ? _staticArcSweep : null,
        strokeWidth: strokeWidth,
        strokeCap: StrokeCap.round,
        color: color,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
