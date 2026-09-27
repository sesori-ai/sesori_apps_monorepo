import "dart:math";

import "package:flutter/scheduler.dart";
import "package:material_ui/material_ui.dart";

/// Glides a scroll position to a target it reads again every frame, on an
/// ease-in-out curve whose duration follows the first distance.
///
/// A lazy list only estimates how far away an unbuilt row is, and the estimate
/// sharpens as rows are built on the way. Each frame covers the curve's share
/// of what remains to the latest target, so a refined target bends the glide
/// without a jump, and the last frame lands on the target exactly. A drag, or
/// any other scroll, replaces the glide; a target that goes null ends it.
class TranscriptGlideActivity({
  required final ScrollPositionWithSingleContext _position,
  required final double? Function() _target,
}) extends ScrollActivity {
  /// In seconds.
  late final double _duration;
  late final Ticker _ticker;
  double _progress = 0;
  double _elapsed = 0;
  double _velocity = 0;

  this : super(_position) {
    final distance = ((_target() ?? _position.pixels) - _position.pixels).abs();
    _duration = (distance * 0.6).clamp(280, 650) / 1000;
    _ticker = _position.context.vsync.createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    final target = _target();
    if (target == null) return delegate.goIdle();
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final time = min(seconds / _duration, 1.0);
    final progress = Curves.easeInOutCubic.transform(time);
    final from = _position.pixels;
    final to = target.clamp(_position.minScrollExtent, _position.maxScrollExtent);
    final pixels = time >= 1 ? to : from + (to - from) * (progress - _progress) / (1 - _progress);
    final step = seconds - _elapsed;
    _velocity = step > 0 ? (pixels - from) / step : 0;
    _progress = progress;
    _elapsed = seconds;
    delegate.setPixels(pixels);
    if (time >= 1) delegate.goIdle();
  }

  @override
  bool get shouldIgnorePointer => true;

  @override
  bool get isScrolling => true;

  @override
  double get velocity => _velocity;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
