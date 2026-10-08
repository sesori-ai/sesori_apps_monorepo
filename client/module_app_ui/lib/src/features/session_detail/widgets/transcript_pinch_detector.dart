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

  /// How far the fingers have spread, from 0 to 1 at full spread, and how far
  /// their midpoint has [moved] since the pinch began. A trackpad's pinch has
  /// no fingers on the screen to follow, so it never moves.
  required final void Function({required double progress, required Offset moved}) onProgress,

  /// The fingers let go, or one of them did; [closes] when they had spread
  /// past halfway, and [velocity] is how fast the spread was changing then,
  /// in full spreads a second. Nothing follows in that gesture.
  required final void Function({required bool closes, required double velocity}) onRelease,
}) extends TranscriptPinch;

/// Reports a pinch by touch or trackpad, as [pinch] asks.
///
/// A second finger claims the gesture at once, so a pinch never loses to the
/// list's vertical drag, even with one finger held still. A trackpad pinch
/// wins once its scale changes, and a trackpad pan never pinches.
///
/// For a pinch in, one finger alone never pinches and gives the gesture up
/// after a few pixels, so scrolling, taps, the timestamp peek and a code
/// block's horizontal scroll are untouched. Two fingers on a touch screen
/// therefore pinch and never scroll.
///
/// A pinch out is taken whenever a second finger lands, also after the first
/// has started to scroll a list beneath: that list holds still from the moment
/// the second finger touches until the pinch lets go. Fingers that land
/// together often reach the screen as one until they part, by which time that
/// one has moved far enough to scroll. A touch pinch out is measured in
/// pixels the fingers have spread since the second landed; a trackpad's by
/// its scale.
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

/// What a touch pinch out has come to since its second finger landed.
sealed class const _TouchPinch();

/// Following the [first] and [second] fingers, which landed [spreadFrom] apart
/// around [focalFrom].
final class _FollowingFingers({
  required final int first,
  required final int second,
  required final double spreadFrom,
  required final Offset focalFrom,
}) extends _TouchPinch {
  /// How fast the fingers are spreading, in pixels a second along x.
  final spreadVelocity = VelocityTracker.withKind(PointerDeviceKind.touch);

  bool follows({required int pointer}) => pointer == first || pointer == second;
}

/// Let go, or not taken: nothing more happens until the last finger lifts.
final class const _TouchPinchOver() extends _TouchPinch;

class _TranscriptPinchDetectorState() extends State<TranscriptPinchDetector> {
  static const double _kPinchInScale = 0.8;

  /// The scale at which a trackpad's pinch out has spread fully.
  static const double _kPinchOutFullScale = 1.5;

  /// How far, in logical pixels, a touch pinch out's fingers spread beyond
  /// where they landed to spread fully.
  static const double _kPinchOutFullSpread = 200;

  /// The share of a full spread past which a pinch out let go closes: 100
  /// pixels by touch, and a scale of 1.25 by trackpad, the pinch in's 0.8
  /// turned over.
  static const double _kPinchOutCloses = 0.5;

  /// How far ahead, in seconds, a trackpad's pinch out let go is carried at
  /// the speed its scale was changing; the spread it would reach decides
  /// whether it closes.
  static const double _kPinchOutCarry = 0.1;

  /// The recognizer's gesture has had its outcome: it pinched in, was let go,
  /// or is a touch pinch out, which the fingers themselves measure.
  bool _done = false;

  /// A trackpad pinch out has begun and been taken.
  bool _outStarted = false;
  double _outScale = 1;

  /// Where each touch finger down on a pinch out's screen is, in global
  /// coordinates.
  final _touches = <int, Offset>{};

  /// The touch gesture's pinch out; null until its second finger lands.
  _TouchPinch? _touchPinch;

  /// The list a finger is scrolling beneath a pinch out, until it stops.
  ScrollPosition? _draggedScroll;

  /// Holds that list still while a pinch out follows the fingers.
  ScrollHoldController? _heldScroll;

  void _onFirstPointer() {
    _done = false;
    _outStarted = false;
    _outScale = 1;
    if (widget.pinch case TranscriptPinchIn(:final onPointerDown)) onPointerDown();
  }

  void _onStart(ScaleStartDetails details) {
    switch (widget.pinch) {
      case TranscriptPinchIn(:final onPinchStart):
        onPinchStart();
      case TranscriptPinchOut():
        // The recognizer only claims a touch pinch out from the list and taps.
        if (details.kind != PointerDeviceKind.trackpad) _done = true;
    }
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
        onProgress(
          progress: _outProgressOf(scale: _outScale),
          moved: Offset.zero,
        );
    }
  }

  /// How far a trackpad's pinch out at [scale] has spread. Measured from the
  /// gesture's own scale of 1, so the spread the recognizer needed to accept
  /// the pinch counts too.
  static double _outProgressOf({required double scale}) => ((scale - 1) / (_kPinchOutFullScale - 1)).clamp(0.0, 1.0);

  /// Lets a trackpad's pinch out go when it ends.
  void _onEnd(ScaleEndDetails details) {
    if (_done || !_outStarted) return;
    if (widget.pinch case TranscriptPinchOut(:final onRelease)) {
      _done = true;
      final carried = _outScale + details.scaleVelocity * _kPinchOutCarry;
      onRelease(
        closes: _outProgressOf(scale: carried) >= _kPinchOutCloses,
        velocity: details.scaleVelocity / (_kPinchOutFullScale - 1),
      );
    }
  }

  void _onLastPointerGone() {
    if (widget.pinch case TranscriptPinchIn(:final onGestureEnd)) onGestureEnd();
  }

  /// Starts a touch pinch out once a second finger lands, whoever holds the
  /// gesture by then, and holds still a list the first finger was scrolling.
  void _onTouchDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _touches[event.pointer] = event.position;
    if (_touchPinch != null || _touches.length != 2) return;
    if (widget.pinch case TranscriptPinchOut(:final onStart)) {
      final [(first, a), (second, b)] = [for (final MapEntry(:key, :value) in _touches.entries) (key, value)];
      final focal = (a + b) / 2;
      if (!onStart(focalPoint: focal)) {
        _touchPinch = const _TouchPinchOver();
        return;
      }
      _touchPinch = _FollowingFingers(first: first, second: second, spreadFrom: (a - b).distance, focalFrom: focal);
      _heldScroll = _draggedScroll?.hold(() => _heldScroll = null);
    }
  }

  void _onTouchMove(PointerMoveEvent event) {
    if (!_touches.containsKey(event.pointer)) return;
    _touches[event.pointer] = event.position;
    if (_touchPinch case final _FollowingFingers fingers when fingers.follows(pointer: event.pointer)) {
      if (widget.pinch case TranscriptPinchOut(:final onProgress)) {
        if (_spreadOf(fingers: fingers) case (:final spread, :final focal)) {
          fingers.spreadVelocity.addPosition(event.timeStamp, Offset(spread, 0));
          onProgress(progress: (spread / _kPinchOutFullSpread).clamp(0.0, 1.0), moved: focal - fingers.focalFrom);
        }
      }
    }
  }

  /// Lets a touch pinch out go as one of its fingers lifts, by where the
  /// fingers last moved to: the pixel or two they slide as they leave the
  /// glass decides nothing against a threshold of 100.
  void _onTouchEnd(PointerEvent event) {
    if (!_touches.containsKey(event.pointer)) return;
    if (_touchPinch case final _FollowingFingers fingers when fingers.follows(pointer: event.pointer)) {
      if (widget.pinch case TranscriptPinchOut(:final onRelease)) {
        if (_spreadOf(fingers: fingers) case (:final spread, focal: _)) {
          onRelease(
            closes: spread >= _kPinchOutCloses * _kPinchOutFullSpread,
            velocity: fingers.spreadVelocity.getVelocity().pixelsPerSecond.dx / _kPinchOutFullSpread,
          );
        }
      }
      _touchPinch = const _TouchPinchOver();
      _heldScroll?.cancel();
    }
    _touches.remove(event.pointer);
    if (_touches.isEmpty) _touchPinch = null;
  }

  /// How far [fingers] have spread since they landed, in logical pixels, and
  /// their midpoint now; null once one of them has lifted.
  ({double spread, Offset focal})? _spreadOf({required _FollowingFingers fingers}) =>
      switch ((_touches[fingers.first], _touches[fingers.second])) {
        (final a?, final b?) => (spread: (a - b).distance - fingers.spreadFrom, focal: (a + b) / 2),
        _ => null,
      };

  /// Keeps the list a finger is scrolling, so a pinch out landing on it can
  /// hold it still.
  bool _onScroll(ScrollNotification notification) {
    if (notification case ScrollStartNotification(dragDetails: _?, :final context?)) {
      _draggedScroll = context.findAncestorStateOfType<ScrollableState>()?.position;
    } else if (notification is ScrollEndNotification) {
      _draggedScroll = null;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final pinch = widget.pinch;
    final recognizer = RawGestureDetector(
      gestures: {
        _PinchRecognizer: GestureRecognizerFactoryWithHandlers<_PinchRecognizer>(
          () => _PinchRecognizer(
            debugOwner: this,
            supportedDevices: const {PointerDeviceKind.touch, PointerDeviceKind.trackpad},
            givesUpLoneFinger: pinch is TranscriptPinchIn,
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
    return switch (pinch) {
      TranscriptPinchIn() => recognizer,
      TranscriptPinchOut() => NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Listener(
          onPointerDown: _onTouchDown,
          onPointerMove: _onTouchMove,
          onPointerUp: _onTouchEnd,
          onPointerCancel: _onTouchEnd,
          child: recognizer,
        ),
      ),
    };
  }
}

class _PinchRecognizer({
  super.debugOwner,
  super.supportedDevices,

  /// Whether a lone finger's few pixels of travel give the gesture up. A pinch
  /// out keeps it instead, until the list's drag or a tap wins it, so a
  /// second finger landing before then still claims it from them.
  required final bool givesUpLoneFinger,
}) extends ScaleGestureRecognizer {
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
    if (givesUpLoneFinger) _soloDownPosition = event.position;
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
