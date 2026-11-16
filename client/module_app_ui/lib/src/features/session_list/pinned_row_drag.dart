import "dart:async";
import "dart:math" as math;

import "package:flutter/gestures.dart";
import "package:flutter/rendering.dart";
import "package:flutter/scheduler.dart";
import "package:flutter/services.dart";
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

/// How near the list's top or bottom edge a held row scrolls the list.
const double _edgeScrollZone = 40;

/// How fast the list scrolls, in logical pixels a second, under a row held
/// right at its edge or past it; it scrolls slower the farther in it is held.
const double _edgeScrollMaxSpeed = 1000;

/// The global top of the part of a list that nothing covers: below a
/// phone's glass bar, which the list scrolls on under, or the list's own
/// top at [viewportTop].
double pinnedListUncoveredTop({required BuildContext listContext, required double viewportTop}) =>
    switch (pregoTopBarGeometryOf(context: listContext)) {
      (:final baseInset, :final bannerHeight)? => math.max(viewportTop, baseInset + bannerHeight.value),
      null => viewportTop,
    };

/// The drag and drop that reorders a list's pinned rows: which row is lifted,
/// where the list should show it meanwhile, and where the lifted copy
/// floats. The list lists its pinned rows by [place] and wraps each in a
/// [PinnedRowDrag], which reports the pointer here.
///
/// While a row is lifted, the list shows it at its [place] with the other
/// pinned rows sliding out of its way; the copy floats over the list under
/// the pointer, held within the pinned rows. Held near the list's top or
/// bottom edge, it scrolls the list until the pinned rows' end shows. A drop
/// asks the window to move it there, and keeps [place] only until the rows
/// the list shows stand that way, which the window's optimistic order brings
/// at once, or until the move is answered; a refused move slides the rows
/// back.
final class PinnedRowDragTracker({
  /// The global bottom of what the list holds over its top, such as its
  /// Pinned heading while editing, if anything; read as a held row nears
  /// the top, so the list scrolls when the row meets it.
  required final double? Function() heldOverTop,
}) extends ChangeNotifier {
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

  /// The global bottom of the last pinned row shown, as last laid out:
  /// infinite while the built ones end above it, and null while none is
  /// built.
  double? pinnedBottom() {
    final boxes = [for (final sessionId in _shown) ?_box(sessionId: sessionId)];
    if (boxes.isEmpty) return null;
    if (_box(sessionId: _shown.last) == null) return double.infinity;
    return boxes.map((box) => box.localToGlobal(Offset(0, box.size.height)).dy).reduce(math.max);
  }

  void _register({required String sessionId, required BuildContext context}) => _rows[sessionId] = context;

  void _unregister({required String sessionId, required BuildContext context}) {
    if (identical(_rows[sessionId], context)) _rows.remove(sessionId);
  }

  /// [sessionId]'s row as the list last laid it out, if it is built.
  RenderBox? _box({required String sessionId}) => switch (_rows[sessionId]?.findRenderObject()) {
    final RenderBox box when box.attached && box.hasSize => box,
    _ => null,
  };

  /// Lifts the row [room] lays out for [sessionId] in [scrollable], under a
  /// pointer at [pointerY]; false when no row can be lifted now, as while
  /// another one is. [vsync] drives the scrolling at the list's edges.
  bool _start({
    required String sessionId,
    required RenderBox room,
    required ScrollableState scrollable,
    required double pointerY,
    required TickerProvider vsync,
  }) {
    final viewport = scrollable.context.findRenderObject();
    if (_lift != null || viewport is! RenderBox || !viewport.hasSize) return false;
    final position = scrollable.position;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final top = room.localToGlobal(Offset.zero).dy;
    // A phone list scrolls on under its glass bar and the home indicator, so
    // its edges are where those leave it uncovered.
    final listContext = scrollable.context;
    final uncoveredTop = pinnedListUncoveredTop(listContext: listContext, viewportTop: viewportTop);
    final screen = listContext.getInheritedWidgetOfExactType<MediaQuery>()?.data;
    final uncoveredBottom = switch (screen) {
      final screen? => screen.size.height - screen.padding.bottom,
      null => double.infinity,
    };
    final lift = _Lift(
      sessionId: sessionId,
      position: position,
      viewportTop: viewportTop,
      edgeTop: () => math.max(uncoveredTop, heldOverTop() ?? uncoveredTop),
      edgeBottom: math.min(viewportTop + viewport.size.height, uncoveredBottom),
      height: room.size.height,
      groupTop: top - viewportTop + position.pixels,
      grab: pointerY - top,
      pointerY: pointerY,
      autoscroll: vsync.createTicker(_scrollAtEdge),
    );
    _lift = lift;
    position.addListener(_follow);
    _follow();
    notifyListeners();
    return true;
  }

  void _update({required double pointerY}) {
    if (_lift case final lift?) {
      lift.pointerY = pointerY;
      _follow();
    }
  }

  /// Stands the lifted row where the pointer and the list's scroll put it,
  /// and scrolls the list while it is held at an edge.
  void _follow() {
    final lift = _lift;
    if (lift == null) return;
    _takeInBuiltRows(lift: lift);
    final index = lift.index;
    lift.follow();
    liftedTop.value = lift.top;
    if (!lift.autoscroll.isActive && lift.edgeScroll() != null) {
      lift.scrolledAt = Duration.zero;
      lift.autoscroll.start();
    }
    if (lift.index != index) notifyListeners();
  }

  /// Takes in the pinned rows built right above and below the ones the lift
  /// knows, as a scroll builds them, so each is a place to drop on and the
  /// edge scrolling runs on to the pinned rows' true end.
  void _takeInBuiltRows({required _Lift lift}) {
    while (true) {
      final at = _shown.indexOf(lift.firstSessionId);
      if (at <= 0) {
        lift.aboveSessionId = null;
        break;
      }
      lift.aboveSessionId = _shown[at - 1];
      final box = _box(sessionId: _shown[at - 1]);
      if (box == null) break;
      lift.takeInAbove(sessionId: _shown[at - 1], height: box.size.height);
    }
    while (true) {
      final at = _shown.indexOf(lift.lastSessionId);
      if (at < 0 || at == _shown.length - 1) break;
      final box = _box(sessionId: _shown[at + 1]);
      if (box == null) break;
      lift.takeInBelow(sessionId: _shown[at + 1], height: box.size.height);
    }
  }

  /// Scrolls the list a frame's worth toward the edge the lifted row is held
  /// at, until it is held there no more; the scroll moves the row along.
  void _scrollAtEdge(Duration elapsed) {
    final lift = _lift;
    if (lift == null) return;
    final seconds = (elapsed - lift.scrolledAt).inMicroseconds / Duration.microsecondsPerSecond;
    lift.scrolledAt = elapsed;
    _takeInBuiltRows(lift: lift);
    final pixels = lift.position.pixels;
    switch (lift.edgeScroll()) {
      case null:
        lift.autoscroll.stop();
      case (:final speed, :final limit):
        final to = pixels + speed * seconds;
        lift.position.jumpTo(speed < 0 ? math.max(to, limit) : math.min(to, limit));
    }
  }

  /// Puts the lifted row back where it was lifted, for a drag the pointer
  /// gave up on; the drop that follows then moves nothing.
  void _cancel() {
    if (_lift case final lift?) lift.index = lift.startIndex;
  }

  /// Lets go of [sessionId]'s lift when its row leaves the list mid-drag, so
  /// later drags are not refused. Its list is rebuilding already.
  void _abandon({required String sessionId}) {
    if (_lift case final lift? when lift.sessionId == sessionId) _letGo(lift: lift);
  }

  void _letGo({required _Lift lift}) {
    _lift = null;
    liftedTop.value = null;
    lift.position.removeListener(_follow);
    lift.autoscroll.dispose();
  }

  /// Drops the lifted row where it stands and, when that moved it, asks
  /// [move] to keep it there. Answers whether the bridge refused it.
  Future<bool> _drop({required PinnedRowMove move}) async {
    final lift = _lift;
    if (lift == null) return false;
    _letGo(lift: lift);
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

/// A pinned row's room in the list: whose it is and its height.
typedef _Slot = ({String sessionId, double height});

/// The lifted row and the other pinned rows built around it, top first, in
/// the list's scroll content, where they keep their places however it
/// scrolls; [index] is where among those others the lifted row stands.
final class _Lift({
  required final String sessionId,
  required final ScrollPosition position,

  /// The list's global top, where its scroll content starts.
  required final double viewportTop,

  /// The global top and bottom of the list's uncovered part, whose edges the
  /// copy is held at to scroll it.
  required final double Function() edgeTop,
  required final double edgeBottom,
  required final double height,

  /// Where the known pinned rows start, in the list's scroll content.
  required double groupTop,

  /// How far below the copy's top the pointer holds it.
  required final double grab,

  /// Where the pointer is now, globally.
  required double pointerY,

  /// Scrolls the list while the copy is held at its edge.
  required final Ticker autoscroll,
}) {
  double groupTop = groupTop;
  double pointerY = pointerY;
  final List<_Slot> others = [];
  int startIndex = 0;
  int index = 0;

  /// The pinned row right above the known ones, which a row dropped first
  /// lands below; null when the known ones start the pinned rows.
  String? aboveSessionId;

  /// The floating copy's global top.
  double top = 0;

  /// When [autoscroll] last scrolled the list.
  Duration scrolledAt = Duration.zero;

  double get groupBottom => others.fold(groupTop + height, (bottom, other) => bottom + other.height);

  /// The topmost and bottommost known rows, as the list orders them before
  /// the lift moved any.
  String get firstSessionId => startIndex == 0 ? sessionId : others.first.sessionId;
  String get lastSessionId => startIndex == others.length ? sessionId : others.last.sessionId;

  String? get afterSessionId => index == 0 ? aboveSessionId : others[index - 1].sessionId;

  /// How far the list's top edge is into its scroll content.
  double get _toContent => position.pixels - viewportTop;

  void takeInAbove({required String sessionId, required double height}) {
    others.insert(0, (sessionId: sessionId, height: height));
    groupTop -= height;
    startIndex++;
    index++;
  }

  void takeInBelow({required String sessionId, required double height}) =>
      others.add((sessionId: sessionId, height: height));

  /// Follows the pointer, held within the pinned rows, and stands the row
  /// before the first other row whose middle it has not passed, as those
  /// rows now stand around its room. Held against either end, it stands
  /// there, however its height compares with the row it meets.
  void follow() {
    final groupBottom = this.groupBottom;
    final contentTop = (pointerY - grab + _toContent).clamp(groupTop, groupBottom - height);
    top = contentTop - _toContent;
    if (contentTop <= groupTop || contentTop >= groupBottom - height) {
      index = contentTop <= groupTop ? 0 : others.length;
      return;
    }
    final middle = contentTop + height / 2;
    var y = groupTop;
    var passed = 0;
    for (final (at, other) in others.indexed) {
      if (at == index) y += height;
      if (y + other.height / 2 < middle) passed++;
      y += other.height;
    }
    index = passed;
  }

  /// How the list scrolls under the copy: toward the edge the copy is held
  /// within [_edgeScrollZone] of, faster the nearer it is, and no farther
  /// than [limit], where the pinned rows' end shows that far in from the
  /// edge or the list ends. Null when it does not scroll. A copy held at the
  /// pinned rows' end rides toward the edge with them, slowing the scroll as
  /// it nears [limit], so it stops within a pixel of it rather than creep on.
  ({double speed, double limit})? edgeScroll() {
    final pixels = position.pixels;
    final edgeTop = this.edgeTop();
    final fromTop = top - edgeTop;
    if (fromTop < _edgeScrollZone) {
      final limit = math.max(position.minScrollExtent, groupTop - _edgeScrollZone - (edgeTop - viewportTop));
      if (pixels <= limit + 1) return null;
      return (speed: -_edgeScrollMaxSpeed * math.min(1, (_edgeScrollZone - fromTop) / _edgeScrollZone), limit: limit);
    }
    final fromBottom = edgeBottom - top - height;
    if (fromBottom < _edgeScrollZone) {
      final limit = math.min(position.maxScrollExtent, groupBottom + _edgeScrollZone - (edgeBottom - viewportTop));
      if (pixels >= limit - 1) return null;
      return (speed: _edgeScrollMaxSpeed * math.min(1, (_edgeScrollZone - fromBottom) / _edgeScrollZone), limit: limit);
    }
    return null;
  }
}

/// A pinned row the user can drag within the pinned rows: with a mouse, a
/// press that moves lifts it at once, while a click still opens it and a
/// right click its menu. While [editing], a finger lifts it from the handle
/// at its end as soon as it touches it, and the row takes no other taps or
/// swipes. While lifted, the row keeps its room in the list, empty, and a
/// lifted copy of it follows the pointer over the list; on release the copy
/// glides into that room.
class const PinnedRowDrag({
  super.key,
  required final String sessionId,
  required final PinnedRowDragTracker tracker,

  /// Whether the list's pinned rows are being reordered by touch, which
  /// fades the handle in over the row's end.
  required final bool editing,

  /// Asked on a drop that moved the row.
  required final PinnedRowMove onMove,

  /// Called when the bridge refused a dropped row's move, after the rows slid
  /// back.
  required final VoidCallback onMoveRefused,

  /// Whether the row's corners are rounded, as a pointer row's are.
  required final BorderRadius borderRadius,

  /// The lifted copy's fill, and the handle's scrim: the row's own.
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

  // A row the list set aside, as it scrolled away, is no longer laid out.
  @override
  void deactivate() {
    widget.tracker._unregister(sessionId: widget.sessionId, context: context);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    widget.tracker._register(sessionId: widget.sessionId, context: context);
  }

  @override
  void dispose() {
    widget.tracker._abandon(sessionId: widget.sessionId);
    _lifted.dispose();
    _lift.dispose();
    _settling.dispose();
    _settle.dispose();
    super.dispose();
  }

  /// The finger holding the handle, while one lifted the row.
  int? _handleTouch;

  /// Lifts the row under a pointer at [pointerY]; false when it cannot be
  /// lifted now, as while another row is.
  bool _grab({required double pointerY}) {
    final room = _roomBox();
    final scrollable = Scrollable.maybeOf(context);
    if (room == null ||
        scrollable == null ||
        !widget.tracker._start(
          sessionId: widget.sessionId,
          room: room,
          scrollable: scrollable,
          pointerY: pointerY,
          vsync: this,
        )) {
      return false;
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
    return true;
  }

  void _onUpdate(DragUpdateDetails details) => widget.tracker._update(pointerY: details.globalPosition.dy);

  void _onHandleDown(PointerDownEvent event) {
    if (_handleTouch != null || !_grab(pointerY: event.position.dy)) return;
    _handleTouch = event.pointer;
    unawaited(HapticFeedback.lightImpact());
  }

  void _onHandleMove(PointerMoveEvent event) {
    if (event.pointer == _handleTouch) widget.tracker._update(pointerY: event.position.dy);
  }

  void _onHandleUp(PointerEvent event) {
    if (event.pointer != _handleTouch) return;
    _handleTouch = null;
    if (event is PointerCancelEvent) widget.tracker._cancel();
    _onEnd();
  }

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
          ..onStart = ((details) => _grab(pointerY: details.globalPosition.dy))
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
          child: Opacity(
            opacity: _portal.isShowing ? 0 : 1,
            child: _withHandle(
              context: context,
              // Reordering, the row neither opens nor swipes; the list still
              // scrolls under a finger on it.
              row: IgnorePointer(ignoring: widget.editing, child: widget.child),
              handle: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                // Takes the touch from the list's scroll at once, so the row
                // lifts on touch down, with no hold.
                gestures: {
                  EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                    EagerGestureRecognizer.new,
                    (_) {},
                  ),
                },
                child: Listener(
                  onPointerDown: _onHandleDown,
                  onPointerMove: _onHandleMove,
                  onPointerUp: _onHandleUp,
                  onPointerCancel: _onHandleUp,
                  child: _handleMark(context: context),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// [row] with [handle] over its end, faded in while [PinnedRowDrag.editing].
  Widget _withHandle({required BuildContext context, required Widget row, required Widget handle}) => Stack(
    fit: StackFit.passthrough,
    children: [
      row,
      PositionedDirectional(
        top: 0,
        bottom: 0,
        end: 0,
        child: IgnorePointer(
          ignoring: !widget.editing,
          child: AnimatedOpacity(
            opacity: widget.editing ? 1 : 0,
            duration: context.isReducedMotion ? Duration.zero : transcriptMotionDuration,
            curve: transcriptMotionCurve,
            child: handle,
          ),
        ),
      ),
    ],
  );

  /// The handle's ≡ on a scrim of the row's fill, which covers the time
  /// beneath it rather than moving anything.
  Widget _handleMark({required BuildContext context}) => ExcludeSemantics(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [widget.liftedColor.withValues(alpha: 0), widget.liftedColor],
          stops: const [0, 0.4],
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 2 * PregoSpacing.xl, end: PregoSpacing.xl),
        child: Align(
          widthFactor: 1,
          child: Icon(TablerRegular.menu_2, size: PregoIconSize.lg, color: context.prego.colors.fgQuaternary),
        ),
      ),
    ),
  );

  Widget _copy(BuildContext context) {
    final prego = context.prego;
    return FloatAt(
      origin: _copyOrigin,
      repaint: Listenable.merge([widget.tracker.liftedTop, _settling]),
      width: _width,
      interactive: false,
      clipAbove: null,
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
        child: _withHandle(
          context: context,
          row: widget.child,
          handle: _handleMark(context: context),
        ),
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
/// rebuilding and can track a list row that is still sliding. A null origin
/// paints nothing, and nothing paints above [clipAbove]'s global y, if any.
class const FloatAt({
  super.key,
  required final Offset? Function() origin,
  required final Listenable repaint,
  required final double width,

  /// Whether the child takes the taps on it, as a held heading's button
  /// does; otherwise the copy only keeps them from what is beneath it.
  required final bool interactive,
  required final double Function()? clipAbove,
  super.child,
}) extends SingleChildRenderObjectWidget {
  @override
  RenderFloatAt createRenderObject(BuildContext context) =>
      RenderFloatAt(origin: origin, repaint: repaint, width: width, interactive: interactive, clipAbove: clipAbove);

  @override
  void updateRenderObject(BuildContext context, RenderFloatAt renderObject) => renderObject
    ..origin = origin
    ..repaint = repaint
    ..width = width
    ..interactive = interactive
    ..clipAbove = clipAbove;
}

final class RenderFloatAt({
  required Offset? Function() origin,
  required Listenable repaint,
  required double width,
  required bool interactive,
  required double Function()? clipAbove,
}) extends RenderProxyBox {
  Offset? Function() origin = origin;
  bool interactive = interactive;
  double Function()? clipAbove = clipAbove;
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

  /// A copy takes the pointer from the rows beneath it, so they show no
  /// hover or title tooltip while a row is carried over them; an
  /// [interactive] one hands it to its child.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    final origin = this.origin();
    if (child == null || origin == null) return false;
    final at = globalToLocal(origin);
    if (!(at & child.size).contains(position) || position.dy < _clipTop) return false;
    if (interactive) {
      return result.addWithPaintOffset(
        offset: at,
        position: position,
        hitTest: (result, position) => child.hitTest(result, position: position),
      );
    }
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  /// A copy is only drawn: what assistive technology reads stays the list's
  /// own row or heading, not a duplicate wherever the copy may stand.
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {}

  /// The child stands where it paints, for its taps and for whoever locates it.
  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (origin() case final origin?) {
      final at = globalToLocal(origin);
      transform.translateByDouble(at.dx, at.dy, 0, 1);
    }
  }

  /// Where the copy is cut off, in local terms.
  double get _clipTop => switch (clipAbove) {
    final clipAbove? => globalToLocal(Offset(0, clipAbove())).dy,
    null => double.negativeInfinity,
  };

  @override
  void paint(PaintingContext context, Offset offset) {
    final (child, origin) = (this.child, this.origin());
    if (child == null || origin == null) return;
    final at = globalToLocal(origin);
    if (clipAbove == null) return context.paintChild(child, offset + at);
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Rect.fromLTRB(0, _clipTop, size.width, size.height),
      (context, offset) => context.paintChild(child, offset + at),
      oldLayer: _clip.layer,
    );
  }

  final LayerHandle<ClipRectLayer> _clip = LayerHandle();

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}
