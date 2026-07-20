import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/prego_reduced_motion.dart';
import '../theme/prego_theme.dart';

/// Builds the secondary actions revealed behind a [PregoSwipeActions] row.
///
/// [close] settles the row shut — call it first in an action's tap handler so
/// the row is already closing while the action's effect (a dialog, a snackbar)
/// plays out.
typedef PregoSwipeActionListBuilder = List<Widget> Function(BuildContext context, VoidCallback close);

/// Builds the primary action of a [PregoSwipeActions] row. Same [close]
/// contract as [PregoSwipeActionListBuilder].
typedef PregoSwipeActionBuilder = Widget Function(BuildContext context, VoidCallback close);

/// A list row that swipes toward its start edge to reveal trailing actions —
/// the iOS-Mail treatment: a partial swipe settles the row open with the
/// actions tappable; continuing the swipe past the commit threshold and
/// releasing runs [onFullSwipe] directly.
///
/// A row can also carry one leading action ([leadingPrimaryActionBuilder]),
/// revealed by the opposite swipe and committed by [onLeadingFullSwipe], with
/// the same mechanics mirrored — the mail-app mark-unread position. A single
/// action rather than a strip, because no host has needed more on that edge.
///
/// The actions trail the sliding content's edge (drawer motion), so the design
/// reads as one strip: content, then actions, clipped to the row. During an
/// overdrag past a side's open width its primary action stretches — the edge
/// away from the content stays pinned to the row's edge while the body grows
/// into the extra drag — which, with a haptic tick at the threshold, is the
/// cue that releasing will commit.
///
/// The row closes itself on the interactions that would otherwise fight an
/// open row: a tap anywhere outside it (which also keeps at most one row open
/// per list, since a drag on a sibling starts with a pointer-down outside this
/// one), a tap on the row's own content (absorbed, so the row doesn't also
/// activate), and any scroll of the enclosing scrollable.
///
/// While the row settles shut the strips keep rendering the children captured
/// as the close began: the tapped or committed action often just changed the
/// very state its own label derives from (a read toggle), and a live rebuild
/// would morph the still-visible pill into its opposite mid-settle. Fresh
/// builder output applies again once the row is closed.
///
/// The gesture is undiscoverable to assistive tech by nature; hosts must keep
/// an alternative path to the same actions (the project row's long-press
/// menu). While a side is closed its actions are excluded from semantics and
/// focus traversal entirely, so the row still reads as one button.
class PregoSwipeActions extends StatefulWidget {
  const PregoSwipeActions({
    super.key,
    required this.child,
    required this.actionsBuilder,
    required this.primaryActionBuilder,
    required this.onFullSwipe,
    this.leadingPrimaryActionBuilder,
    this.onLeadingFullSwipe,
    this.showBottomHairline = false,
  }) : assert(
         (leadingPrimaryActionBuilder == null) == (onLeadingFullSwipe == null),
         'A leading action takes both its builder and its full-swipe commit.',
       );

  /// The row content. Slides off the swiped-toward edge as the row opens.
  final Widget child;

  /// The trailing secondary actions, laid out in order before the trailing
  /// primary action.
  final PregoSwipeActionListBuilder actionsBuilder;

  /// The trailing primary action — the one a full swipe toward the start edge
  /// commits. Rests at its own natural width; during an overdrag the component
  /// re-boxes it wider (that width plus the surplus), so it must fill any
  /// extra width it is given — content that centers itself in a stretched box,
  /// the way the design system's buttons lay out.
  final PregoSwipeActionBuilder primaryActionBuilder;

  /// Committed by a full swipe toward the start edge: called once on release
  /// past the commit threshold, while the row settles shut. The action owns
  /// any row removal; if it fails, the row is simply closed.
  final VoidCallback onFullSwipe;

  /// The single leading action, revealed by swiping toward the end edge; null
  /// leaves that swipe inert. Same width contract as [primaryActionBuilder],
  /// mirrored: its leading edge pins to the row's start while an overdrag
  /// grows it.
  final PregoSwipeActionBuilder? leadingPrimaryActionBuilder;

  /// The leading counterpart of [onFullSwipe], with the same contract. Set
  /// exactly when [leadingPrimaryActionBuilder] is.
  final VoidCallback? onLeadingFullSwipe;

  /// Draws a row divider along the bottom edge, outside the sliding stack, so
  /// the divider holds still while the row's content slides. A zero-width
  /// border side is a single physical pixel and costs the row no height, so
  /// the divider doesn't push the list off its pitch. Off by default.
  final bool showBottomHairline;

  @override
  State<PregoSwipeActions> createState() => _PregoSwipeActionsState();
}

/// How long a settle (open, close) runs when motion is allowed.
const Duration _settleDuration = Duration(milliseconds: 220);

/// The fraction of the row's width past which releasing commits the full
/// swipe, on either side.
const double _commitFraction = 0.6;

/// The overdrag past a side's reveal before its commit can arm, when the
/// reveal itself reaches further than the row-width fraction. Enough for the
/// stretch cue to be seen before releasing means committing.
const double _commitClearance = 64;

/// Velocity (logical px/s along the drag axis) treated as a fling: an opening
/// fling settles the row open from any distance, a closing fling settles it
/// shut and cancels a pending commit.
const double _flingVelocity = 700;

/// One build's strip children, captured as a unit when a close settle begins.
typedef _StripChildren = ({List<Widget> actions, Widget primary, Widget? leadingPrimary});

class _PregoSwipeActionsState extends State<PregoSwipeActions> with SingleTickerProviderStateMixin {
  /// 0 is closed, and the sign is the open side: positive slides the content
  /// toward the start edge (trailing actions), negative toward the end edge
  /// (the leading action). The magnitude times the row width is the pixel
  /// extent, so thresholds stay proportional if the row resizes mid-gesture.
  late final AnimationController _controller = AnimationController(vsync: this, value: 0, lowerBound: -1);

  final _SwipeSide _trailing = _SwipeSide(sign: 1);

  final _SwipeSide _leading = _SwipeSide(sign: -1);

  double _rowWidth = 0;

  bool _dragging = false;

  /// The extent's sign as the current drag began — the side the gesture found
  /// the row on. A fling toward the opposite side then reads as a closing
  /// fling even when its last pixels overshot past zero.
  double _dragStartSide = 0;

  /// Tracks threshold crossings during a drag, for the haptic edges and the
  /// release decision.
  bool _pastCommit = false;

  /// Set when a release fires a full-swipe commit, so the closing settle's
  /// still-large extents cannot re-arm [_pastCommit] on a re-grab and fire the
  /// same commit twice. Cleared once the extent retreats below the threshold —
  /// a fresh crossing after that is a new decision.
  bool _commitFired = false;

  /// The strip children as last built — what a beginning close settle
  /// captures.
  _StripChildren? _lastBuiltStrips;

  /// While a close settle runs, the children captured as it began; the strips
  /// render these instead of fresh builder output, so the closing action's
  /// own state change cannot morph the still-visible pill mid-settle. Null
  /// whenever rebuilds are live: at rest, dragging, or settling open.
  _StripChildren? _frozenStrips;

  /// The scroll position being watched while the row is revealed, so any list
  /// scroll closes it. Null while closed.
  ScrollPosition? _watchedScroll;

  bool get _hasLeading => widget.leadingPrimaryActionBuilder != null;

  double get _extent => _controller.value * _rowWidth;

  /// The side an extent of [sign] opens; zero reads as trailing.
  _SwipeSide _sideOf({required double sign}) => sign < 0 ? _leading : _trailing;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncScrollWatch);
    _controller.addListener(_syncStripThaw);
  }

  @override
  void dispose() {
    _unwatchScroll();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strips =
        _frozenStrips ??
        (
          actions: widget.actionsBuilder(context, _close),
          primary: widget.primaryActionBuilder(context, _close),
          leadingPrimary: widget.leadingPrimaryActionBuilder?.call(context, _close),
        );
    _lastBuiltStrips = strips;
    final actions = strips.actions;
    final primary = strips.primary;
    final leadingPrimary = strips.leadingPrimary;

    final row = TapRegion(
      onTapOutside: (_) => _handleTapOutside(),
      child: GestureDetector(
        onHorizontalDragStart: _handleDragStart,
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        onHorizontalDragCancel: _handleDragCancel,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _rowWidth = constraints.maxWidth;
            return ClipRect(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final extent = _extent;
                  // The content and the strips translate as one: each strip
                  // sits just past its own edge of the row and follows the
                  // content's edge in.
                  final dx = Directionality.of(context) == TextDirection.rtl ? extent : -extent;
                  final shift = Offset(dx, 0);
                  return Stack(
                    children: [
                      Transform.translate(offset: shift, child: widget.child),
                      _positionedStrip(side: _trailing, actions: actions, primary: primary, extent: extent, shift: shift),
                      if (leadingPrimary != null)
                        _positionedStrip(side: _leading, actions: const [], primary: leadingPrimary, extent: extent, shift: shift),
                      if (extent != 0)
                        // Absorbs taps on the revealed row's content so it
                        // closes instead of activating; sized to spare the open
                        // side's actions, which stay tappable.
                        PositionedDirectional(
                          start: extent > 0 ? 0 : -extent,
                          end: extent > 0 ? extent : 0,
                          top: 0,
                          bottom: 0,
                          child: ExcludeSemantics(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _close,
                              onSecondaryTap: _close,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
    if (!widget.showBottomHairline) return row;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.prego.colors.borderTertiary, width: 0)),
      ),
      child: row,
    );
  }

  /// One side's strip, laid out just past its own edge of the row so the
  /// shared [shift] carries it in with the content. While the side is closed
  /// its actions must be inert chrome: excluded from semantics (the row reads
  /// as one merged button, and the host's menu remains the assistive path to
  /// the same actions) and from focus traversal (the clipped pills must not be
  /// invisible tab stops).
  Widget _positionedStrip({
    required _SwipeSide side,
    required List<Widget> actions,
    required Widget primary,
    required double extent,
    required Offset shift,
  }) {
    final closed = side.closedAt(extent: extent);
    return PositionedDirectional(
      start: side.sign > 0 ? _rowWidth : null,
      end: side.sign > 0 ? null : _rowWidth,
      top: 0,
      bottom: 0,
      child: Transform.translate(
        offset: shift,
        child: ExcludeSemantics(
          excluding: closed,
          child: ExcludeFocus(
            excluding: closed,
            child: side.buildStrip(actions: actions, primary: primary, extent: extent),
          ),
        ),
      ),
    );
  }

  // ── Gesture handling ───────────────────────────────────────────────────────

  void _handleDragStart(DragStartDetails details) {
    _dragging = true;
    _controller.stop();
    // A re-grab mid-close takes the row back to live rebuilds.
    if (_frozenStrips != null) setState(() => _frozenStrips = null);
    _dragStartSide = _extent.sign;
    _trailing.measureIfResting(extent: _extent);
    _leading.measureIfResting(extent: _extent);
    // A re-grab of a held overdrag stays armed — unless the extent is the
    // closing settle of a commit that already fired.
    _pastCommit = !_commitFired && _extent.abs() >= _commitThreshold(extent: _extent);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_rowWidth <= 0) return;
    final floor = _hasLeading ? -_rowWidth : 0.0;
    final extent = (_extent + _toExtentDelta(details.primaryDelta ?? 0)).clamp(floor, _rowWidth);
    _controller.value = extent / _rowWidth;

    final threshold = _commitThreshold(extent: extent);
    if (extent.abs() < threshold) _commitFired = false;
    final past = !_commitFired && extent.abs() >= threshold;
    if (past == _pastCommit) return;
    _pastCommit = past;
    // The threshold is otherwise only visible as the stretch's progression;
    // the tick marks the exact point past which releasing commits (and the
    // lighter one, dragging back out again).
    unawaited(past ? HapticFeedback.lightImpact() : HapticFeedback.selectionClick());
  }

  void _handleDragEnd(DragEndDetails details) {
    _dragging = false;
    // Velocity in extent terms: positive drives toward the trailing side, the
    // way the extent itself grows.
    final velocity = _toExtentDelta(details.primaryVelocity ?? 0);
    final side = _extent.sign;
    // A deliberate fling back cancels a pending commit — position alone would
    // read a fast "changed my mind" swipe as a commit.
    if (_pastCommit && side * velocity > -_flingVelocity) {
      _commitFired = true;
      // A negative side only exists with a leading action, whose constructor
      // pairs the builder with its commit.
      (side < 0 ? widget.onLeadingFullSwipe : widget.onFullSwipe)?.call();
      _close();
      return;
    }
    if (velocity.abs() > _flingVelocity) {
      final flingSide = velocity.sign;
      if (_flingOpens(side: flingSide)) {
        _settleTo(flingSide * _sideOf(sign: flingSide).reveal);
      } else {
        _close();
      }
      return;
    }
    _settleToNearest();
  }

  /// Whether a fling toward [side] reads as opening it — otherwise it is a
  /// closing fling for the other side. Opening needs actions on [side], the
  /// extent at or past zero toward it (exactly zero is the violent short flick
  /// whose whole delta went to winning the gesture arena), and — when the drag
  /// began with the opposite side open — the gesture to have crossed
  /// meaningfully in, past the point where a plain release would settle [side]
  /// open anyway. A hard close that overshoots zero by a few pixels then
  /// settles closed instead of bouncing the opposite side open.
  bool _flingOpens({required double side}) {
    if (side < 0 && !_hasLeading) return false;
    final toward = _extent * side;
    if (toward < 0) return false;
    if (_dragStartSide == -side) return toward > _sideOf(sign: side).reveal / 2;
    return true;
  }

  void _handleDragCancel() {
    _dragging = false;
    _settleToNearest();
  }

  void _handleTapOutside() {
    if (_extent == 0 || _dragging) return;
    _close();
  }

  /// The extent past which releasing commits, for the side [extent] is open
  /// toward. A fraction of the row's width — but never inside the side's own
  /// reveal: a strip that is wide on its row (long labels, large text scales,
  /// narrow screens) must keep a reachable open state, so its commit only
  /// arms once the overdrag has stretched visibly past it. And never past the
  /// row's width, which is as far as the drag itself reaches: when the reveal
  /// plus its clearance would put the threshold out of range, the full-width
  /// drag still arms.
  double _commitThreshold({required double extent}) => math.min(
    _rowWidth,
    math.max(_commitFraction * _rowWidth, _sideOf(sign: extent.sign).reveal + _commitClearance),
  );

  /// Extent grows positive toward the start edge: a leftward drag in LTR,
  /// rightward in RTL.
  double _toExtentDelta(double primaryDelta) =>
      Directionality.of(context) == TextDirection.rtl ? primaryDelta : -primaryDelta;

  // ── Settling ───────────────────────────────────────────────────────────────

  void _close() => _settleTo(0);

  void _settleToNearest() {
    final side = _extent.sign;
    final reveal = _sideOf(sign: side).reveal;
    _settleTo(_extent.abs() > reveal / 2 ? side * reveal : 0);
  }

  void _settleTo(double target) {
    // The close callback escapes to host action handlers, which may hold it
    // across an await that outlives the row.
    if (!mounted || _rowWidth <= 0) return;
    if (target == 0 && _extent != 0) {
      // A second close mid-close keeps the original capture.
      _frozenStrips ??= _lastBuiltStrips;
    } else {
      _frozenStrips = null;
    }
    final value = (target / _rowWidth).clamp(-1.0, 1.0);
    if (prefersReducedMotion(context)) {
      _controller.value = value;
      return;
    }
    unawaited(_controller.animateTo(value, duration: _settleDuration, curve: Curves.easeOutCubic));
  }

  /// Thaws the frozen strips once the close settle lands, so the very next
  /// build picks up fresh builder output again.
  void _syncStripThaw() {
    if (_frozenStrips == null || _controller.value != 0) return;
    setState(() => _frozenStrips = null);
  }

  // ── Close on scroll ────────────────────────────────────────────────────────

  /// Watches the enclosing scrollable exactly while the row is revealed.
  void _syncScrollWatch() {
    final revealed = _controller.value != 0;
    if (revealed && _watchedScroll == null) {
      final scrollable = context.findAncestorStateOfType<ScrollableState>();
      if (scrollable == null) return;
      _watchedScroll = scrollable.position;
      _watchedScroll?.addListener(_handleScroll);
    } else if (!revealed) {
      _unwatchScroll();
    }
  }

  void _handleScroll() {
    if (_dragging) return;
    _close();
  }

  void _unwatchScroll() {
    _watchedScroll?.removeListener(_handleScroll);
    _watchedScroll = null;
  }
}

/// One side of a [PregoSwipeActions] row — the trailing strip or the leading
/// action — so each per-side mechanic (measurement, overdrag stretch, strip
/// layout) exists once, instantiated for both sides.
class _SwipeSide {
  _SwipeSide({required this.sign});

  /// The extent sign that opens this side: positive trailing, negative
  /// leading.
  final double sign;

  final GlobalKey stripKey = GlobalKey();

  final GlobalKey primaryKey = GlobalKey();

  /// Measured from the strip as laid out, so token or label changes never
  /// desync the settle target from the rendered actions.
  double? revealWidth;

  /// The primary action at its natural width — the base its overdrag stretch
  /// grows from. Measured alongside [revealWidth], under the same staleness
  /// contract.
  double? primaryWidth;

  double get reveal => revealWidth ?? 0;

  /// Whether [extent] leaves this side closed — at zero or open toward the
  /// other side.
  bool closedAt({required double extent}) => extent * sign <= 0;

  /// How far [extent] has overdragged past this side's reveal; zero through
  /// the reveal and while unmeasured.
  double surplusAt({required double extent}) => math.max(0, extent * sign - (revealWidth ?? double.infinity));

  /// The width imposed on this side's primary action while an overdrag
  /// stretches it. Null at rest and through the reveal, which leaves the
  /// action its natural width.
  double? stretchTargetAt({required double extent}) {
    final surplus = surplusAt(extent: extent);
    final natural = primaryWidth;
    if (surplus <= 0 || natural == null) return null;
    return natural + surplus;
  }

  /// The settle targets are the action strips as laid out, and the stretch
  /// bases each primary's own size within its strip. A side's measurements are
  /// only trustworthy while that side is not stretched, so a re-grab
  /// mid-overdrag keeps its previous ones.
  void measureIfResting({required double extent}) {
    if (surplusAt(extent: extent) > 0) return;
    revealWidth = _measuredWidth(key: stripKey) ?? revealWidth;
    primaryWidth = _measuredWidth(key: primaryKey) ?? primaryWidth;
  }

  static double? _measuredWidth({required GlobalKey key}) {
    final box = key.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size.width : null;
  }

  /// The gap on the content side separates the strip from the sliding content
  /// edge; the inset on the outer side matches the row's own horizontal
  /// padding so the open actions sit flush with the rest of the screen's
  /// content. A Row for its cross-axis behavior — the strip spans the row's
  /// height, and the actions must center in it, not stretch to it.
  Widget buildStrip({required List<Widget> actions, required Widget primary, required double extent}) {
    return KeyedSubtree(
      key: stripKey,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: sign > 0 ? PregoSpacing.sm : PregoSpacing.xl,
          end: sign > 0 ? PregoSpacing.xl : PregoSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: PregoSpacing.sm,
          children: [
            ...actions,
            SizedBox(key: primaryKey, width: stretchTargetAt(extent: extent), child: primary),
          ],
        ),
      ),
    );
  }
}
