import "dart:async";

import "package:flutter/gestures.dart";
import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../session_detail/widgets/transcript_motion.dart";

/// Where the list shows a pinned row ahead of the bridge: [sessionId]
/// directly below [afterSessionId] among the pinned rows shown, or first when
/// it is null.
typedef PinnedRowPlace = ({String sessionId, String? afterSessionId});

/// Moves a pinned session below another, or to the top when
/// [afterSessionId] is null; answers whether the bridge took the move.
typedef PinnedRowMove = Future<bool> Function({required String sessionId, required String? afterSessionId});

/// How long a lifted row takes to lift or settle back into the list.
const Duration _liftDuration = Duration(milliseconds: 150);

/// The drag and drop that reorders a list's pinned rows: which row is lifted,
/// where the list should show it meanwhile, and where the lifted copy
/// floats. The list lists its pinned rows by [place] and wraps each in a
/// [PinnedRowDrag], which reports the pointer here.
///
/// While a row is lifted, the list shows it at its [place] with the other
/// pinned rows sliding out of its way; the copy floats over the list under
/// the pointer, held within the pinned rows. A drop asks the window to move
/// it there, and keeps [place] only until the rows the list shows stand that
/// way, which the window's optimistic order brings at once, or until the
/// move is answered; a refused move slides the rows back.
final class PinnedRowDragTracker() extends ChangeNotifier {
  final Map<String, BuildContext> _rows = {};

  /// The pinned rows the list shows, top first, as their sessions order them.
  List<String> _shown = const [];
  _Lift? _lift;
  PinnedRowPlace? _pending;
  bool _disposed = false;

  /// Where the list shows a lifted or just dropped row, if any.
  PinnedRowPlace? get place => switch (_lift) {
    final lift? => (sessionId: lift.sessionId, afterSessionId: lift.afterSessionId),
    null => _pending,
  };

  /// The global top of the lifted row's floating copy, while it is held. It
  /// changes on every pointer move, which needs only a repaint, so it is not
  /// part of what notifies the list.
  final ValueNotifier<double?> liftedTop = ValueNotifier(null);

  /// Tells the tracker the pinned rows the list shows, top first, before any
  /// [place] moved one. A dropped row's place is let go once they show it.
  void showPinned({required List<String> sessionIds}) {
    _shown = sessionIds;
    if (_pending case (:final sessionId, :final afterSessionId)?) {
      final at = sessionIds.indexOf(sessionId);
      if (at == 0 ? afterSessionId == null : at > 0 && sessionIds[at - 1] == afterSessionId) _pending = null;
    }
  }

  void _register({required String sessionId, required BuildContext context}) => _rows[sessionId] = context;

  void _unregister({required String sessionId, required BuildContext context}) {
    if (identical(_rows[sessionId], context)) _rows.remove(sessionId);
  }

  /// Lifts [sessionId]'s row under a pointer at [pointerY]; false when no row
  /// can be lifted now, as while another one is.
  bool _start({required String sessionId, required double pointerY}) {
    if (_lift != null) return false;
    final rows = <_Slot>[];
    for (final id in _shown) {
      // Only rows on screen are targets: one scrolled away, built or not,
      // keeps its place.
      if (_rows[id]?.findRenderObject() case final RenderBox box? when box.attached && box.hasSize) {
        final top = box.localToGlobal(Offset.zero).dy;
        if (RenderAbstractViewport.maybeOf(box) case final RenderBox viewport?) {
          final viewportTop = viewport.localToGlobal(Offset.zero).dy;
          if (top + box.size.height <= viewportTop || top >= viewportTop + viewport.size.height) continue;
        }
        rows.add((sessionId: id, top: top, height: box.size.height));
      }
    }
    final index = rows.indexWhere((row) => row.sessionId == sessionId);
    if (index < 0) return false;
    final firstShown = _shown.indexOf(rows.first.sessionId);
    final lifted = rows[index];
    final others = [...rows]..removeAt(index);
    _lift = _Lift(
      sessionId: sessionId,
      aboveSessionId: firstShown > 0 ? _shown[firstShown - 1] : null,
      others: others,
      height: lifted.height,
      groupTop: rows.first.top,
      groupBottom: rows.last.top + rows.last.height,
      startTop: lifted.top,
      startPointerY: pointerY,
      index: index,
    )..top = lifted.top;
    liftedTop.value = lifted.top;
    notifyListeners();
    return true;
  }

  void _update({required double pointerY}) {
    final lift = _lift;
    if (lift == null) return;
    final index = lift.index;
    lift.moveTo(pointerY: pointerY);
    liftedTop.value = lift.top;
    if (lift.index != index) notifyListeners();
  }

  /// Puts the lifted row back where it was lifted, for a drag the pointer
  /// gave up on; the drop that follows then moves nothing.
  void _cancel() {
    if (_lift case final lift?) lift.index = lift.startIndex;
  }

  /// Lets go of [sessionId]'s lift when its row leaves the list mid-drag, so
  /// later drags are not refused. Its list is rebuilding already.
  void _abandon({required String sessionId}) {
    if (_lift?.sessionId != sessionId) return;
    _lift = null;
    liftedTop.value = null;
  }

  /// Drops the lifted row where it stands and, when that moved it, asks
  /// [move] to keep it there. Answers whether the bridge refused it.
  Future<bool> _drop({required PinnedRowMove move}) async {
    final lift = _lift;
    if (lift == null) return false;
    _lift = null;
    liftedTop.value = null;
    if (lift.index == lift.startIndex) {
      notifyListeners();
      return false;
    }
    final place = (sessionId: lift.sessionId, afterSessionId: lift.afterSessionId);
    _pending = place;
    notifyListeners();
    final moved = await move(sessionId: place.sessionId, afterSessionId: place.afterSessionId);
    if (_disposed) return !moved;
    if (identical(_pending, place)) {
      _pending = null;
      notifyListeners();
    }
    return !moved;
  }

  @override
  void dispose() {
    _disposed = true;
    liftedTop.dispose();
    super.dispose();
  }
}

/// A pinned row's room as a drag started: its global top and its height.
typedef _Slot = ({String sessionId, double top, double height});

/// The lifted row: the other pinned rows on screen as the drag started, top
/// first, and the index among them the lifted one stands at.
final class _Lift({
  required final String sessionId,

  /// The pinned row scrolled away right above the first one on screen, which
  /// a row dropped first lands below; null when the first is the group's.
  required final String? aboveSessionId,
  required final List<_Slot> others,
  required final double height,
  required final double groupTop,
  required final double groupBottom,
  required final double startTop,
  required final double startPointerY,
  required int index,
}) {
  final int startIndex = index;
  int index = index;

  /// The floating copy's global top.
  double top = 0;

  String? get afterSessionId => index == 0 ? aboveSessionId : others[index - 1].sessionId;

  /// Follows the pointer, held within the pinned rows, and stands the row
  /// before the first other row whose middle it has not passed, as those
  /// rows now stand around its room. Held against either end, it stands
  /// there, however its height compares with the row it meets.
  void moveTo({required double pointerY}) {
    top = (startTop + pointerY - startPointerY).clamp(groupTop, groupBottom - height);
    if (top <= groupTop || top >= groupBottom - height) {
      index = top <= groupTop ? 0 : others.length;
      return;
    }
    final middle = top + height / 2;
    var y = groupTop;
    var passed = 0;
    for (final (at, other) in others.indexed) {
      if (at == index) y += height;
      if (y + other.height / 2 < middle) passed++;
      y += other.height;
    }
    index = passed;
  }
}

/// A pinned row the user can drag within the pinned rows: with a mouse, a
/// press that moves lifts it at once, while a click still opens it and a
/// right click its menu. While lifted, the row keeps its room in the list,
/// empty, and a lifted copy of it follows the pointer over the list; on
/// release the copy glides into that room.
class const PinnedRowDrag({
  super.key,
  required final String sessionId,
  required final PinnedRowDragTracker tracker,

  /// Asked on a drop that moved the row.
  required final PinnedRowMove onMove,

  /// Called when the bridge refused a dropped row's move, after the rows slid
  /// back.
  required final VoidCallback onMoveRefused,

  /// Whether the row's corners are rounded, as a pointer row's are.
  required final BorderRadius borderRadius,
  required final Color liftedColor,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<PinnedRowDrag> createState() => _PinnedRowDragState();
}

class _PinnedRowDragState() extends State<PinnedRowDrag> with TickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();

  /// The copy's lift: its scale and shadow.
  late final AnimationController _lift = AnimationController(vsync: this, duration: _liftDuration);
  late final CurvedAnimation _lifted = CurvedAnimation(parent: _lift, curve: transcriptMotionCurve);

  /// The copy's glide from where it was dropped into the row's room.
  late final AnimationController _settle = AnimationController(vsync: this, duration: transcriptMotionDuration);
  late final CurvedAnimation _settling = CurvedAnimation(parent: _settle, curve: transcriptMotionCurve);
  double _droppedTop = 0;

  /// The row's width as it was lifted, which the copy keeps.
  double _width = 0;

  @override
  void initState() {
    super.initState();
    widget.tracker._register(sessionId: widget.sessionId, context: context);
  }

  @override
  void didUpdateWidget(PinnedRowDrag oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracker != widget.tracker || oldWidget.sessionId != widget.sessionId) {
      oldWidget.tracker._unregister(sessionId: oldWidget.sessionId, context: context);
      widget.tracker._register(sessionId: widget.sessionId, context: context);
    }
  }

  @override
  void dispose() {
    widget.tracker._unregister(sessionId: widget.sessionId, context: context);
    widget.tracker._abandon(sessionId: widget.sessionId);
    _lifted.dispose();
    _lift.dispose();
    _settling.dispose();
    _settle.dispose();
    super.dispose();
  }

  void _onStart(DragStartDetails details) {
    final room = _roomBox();
    if (room == null || !widget.tracker._start(sessionId: widget.sessionId, pointerY: details.globalPosition.dy)) {
      return;
    }
    _width = room.size.width;
    _settle.value = 0;
    _portal.show();
    if (context.isReducedMotion) {
      _lift.value = 1;
    } else {
      _lift.forward();
    }
    setState(() {});
  }

  void _onUpdate(DragUpdateDetails details) => widget.tracker._update(pointerY: details.globalPosition.dy);

  void _onEnd() {
    final top = widget.tracker.liftedTop.value;
    if (top == null) return;
    _droppedTop = top;
    final refused = widget.tracker._drop(move: widget.onMove);
    unawaited(
      refused.then((refused) {
        if (refused && mounted) widget.onMoveRefused();
      }),
    );
    if (context.isReducedMotion) {
      _landed();
      return;
    }
    _lift.reverse();
    unawaited(_settle.forward(from: 0).then((_) => _landed()));
  }

  void _landed() {
    if (!mounted) return;
    _portal.hide();
    _lift.value = 0;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    gestures: {
      VerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
        // Touch scrolls the list; the phone lifts a row another way.
        () => VerticalDragGestureRecognizer(supportedDevices: const {PointerDeviceKind.mouse}),
        (recognizer) => recognizer
          ..dragStartBehavior = DragStartBehavior.down
          ..onStart = _onStart
          ..onUpdate = _onUpdate
          // A pointer cancelled mid-drag also ends it; the listener below
          // has put the row back by then.
          ..onEnd = ((_) => _onEnd()),
      ),
    },
    child: Listener(
      onPointerCancel: (_) => widget.tracker._cancel(),
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _copy,
        // Its room stays, empty and untouchable, while the copy stands for it.
        child: IgnorePointer(
          ignoring: _portal.isShowing,
          child: Opacity(opacity: _portal.isShowing ? 0 : 1, child: widget.child),
        ),
      ),
    ),
  );

  Widget _copy(BuildContext context) {
    final prego = context.prego;
    return _FloatAt(
      origin: _copyOrigin,
      repaint: Listenable.merge([widget.tracker.liftedTop, _settling]),
      width: _width,
      child: AnimatedBuilder(
        animation: _lifted,
        builder: (context, child) => Transform.scale(
          scale: 1 + 0.02 * _lifted.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.liftedColor,
              borderRadius: widget.borderRadius,
              boxShadow: [
                for (final shadow in prego.shadows.lg)
                  shadow.copyWith(color: shadow.color.withValues(alpha: shadow.color.a * _lifted.value)),
              ],
            ),
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }

  /// The copy's global top left: under the pointer while held, then gliding
  /// into the row's room. Read as the copy paints, once the list has laid
  /// its rows out.
  Offset _copyOrigin() {
    final room = _roomBox()?.localToGlobal(Offset.zero);
    final held = widget.tracker.liftedTop.value;
    return Offset(
      room?.dx ?? 0,
      held ?? _droppedTop + ((room?.dy ?? _droppedTop) - _droppedTop) * _settling.value,
    );
  }

  /// The row's room in the list, sliding with it.
  RenderBox? _roomBox() => switch (context.findRenderObject()) {
    final RenderBox box when box.attached && box.hasSize => box,
    _ => null,
  };
}

/// Paints its child at a global position read as it paints, and repaints
/// whenever [repaint] changes, so a copy can follow the pointer without
/// rebuilding and can track a list row that is still sliding.
class const _FloatAt({
  required final Offset Function() origin,
  required final Listenable repaint,
  required final double width,
  super.child,
}) extends SingleChildRenderObjectWidget {
  @override
  _RenderFloatAt createRenderObject(BuildContext context) =>
      _RenderFloatAt(origin: origin, repaint: repaint, width: width);

  @override
  void updateRenderObject(BuildContext context, _RenderFloatAt renderObject) => renderObject
    ..origin = origin
    ..repaint = repaint
    ..width = width;
}

final class _RenderFloatAt({
  required Offset Function() origin,
  required Listenable repaint,
  required double width,
}) extends RenderProxyBox {
  Offset Function() origin = origin;
  Listenable _repaint = repaint;
  double _width = width;

  Listenable get repaint => _repaint;
  set repaint(Listenable value) {
    if (identical(value, _repaint)) return;
    if (attached) {
      _repaint.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _repaint = value;
  }

  double get width => _width;
  set width(double value) {
    if (value == _width) return;
    _width = value;
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() {
    child?.layout(BoxConstraints.tightFor(width: _width));
    size = constraints.biggest;
  }

  /// The copy takes the pointer from the rows beneath it, so they show no
  /// hover or title tooltip while a row is carried over them.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null || !(globalToLocal(origin()) & child.size).contains(position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child case final child?) context.paintChild(child, offset + globalToLocal(origin()));
  }
}
