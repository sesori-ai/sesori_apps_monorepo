import "package:flutter/gestures.dart";
import "package:material_ui/material_ui.dart";

/// What a pinch on a [TranscriptPinchDetector] does.
sealed class const TranscriptPinch();

/// The transcript's pinch: a pinch in past its threshold reports once, and a
/// pinch out reports nothing, since on the transcript there is nothing to
/// pinch out of.
final class const TranscriptPinchIn({
  /// A gesture's first pointer landed, before any recognizer has won it.
  required final VoidCallback onPointerDown,

  /// The pinch won its gesture. Can repeat within one gesture.
  required final VoidCallback onPinchStart,

  /// The pinch closed past its threshold, with the focal point in global
  /// coordinates.
  required final void Function({required Offset focalPoint}) onPinchIn,

  /// The gesture's last pointer lifted, or the pinch lost its gesture.
  required final VoidCallback onGestureEnd,
}) extends TranscriptPinch;

/// The Prompts screen's pinch: a pinch out is followed while the fingers
/// spread, then let go once, and a pinch in reports nothing.
final class const TranscriptPinchOut({
  /// The pinch began at [focalPoint], in global coordinates. Once per gesture.
  /// Returns whether the screen takes it; one it does not take reports
  /// nothing more.
  required final bool Function({required Offset focalPoint}) onStart,

  /// How far the fingers have spread, from 0 to 1 at full spread.
  required final void Function({required double progress}) onProgress,

  /// The fingers let go, or one of them did; [closes] when they had spread
  /// past halfway, or would have a moment later at the speed they were
  /// moving. Nothing follows in that gesture.
  required final void Function({required bool closes}) onRelease,
}) extends TranscriptPinch;

/// Reports a pinch by touch or trackpad, as [pinch] asks.
///
/// A second finger claims the gesture at once, so a pinch never loses to the
/// list's vertical drag, even with one finger held still. One finger alone
/// never pinches and gives the gesture up after a few pixels, so scrolling,
/// taps, the timestamp peek and a code block's horizontal scroll are
/// untouched. Two fingers on a touch screen therefore
/// pinch and never scroll. A trackpad pinch wins once its scale changes, and a
/// trackpad pan never pinches.
///
/// A gesture runs from its first pointer down to its last pointer up, and
/// pinches in, or is let go, at most once.
class const TranscriptPinchDetector({
  super.key,
  required final TranscriptPinch pinch,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<TranscriptPinchDetector> createState() => _TranscriptPinchDetectorState();
}

class _TranscriptPinchDetectorState() extends State<TranscriptPinchDetector> {
  static const double _kPinchInScale = 0.8;

  /// The scale at which a pinch out has spread fully.
  static const double _kPinchOutFullScale = 1.5;

  /// The spread past which a pinch out let go closes: a scale of 1.25, the
  /// pinch in's 0.8 turned over.
  static const double _kPinchOutCloses = 0.5;

  /// How far ahead, in seconds, a pinch out let go is carried at the speed its
  /// scale was changing; the spread it would reach decides whether it closes.
  /// A flick still closes or stays by its direction, but the pixel fingers
  /// slide as they lift off a phone's glass, a fast change of scale when they
  /// landed close together, cannot turn a wide spread back.
  static const double _kPinchOutCarry = 0.1;

  /// The gesture has had its outcome: it pinched in, or was let go.
  bool _done = false;

  /// A pinch out has begun and been taken.
  bool _outStarted = false;
  double _outScale = 1;

  void _onFirstPointer() {
    _done = false;
    _outStarted = false;
    _outScale = 1;
    if (widget.pinch case TranscriptPinchIn(:final onPointerDown)) onPointerDown();
  }

  void _onStart(ScaleStartDetails details) {
    if (widget.pinch case TranscriptPinchIn(:final onPinchStart)) onPinchStart();
  }

  void _onUpdate(ScaleUpdateDetails details) {
    if (_done) return;
    switch (widget.pinch) {
      case TranscriptPinchIn(:final onPinchIn):
        if (details.scale > _kPinchInScale) return;
        _done = true;
        onPinchIn(focalPoint: details.focalPoint);
      case TranscriptPinchOut(:final onStart, :final onProgress):
        if (!_outStarted) {
          _outStarted = onStart(focalPoint: details.focalPoint);
          // A screen that does not take the pinch hears nothing more from it.
          _done = !_outStarted;
          if (_done) return;
        }
        _outScale = details.scale;
        onProgress(progress: _outProgressOf(scale: _outScale));
    }
  }

  /// How far a pinch out at [scale] has spread. Measured from the gesture's
  /// own scale of 1, so the spread the recognizer needed to accept the pinch
  /// counts too.
  static double _outProgressOf({required double scale}) => ((scale - 1) / (_kPinchOutFullScale - 1)).clamp(0.0, 1.0);

  /// Lets a pinch out go when its fingers lift or one of them does: a lone
  /// finger left behind measures no spread, so it cannot carry it on.
  void _onEnd(ScaleEndDetails details) {
    if (_done || !_outStarted) return;
    if (widget.pinch case TranscriptPinchOut(:final onRelease)) {
      _done = true;
      final carried = _outScale + details.scaleVelocity * _kPinchOutCarry;
      onRelease(closes: _outProgressOf(scale: carried) >= _kPinchOutCloses);
    }
  }

  void _onLastPointerGone() {
    if (widget.pinch case TranscriptPinchIn(:final onGestureEnd)) onGestureEnd();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        _PinchRecognizer: GestureRecognizerFactoryWithHandlers<_PinchRecognizer>(
          () => _PinchRecognizer(
            debugOwner: this,
            supportedDevices: const {PointerDeviceKind.touch, PointerDeviceKind.trackpad},
          ),
          (recognizer) => recognizer
            ..onFirstPointer = _onFirstPointer
            ..onLastPointerGone = _onLastPointerGone
            ..onStart = _onStart
            ..onUpdate = _onUpdate
            ..onEnd = _onEnd,
        ),
      },
      child: widget.child,
    );
  }
}

class _PinchRecognizer({super.debugOwner, super.supportedDevices}) extends ScaleGestureRecognizer {
  /// A lone finger's travel that gives the gesture up. Below `kTouchSlop`, so
  /// a small drag still reaches the list at once, as the timestamp peek's
  /// pending slop keeps it.
  static const double _kSoloRejectionSlop = 8;

  VoidCallback? onFirstPointer;
  VoidCallback? onLastPointerGone;

  /// Where a lone first finger landed, until a second one joins it.
  Offset? _soloDownPosition;

  /// An endless pan slop: a pan alone never wins, only a second finger or a
  /// trackpad's scale does.
  @override
  DeviceGestureSettings? get gestureSettings => const DeviceGestureSettings(touchSlop: double.infinity);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    final first = pointerCount == 0;
    super.addAllowedPointer(event);
    if (!first) return;
    _soloDownPosition = event.position;
    onFirstPointer?.call();
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    final first = pointerCount == 0;
    super.addAllowedPointerPanZoom(event);
    if (first) onFirstPointer?.call();
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    if (event is PointerDownEvent && pointerCount >= 2) {
      _soloDownPosition = null;
      resolve(GestureDisposition.accepted);
    } else if (event is PointerMoveEvent) {
      final down = _soloDownPosition;
      if (down == null || (event.position - down).distance <= _kSoloRejectionSlop) return;
      _soloDownPosition = null;
      resolve(GestureDisposition.rejected);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _soloDownPosition = null;
    super.didStopTrackingLastPointer(pointer);
    onLastPointerGone?.call();
  }
}
