import "dart:math";

import "package:flutter/scheduler.dart";
import "package:material_ui/material_ui.dart";

/// Glides a scroll position to a target it reads again every frame, on an
/// ease-in-out curve whose duration follows the first distance.
///
/// A lazy list only estimates how far away an unbuilt row is, and the estimate
/// sharpens as rows are built on the way. Each frame covers the curve's share
/// of what remains to the latest target, so a refined target bends the glide
/// without a jump, and the glide ends on the target exactly. No frame moves
/// further than [_maxStep], less than the list builds ahead of its edge, so an
/// estimate that lies past the real row is corrected before the glide passes
/// it and never sends the reader back. A drag, or any other scroll, replaces
/// the glide; a target that goes null ends it.
class TranscriptGlideActivity({
  required final ScrollPositionWithSingleContext _position,
  required final double? Function() _target,
}) extends ScrollActivity {
  /// The furthest one frame moves, in pixels.
  static const double _maxStep = 200;

  /// In seconds.
  late final double _duration;
  late final Ticker _ticker;
  double _progress = 0;
  double _elapsed = 0;
  double _velocity = 0;

  this : super(_position) {
    final distance = ((_target() ?? _position.pixels) - _position.pixels).abs();
    // Long enough that the curve's peak, three times its mean speed, stays
    // within a step a frame.
    _duration = max((distance * 0.6).clamp(280, 650) / 1000, distance * 3 / (_maxStep * 60));
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
    final share = time >= 1 ? to - from : (to - from) * (progress - _progress) / (1 - _progress);
    // Past the curve's end, a capped glide covers the rest a step a frame.
    final pixels = time >= 1 && share.abs() <= _maxStep ? to : from + share.clamp(-_maxStep, _maxStep);
    final step = seconds - _elapsed;
    _velocity = step > 0 ? (pixels - from) / step : 0;
    _progress = progress;
    _elapsed = seconds;
    delegate.setPixels(pixels);
    if (pixels == to) delegate.goIdle();
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
