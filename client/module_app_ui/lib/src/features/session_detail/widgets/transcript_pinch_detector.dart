import "package:flutter/gestures.dart";
import "package:material_ui/material_ui.dart";

/// Folds the transcript on a pinch in and unfolds it on a pinch out, by touch
/// or trackpad.
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
/// switches at most once.
class const TranscriptPinchDetector({
  super.key,

  /// A gesture's first pointer landed, before any recognizer has won it.
  required final VoidCallback onPointerDown,

  /// The pinch won its gesture. Can repeat within one gesture.
  required final VoidCallback onPinchStart,

  /// The pinch crossed a threshold, with the focal point in global
  /// coordinates.
  required final void Function({required bool folded, required Offset focalPoint}) onFoldRequested,

  /// The gesture's last pointer lifted, or the pinch lost its gesture.
  required final VoidCallback onGestureEnd,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<TranscriptPinchDetector> createState() => _TranscriptPinchDetectorState();
}

class _TranscriptPinchDetectorState() extends State<TranscriptPinchDetector> {
  static const double _kFoldScale = 0.8;
  static const double _kUnfoldScale = 1.25;

  bool _switched = false;

  void _onFirstPointer() {
    _switched = false;
    widget.onPointerDown();
  }

  void _onStart(ScaleStartDetails details) => widget.onPinchStart();

  void _onUpdate(ScaleUpdateDetails details) {
    if (_switched) return;
    final bool folded;
    if (details.scale <= _kFoldScale) {
      folded = true;
    } else if (details.scale >= _kUnfoldScale) {
      folded = false;
    } else {
      return;
    }
    _switched = true;
    widget.onFoldRequested(folded: folded, focalPoint: details.focalPoint);
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
            ..onLastPointerGone = widget.onGestureEnd
            ..onStart = _onStart
            ..onUpdate = _onUpdate,
        ),
      },
      child: widget.child,
    );
  }
}

/// A scale recognizer that wins as soon as a second touch pointer lands, and
/// never on the movement of one pointer.
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
