import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";

import "../extensions/build_context_x.dart";

/// A spinner for long-lived "agent is working" states, redrawn at a low
/// fixed tick rate instead of every vsync.
///
/// Material's indeterminate [CircularProgressIndicator] animates with an
/// always-on ticker, which forces the engine to produce frames at the display
/// refresh rate (60–120 Hz) for as long as the spinner is visible. On the
/// session chat screen these indicators stay visible for entire agent turns —
/// minutes at a time — keeping the whole render pipeline hot and measurably
/// dominating the screen's battery cost. Stepping a fixed arc at ~8 Hz reads
/// the same at 16–20 px while letting the engine idle between ticks.
///
/// Honours the OS reduce-motion preference by rendering a static arc.
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
  /// One step every 125 ms (8 Hz) — slow enough for the engine to sleep
  /// between ticks, fast enough to read as continuous motion.
  static const _tickInterval = Duration(milliseconds: 125);

  /// Steps per full rotation; with [_tickInterval] this yields one rotation
  /// every 1.5 s, close to the Material spinner's rotation period.
  static const _stepsPerTurn = 12;

  /// Sweep of the drawn arc as a fraction of the full circle.
  static const _arcSweep = 0.75;

  Timer? _timer;
  int _step = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.isReducedMotion) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(_tickInterval, (_) {
        setState(() => _step = (_step + 1) % _stepsPerTurn);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: _step * 2 * math.pi / _stepsPerTurn,
      child: CircularProgressIndicator(
        value: _arcSweep,
        strokeWidth: widget.strokeWidth,
        strokeCap: StrokeCap.round,
        color: widget.color,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
