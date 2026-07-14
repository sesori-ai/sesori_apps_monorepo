import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/semantics.dart";

import "../extensions/build_context_x.dart";

/// A spinner for long-lived "agent is working" states, redrawn at a low fixed
/// rate instead of every vsync.
///
/// Material's indeterminate [CircularProgressIndicator] keeps the render
/// pipeline active at the display refresh rate for the whole agent turn. This
/// indicator advances a fixed arc at 8 Hz and isolates its small repaint, so
/// the engine can sleep between ticks. Covered routes and reduced-motion
/// environments render a static arc.
class ThrottledActivityIndicator extends StatefulWidget {
  final double strokeWidth;
  final Color color;

  const ThrottledActivityIndicator({
    super.key,
    required this.strokeWidth,
    required this.color,
  });

  @override
  State<ThrottledActivityIndicator> createState() => _ThrottledActivityIndicatorState();
}

class _ThrottledActivityIndicatorState extends State<ThrottledActivityIndicator> {
  static const _tickInterval = Duration(milliseconds: 125);
  static const _stepsPerTurn = 12;
  static const _arcSweep = 0.75;

  Timer? _timer;
  int _step = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shouldAnimate = TickerMode.valuesOf(context).enabled && !context.isReducedMotion;
    if (!shouldAnimate) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(_tickInterval, (_) {
      setState(() => _step = (_step + 1) % _stepsPerTurn);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      role: SemanticsRole.loadingSpinner,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: Transform.rotate(
            angle: _step * 2 * math.pi / _stepsPerTurn,
            child: CircularProgressIndicator(
              value: _arcSweep,
              strokeWidth: widget.strokeWidth,
              strokeCap: StrokeCap.round,
              color: widget.color,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}
