import "package:flutter/material.dart";
import "package:flutter/semantics.dart";

import "../extensions/build_context_x.dart";

/// A smooth activity indicator with repaint damage confined to its own layer.
class IsolatedActivityIndicator extends StatelessWidget {
  static const _staticArcSweep = 0.75;

  final double strokeWidth;
  final Color color;

  const IsolatedActivityIndicator({
    super.key,
    required this.strokeWidth,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isReducedMotion) {
      return Semantics(
        role: SemanticsRole.loadingSpinner,
        child: ExcludeSemantics(
          child: RepaintBoundary(child: _indicator(value: _staticArcSweep)),
        ),
      );
    }

    return RepaintBoundary(child: _indicator(value: null));
  }

  CircularProgressIndicator _indicator({required double? value}) {
    return CircularProgressIndicator(
      value: value,
      strokeWidth: strokeWidth,
      strokeCap: StrokeCap.round,
      color: color,
      backgroundColor: Colors.transparent,
    );
  }
}
