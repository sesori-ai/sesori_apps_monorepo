import "dart:async";

import "package:flutter/gestures.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// Lets the top [height] of [child] drag the window, as the title bar the macOS
/// shell hides did: Flutter receives every press under a hidden title bar, so
/// nothing moves the window unless a region hands the press to the host.
///
/// The drag joins the gesture arena beside whatever [child] puts there, so a
/// button, a text selection or a scrollbar still wins its own press.
///
/// [zoomOnDoubleClick] suits a strip with nothing else to click: a double-tap
/// recognizer delays every tap that competes with it.
class const DesktopWindowDragArea({
  super.key,
  required final WindowHost windowHost,
  required final double height,
  required final bool zoomOnDoubleClick,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<DesktopWindowDragArea> createState() => _DesktopWindowDragAreaState();
}

class _DesktopWindowDragAreaState() extends State<DesktopWindowDragArea> {
  late final _WindowDragRecognizer _drag = _WindowDragRecognizer(debugOwner: this)
    // Alone in the arena it wins on the press; a plain click must not drag.
    ..onlyAcceptDragOnThreshold = true
    ..onStart = (_) => _run(operation: widget.windowHost.startDragging, failure: "Failed to start dragging the window");
  late final DoubleTapGestureRecognizer _zoom = DoubleTapGestureRecognizer(debugOwner: this)
    ..onDoubleTap = () => _run(operation: widget.windowHost.toggleZoom, failure: "Failed to zoom the window");

  void _run({required Future<void> Function() operation, required String failure}) {
    unawaited(
      operation().catchError((Object error, StackTrace stackTrace) => logw(failure, error, stackTrace)),
    );
  }

  @override
  void dispose() {
    _drag.dispose();
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) {
      if (event.buttons != kPrimaryButton || event.localPosition.dy >= widget.height) return;
      _drag.addPointer(event);
      if (widget.zoomOnDoubleClick) _zoom.addPointer(event);
    },
    child: widget.child,
  );
}

/// A pan that waits for as much travel as a tap tolerates, so a click that
/// jiggles on a toolbar button stays a click instead of nudging the window.
class _WindowDragRecognizer({required super.debugOwner}) extends PanGestureRecognizer {
  @override
  bool hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) =>
      globalDistanceMoved.abs() > kTouchSlop;
}
