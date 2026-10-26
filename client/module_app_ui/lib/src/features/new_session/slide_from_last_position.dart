import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";

/// Paints [child] sliding from where it last painted to where it lies now,
/// along [progress], each time [forward] flips: [progress] runs toward 1 while
/// [forward] is true and back toward 0 while it is false. Only the painting
/// moves; layout and the child's state are already in their new place.
class const SlideFromLastPosition({
  super.key,
  required final Animation<double> progress,
  required final bool forward,

  /// Slides across only, so a move of the page around [child] carries it
  /// along with its neighbours rather than leaving it behind.
  required final bool horizontalOnly,
  required super.child,
}) extends SingleChildRenderObjectWidget {
  @override
  RenderSlideFromLastPosition createRenderObject(BuildContext context) =>
      RenderSlideFromLastPosition(progress: progress, forward: forward, horizontalOnly: horizontalOnly);

  @override
  void updateRenderObject(BuildContext context, RenderSlideFromLastPosition renderObject) {
    renderObject.update(progress: progress, forward: forward, horizontalOnly: horizontalOnly);
  }
}

class RenderSlideFromLastPosition({
  required Animation<double> progress,
  required bool forward,
  required bool horizontalOnly,
}) extends RenderProxyBox {
  Animation<double> _progress = progress;
  bool _forward = forward;
  bool _horizontalOnly = horizontalOnly;

  /// Where the child last painted, globally; the next move starts there.
  Offset? _lastPosition;

  /// How far the child was from its new place when the move began.
  Offset _from = Offset.zero;

  /// Where the child paints relative to its layout, so taps and semantics
  /// follow what is on screen during the move.
  Offset _shift = Offset.zero;
  bool _moved = false;

  void update({required Animation<double> progress, required bool forward, required bool horizontalOnly}) {
    if (!identical(progress, _progress)) {
      if (attached) _progress.removeListener(markNeedsPaint);
      _progress = progress;
      if (attached) _progress.addListener(markNeedsPaint);
    }
    _horizontalOnly = horizontalOnly;
    if (forward != _forward) {
      _forward = forward;
      _moved = true;
      markNeedsPaint();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _progress.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final position = localToGlobal(Offset.zero);
    final done = _forward ? _progress.value : 1 - _progress.value;
    final remaining = 1 - Curves.easeOutCubic.transform(done);
    if (_moved) {
      // A flip mid-move resumes from where the child painted, scaled to the
      // part of the curve still left.
      final gap = (_lastPosition ?? position) - position;
      final move = _horizontalOnly ? Offset(gap.dx, 0) : gap;
      _from = remaining < 1e-6 ? Offset.zero : move / remaining;
      _moved = false;
    }
    _shift = _from * remaining;
    _lastPosition = position + _shift;
    super.paint(context, offset + _shift);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => result.addWithPaintOffset(
    offset: _shift,
    position: position,
    hitTest: (result, transformed) => super.hitTestChildren(result, position: transformed),
  );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.translateByDouble(_shift.dx, _shift.dy, 0, 1);
}
