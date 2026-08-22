import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// The fraction of a drag target reserved for a platform system-back gesture.
const double _systemBackGestureExclusionFraction = 0.1;

/// A horizontal drag detector that stays out of platform system-back edges.
///
/// Touch drags beginning in the directional start 10% are ignored on iOS. On
/// Android, both 10% edges are ignored when [MediaQuery.systemGestureInsets]
/// reports horizontal gesture-navigation insets. Other pointer kinds and
/// platforms retain the full hit area.
///
/// The detector participates in Flutter's gesture arena, so a horizontal
/// recognizer in [child] can win instead. When [crossAxisRejectionSlop] is set,
/// a still-pending claim is also rejected once vertical-dominant movement
/// reaches that distance. This lets a competing vertical recognizer become the
/// sole arena member before Flutter's normal touch slop when a host requires
/// eager small-drag handling.
class const PregoHorizontalDragGestureDetector({
  super.key,
  required final Widget child,
  required final HitTestBehavior? behavior,
  required final Set<PointerDeviceKind>? supportedDevices,
  required final GestureDragDownCallback? onHorizontalDragDown,
  required final GestureDragStartCallback onHorizontalDragStart,
  required final GestureDragUpdateCallback onHorizontalDragUpdate,
  required final GestureDragEndCallback onHorizontalDragEnd,
  required final GestureDragCancelCallback onHorizontalDragCancel,
  required final double? crossAxisRejectionSlop,
  final DragStartBehavior dragStartBehavior = DragStartBehavior.start,
}) extends StatelessWidget {
  this : assert(crossAxisRejectionSlop == null || crossAxisRejectionSlop > 0);

  @override
  Widget build(BuildContext context) {
    final gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    final scrollBehavior = ScrollConfiguration.of(context);

    return RawGestureDetector(
      behavior: behavior,
      gestures: <Type, GestureRecognizerFactory>{
        _PregoHorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_PregoHorizontalDragGestureRecognizer>(
              () => _PregoHorizontalDragGestureRecognizer(debugOwner: this),
              (recognizer) {
                recognizer
                  ..onDown = onHorizontalDragDown
                  ..onStart = onHorizontalDragStart
                  ..onUpdate = onHorizontalDragUpdate
                  ..onEnd = onHorizontalDragEnd
                  ..onCancel = onHorizontalDragCancel
                  ..dragStartBehavior = dragStartBehavior
                  ..multitouchDragStrategy = scrollBehavior.getMultitouchDragStrategy(context)
                  ..gestureSettings = gestureSettings
                  ..supportedDevices = supportedDevices
                  ..crossAxisRejectionSlop = crossAxisRejectionSlop
                  ..isStartAllowed = (event) => _allowsDragStart(context: context, event: event);
              },
            ),
      },
      child: child,
    );
  }

  bool _allowsDragStart({required BuildContext context, required PointerEvent event}) {
    if (event.kind != PointerDeviceKind.touch) return true;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return true;
    final width = renderObject.size.width;
    if (width <= 0) return true;

    final platform = Theme.of(context).platform;
    final usesAndroidGestureNavigation =
        platform == TargetPlatform.android && _usesAndroidGestureNavigation(context: context);
    final excludeStart = platform == TargetPlatform.iOS || usesAndroidGestureNavigation;
    final excludeEnd = usesAndroidGestureNavigation;
    if (!excludeStart && !excludeEnd) return true;

    final fromStart = Directionality.of(context) == TextDirection.ltr
        ? event.localPosition.dx
        : width - event.localPosition.dx;
    final exclusion = width * _systemBackGestureExclusionFraction;
    return (!excludeStart || fromStart > exclusion) && (!excludeEnd || fromStart < width - exclusion);
  }

  bool _usesAndroidGestureNavigation({required BuildContext context}) {
    final insets = MediaQuery.maybeSystemGestureInsetsOf(context);
    return insets != null && (insets.left > 0 || insets.right > 0);
  }
}

class _PregoHorizontalDragGestureRecognizer({required super.debugOwner}) extends HorizontalDragGestureRecognizer {
  late bool Function(PointerEvent event) isStartAllowed;

  double? crossAxisRejectionSlop;

  final Map<int, Offset> _pointerStarts = <int, Offset>{};
  final Set<int> _acceptedPointers = <int>{};

  @override
  bool isPointerAllowed(PointerEvent event) => super.isPointerAllowed(event) && isStartAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _pointerStarts[event.pointer] = event.position;
    super.addAllowedPointer(event);
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    _pointerStarts[event.pointer] = Offset.zero;
    super.addAllowedPointerPanZoom(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    final rejectionSlop = crossAxisRejectionSlop;
    final pendingDelta = switch (event) {
      PointerMoveEvent() => event.position - (_pointerStarts[event.pointer] ?? event.position),
      PointerPanZoomUpdateEvent() => event.pan,
      _ => null,
    };
    if (rejectionSlop != null &&
        !_acceptedPointers.contains(event.pointer) &&
        pendingDelta != null &&
        pendingDelta.dy.abs() >= rejectionSlop &&
        pendingDelta.dy.abs() >= pendingDelta.dx.abs()) {
      resolvePointer(event.pointer, GestureDisposition.rejected);
      return;
    }

    super.handleEvent(event);
    if (event is PointerUpEvent || event is PointerCancelEvent || event is PointerPanZoomEndEvent) {
      _forgetPointer(event.pointer);
    }
  }

  @override
  void acceptGesture(int pointer) {
    _acceptedPointers.add(pointer);
    super.acceptGesture(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    _forgetPointer(pointer);
    super.rejectGesture(pointer);
  }

  void _forgetPointer(int pointer) {
    _pointerStarts.remove(pointer);
    _acceptedPointers.remove(pointer);
  }
}
