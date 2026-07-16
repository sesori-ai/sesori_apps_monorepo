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
/// The actions trail the sliding content's edge (drawer motion), so the design
/// reads as one strip: content, then actions, clipped to the row. During an
/// overdrag past the open width the primary action stretches — its trailing
/// edge stays pinned to the row's end while its body grows into the extra drag
/// — which, with a haptic tick at the threshold, is the cue that releasing
/// will commit.
///
/// The row closes itself on the interactions that would otherwise fight an
/// open row: a tap anywhere outside it (which also keeps at most one row open
/// per list, since a drag on a sibling starts with a pointer-down outside this
/// one), a tap on the row's own content (absorbed, so the row doesn't also
/// activate), and any scroll of the enclosing scrollable.
///
/// The gesture is undiscoverable to assistive tech by nature; hosts must keep
/// an alternative path to the same actions (the project row's long-press
/// menu). While closed the actions are excluded from semantics entirely, so
/// the row still reads as one button.
class PregoSwipeActions extends StatefulWidget {
  const PregoSwipeActions({
    super.key,
    required this.child,
    required this.actionsBuilder,
    required this.primaryActionBuilder,
    required this.onFullSwipe,
  });

  /// The row content. Slides toward the start edge as the row opens.
  final Widget child;

  /// The secondary actions, laid out in order before the primary action.
  final PregoSwipeActionListBuilder actionsBuilder;

  /// The primary action — the one a full swipe commits. Rests at its own
  /// natural width; during an overdrag the component re-boxes it wider (that
  /// width plus the surplus), so it must fill any extra width it is given —
  /// content that centers itself in a stretched box, the way the design
  /// system's buttons lay out.
  final PregoSwipeActionBuilder primaryActionBuilder;

  /// Committed by a full swipe: called once on release past the commit
  /// threshold, while the row settles shut. The action owns any row removal;
  /// if it fails, the row is simply closed.
  final VoidCallback onFullSwipe;

  @override
  State<PregoSwipeActions> createState() => _PregoSwipeActionsState();
}

/// How long a settle (open, close) runs when motion is allowed.
const Duration _settleDuration = Duration(milliseconds: 220);

/// The fraction of the row's width past which releasing commits the full
/// swipe.
const double _commitFraction = 0.6;

/// Velocity (logical px/s along the drag axis) treated as a fling: an opening
/// fling settles the row open from any distance, a closing fling settles it
/// shut and cancels a pending commit.
const double _flingVelocity = 700;

class _PregoSwipeActionsState extends State<PregoSwipeActions> with SingleTickerProviderStateMixin {
  /// 0 is closed, 1 is the content slid fully off the row. The pixel extent is
  /// this value times the row width, so thresholds stay proportional if the
  /// row resizes mid-gesture.
  late final AnimationController _controller = AnimationController(vsync: this);

  final GlobalKey _stripKey = GlobalKey();

  final GlobalKey _primaryKey = GlobalKey();

  double _rowWidth = 0;

  /// Measured from the actions strip's laid-out size, so token or label
  /// changes never desync the settle target from the rendered actions.
  double? _revealWidth;

  /// The primary action's natural width — the base the overdrag stretch grows
  /// from. Measured alongside [_revealWidth], under the same staleness
  /// contract.
  double? _primaryWidth;

  bool _dragging = false;

  /// Tracks threshold crossings during a drag, for the haptic edges and the
  /// release decision.
  bool _pastCommit = false;

  /// The scroll position being watched while the row is revealed, so any list
  /// scroll closes it. Null while closed.
  ScrollPosition? _watchedScroll;

  double get _extent => _controller.value * _rowWidth;

  double get _overdragSurplus => math.max(0, _extent - (_revealWidth ?? double.infinity));

  /// The width imposed on the primary action while the overdrag stretches it.
  /// Null at rest and through the reveal, which leaves the action its natural
  /// width.
  double? get _primaryStretchTarget {
    final surplus = _overdragSurplus;
    final natural = _primaryWidth;
    if (surplus <= 0 || natural == null) return null;
    return natural + surplus;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncScrollWatch);
  }

  @override
  void dispose() {
    _unwatchScroll();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.actionsBuilder(context, _close);
    final primary = widget.primaryActionBuilder(context, _close);

    return TapRegion(
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
                  // The content and the actions translate as one strip; the
                  // actions sit just past the content's end edge and follow it
                  // in.
                  final dx = Directionality.of(context) == TextDirection.rtl ? extent : -extent;
                  final shift = Offset(dx, 0);
                  return Stack(
                    children: [
                      Transform.translate(offset: shift, child: widget.child),
                      PositionedDirectional(
                        start: _rowWidth,
                        top: 0,
                        bottom: 0,
                        child: Transform.translate(
                          offset: shift,
                          // Off-screen actions must not be announced: while
                          // closed the row reads as one merged button, and the
                          // host's menu remains the assistive path to the same
                          // actions.
                          child: ExcludeSemantics(
                            excluding: extent == 0,
                            child: _actionsStrip(actions: actions, primary: primary),
                          ),
                        ),
                      ),
                      if (extent > 0)
                        // Absorbs taps on the revealed row's content so it
                        // closes instead of activating; sized to spare the
                        // actions, which stay tappable.
                        PositionedDirectional(
                          start: 0,
                          end: extent,
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
  }

  Widget _actionsStrip({required List<Widget> actions, required Widget primary}) {
    return KeyedSubtree(
      key: _stripKey,
      child: Padding(
        // Start gap separates the strip from the sliding content edge; the end
        // inset matches the row's own horizontal padding so the open actions
        // sit flush with the rest of the screen's content.
        padding: const EdgeInsetsDirectional.only(start: PregoSpacing.sm, end: PregoSpacing.xl),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: PregoSpacing.sm,
          children: [
            ...actions,
            SizedBox(key: _primaryKey, width: _primaryStretchTarget, child: primary),
          ],
        ),
      ),
    );
  }

  // ── Gesture handling ───────────────────────────────────────────────────────

  void _handleDragStart(DragStartDetails details) {
    _dragging = true;
    _controller.stop();
    _measureRestingWidths();
    _pastCommit = _extent >= _commitThreshold;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_rowWidth <= 0) return;
    final extent = (_extent + _toExtentDelta(details.primaryDelta ?? 0)).clamp(0.0, _rowWidth);
    _controller.value = extent / _rowWidth;

    final past = extent >= _commitThreshold;
    if (past == _pastCommit) return;
    _pastCommit = past;
    // The threshold is otherwise only visible as the stretch's progression;
    // the tick marks the exact point past which releasing commits (and the
    // lighter one, dragging back out again).
    unawaited(past ? HapticFeedback.lightImpact() : HapticFeedback.selectionClick());
  }

  void _handleDragEnd(DragEndDetails details) {
    _dragging = false;
    final velocity = _toExtentDelta(details.primaryVelocity ?? 0);
    // A deliberate fling back cancels a pending commit — position alone would
    // read a fast "changed my mind" swipe as a commit.
    if (_pastCommit && velocity > -_flingVelocity) {
      widget.onFullSwipe();
      _close();
      return;
    }
    if (velocity > _flingVelocity) {
      _settleTo(_revealWidth ?? 0);
      return;
    }
    if (velocity < -_flingVelocity) {
      _close();
      return;
    }
    _settleToNearest();
  }

  void _handleDragCancel() {
    _dragging = false;
    _settleToNearest();
  }

  void _handleTapOutside() {
    if (_extent == 0 || _dragging) return;
    _close();
  }

  double get _commitThreshold => _commitFraction * _rowWidth;

  /// Extent grows toward the start edge: a leftward drag in LTR, rightward in
  /// RTL.
  double _toExtentDelta(double primaryDelta) =>
      Directionality.of(context) == TextDirection.rtl ? primaryDelta : -primaryDelta;

  /// The settle target is the actions strip as laid out, and the stretch base
  /// is the primary action's own size within it. Only trustworthy while
  /// nothing is stretched, so a re-grab mid-overdrag keeps the previous
  /// measurements.
  void _measureRestingWidths() {
    if (_overdragSurplus > 0) return;
    final strip = _stripKey.currentContext?.findRenderObject();
    if (strip is RenderBox && strip.hasSize) _revealWidth = strip.size.width;
    final primary = _primaryKey.currentContext?.findRenderObject();
    if (primary is RenderBox && primary.hasSize) _primaryWidth = primary.size.width;
  }

  // ── Settling ───────────────────────────────────────────────────────────────

  void _close() => _settleTo(0);

  void _settleToNearest() {
    final reveal = _revealWidth ?? 0;
    _settleTo(_extent > reveal / 2 ? reveal : 0);
  }

  void _settleTo(double target) {
    // The close callback escapes to host action handlers, which may hold it
    // across an await that outlives the row.
    if (!mounted || _rowWidth <= 0) return;
    final value = (target / _rowWidth).clamp(0.0, 1.0);
    if (prefersReducedMotion(context)) {
      _controller.value = value;
      return;
    }
    unawaited(_controller.animateTo(value, duration: _settleDuration, curve: Curves.easeOutCubic));
  }

  // ── Close on scroll ────────────────────────────────────────────────────────

  /// Watches the enclosing scrollable exactly while the row is revealed.
  void _syncScrollWatch() {
    final revealed = _controller.value > 0;
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
