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
/// The gesture is undiscoverable to assistive tech by nature; hosts must keep
/// an alternative path to the same actions (the project row's long-press
/// menu). While a side is closed its actions are excluded from semantics
/// entirely, so the row still reads as one button.
class PregoSwipeActions extends StatefulWidget {
  const PregoSwipeActions({
    super.key,
    required this.child,
    required this.actionsBuilder,
    required this.primaryActionBuilder,
    required this.onFullSwipe,
    this.leadingPrimaryActionBuilder,
    this.onLeadingFullSwipe,
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

  @override
  State<PregoSwipeActions> createState() => _PregoSwipeActionsState();
}

/// How long a settle (open, close) runs when motion is allowed.
const Duration _settleDuration = Duration(milliseconds: 220);

/// The fraction of the row's width past which releasing commits the full
/// swipe, on either side.
const double _commitFraction = 0.6;

/// Velocity (logical px/s along the drag axis) treated as a fling: an opening
/// fling settles the row open from any distance, a closing fling settles it
/// shut and cancels a pending commit.
const double _flingVelocity = 700;

class _PregoSwipeActionsState extends State<PregoSwipeActions> with SingleTickerProviderStateMixin {
  /// 0 is closed, and the sign is the open side: positive slides the content
  /// toward the start edge (trailing actions), negative toward the end edge
  /// (the leading action). The magnitude times the row width is the pixel
  /// extent, so thresholds stay proportional if the row resizes mid-gesture.
  late final AnimationController _controller = AnimationController(vsync: this, value: 0, lowerBound: -1);

  final GlobalKey _trailingStripKey = GlobalKey();

  final GlobalKey _trailingPrimaryKey = GlobalKey();

  final GlobalKey _leadingStripKey = GlobalKey();

  final GlobalKey _leadingPrimaryKey = GlobalKey();

  double _rowWidth = 0;

  /// Measured from each side's strip as laid out, so token or label changes
  /// never desync the settle target from the rendered actions.
  double? _trailingRevealWidth;
  double? _leadingRevealWidth;

  /// Each side's primary action at its natural width — the base its overdrag
  /// stretch grows from. Measured alongside the reveal widths, under the same
  /// staleness contract.
  double? _trailingPrimaryWidth;
  double? _leadingPrimaryWidth;

  bool _dragging = false;

  /// Tracks threshold crossings during a drag, for the haptic edges and the
  /// release decision.
  bool _pastCommit = false;

  /// The scroll position being watched while the row is revealed, so any list
  /// scroll closes it. Null while closed.
  ScrollPosition? _watchedScroll;

  bool get _hasLeading => widget.leadingPrimaryActionBuilder != null;

  double get _extent => _controller.value * _rowWidth;

  double get _trailingSurplus => math.max(0, _extent - (_trailingRevealWidth ?? double.infinity));

  double get _leadingSurplus => math.max(0, -_extent - (_leadingRevealWidth ?? double.infinity));

  /// The width imposed on a side's primary action while an overdrag stretches
  /// it. Null at rest and through the reveal, which leaves the action its
  /// natural width.
  double? get _trailingStretchTarget =>
      _stretchTarget(surplus: _trailingSurplus, natural: _trailingPrimaryWidth);

  double? get _leadingStretchTarget => _stretchTarget(surplus: _leadingSurplus, natural: _leadingPrimaryWidth);

  double? _stretchTarget({required double surplus, required double? natural}) {
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
    final leadingPrimary = widget.leadingPrimaryActionBuilder?.call(context, _close);

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
                  // The content and the strips translate as one: each strip
                  // sits just past its own edge of the row and follows the
                  // content's edge in.
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
                          // Off-screen actions must not be announced: with the
                          // side closed the row reads as one merged button, and
                          // the host's menu remains the assistive path to the
                          // same actions.
                          child: ExcludeSemantics(
                            excluding: extent <= 0,
                            child: _trailingStrip(actions: actions, primary: primary),
                          ),
                        ),
                      ),
                      if (leadingPrimary != null)
                        PositionedDirectional(
                          end: _rowWidth,
                          top: 0,
                          bottom: 0,
                          child: Transform.translate(
                            offset: shift,
                            child: ExcludeSemantics(
                              excluding: extent >= 0,
                              child: _leadingStrip(primary: leadingPrimary),
                            ),
                          ),
                        ),
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
  }

  Widget _trailingStrip({required List<Widget> actions, required Widget primary}) {
    return KeyedSubtree(
      key: _trailingStripKey,
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
            SizedBox(key: _trailingPrimaryKey, width: _trailingStretchTarget, child: primary),
          ],
        ),
      ),
    );
  }

  /// The mirror of [_trailingStrip] down to its insets: outer edge flush with
  /// the screen's content, inner gap against the sliding content edge. Still a
  /// Row for its cross-axis behavior — the strip spans the row's height, and
  /// the action must center in it, not stretch to it.
  Widget _leadingStrip({required Widget primary}) {
    return KeyedSubtree(
      key: _leadingStripKey,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xl, end: PregoSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(key: _leadingPrimaryKey, width: _leadingStretchTarget, child: primary),
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
    _pastCommit = _extent.abs() >= _commitThreshold;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_rowWidth <= 0) return;
    final floor = _hasLeading ? -_rowWidth : 0.0;
    final extent = (_extent + _toExtentDelta(details.primaryDelta ?? 0)).clamp(floor, _rowWidth);
    _controller.value = extent / _rowWidth;

    final past = extent.abs() >= _commitThreshold;
    if (past == _pastCommit) return;
    _pastCommit = past;
    // The threshold is otherwise only visible as the stretch's progression;
    // the tick marks the exact point past which releasing commits (and the
    // lighter one, dragging back out again).
    unawaited(past ? HapticFeedback.lightImpact() : HapticFeedback.selectionClick());
  }

  void _handleDragEnd(DragEndDetails details) {
    _dragging = false;
    // The release reads relative to the side the row is open toward: positive
    // velocity opens that side further, negative closes it.
    final side = _extent.sign;
    final velocity = side * _toExtentDelta(details.primaryVelocity ?? 0);
    // A deliberate fling back cancels a pending commit — position alone would
    // read a fast "changed my mind" swipe as a commit.
    if (_pastCommit && velocity > -_flingVelocity) {
      // A negative side only exists with a leading action, whose constructor
      // pairs the builder with its commit.
      (side < 0 ? widget.onLeadingFullSwipe : widget.onFullSwipe)?.call();
      _close();
      return;
    }
    if (velocity > _flingVelocity) {
      _settleTo(side * _revealOf(side));
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

  /// Extent grows positive toward the start edge: a leftward drag in LTR,
  /// rightward in RTL.
  double _toExtentDelta(double primaryDelta) =>
      Directionality.of(context) == TextDirection.rtl ? primaryDelta : -primaryDelta;

  double _revealOf(double side) => side < 0 ? (_leadingRevealWidth ?? 0) : (_trailingRevealWidth ?? 0);

  /// The settle targets are the action strips as laid out, and the stretch
  /// bases each primary's own size within its strip. A side's measurements are
  /// only trustworthy while that side is not stretched, so a re-grab
  /// mid-overdrag keeps its previous ones.
  void _measureRestingWidths() {
    if (_trailingSurplus <= 0) {
      _trailingRevealWidth = _measuredWidth(_trailingStripKey) ?? _trailingRevealWidth;
      _trailingPrimaryWidth = _measuredWidth(_trailingPrimaryKey) ?? _trailingPrimaryWidth;
    }
    if (_hasLeading && _leadingSurplus <= 0) {
      _leadingRevealWidth = _measuredWidth(_leadingStripKey) ?? _leadingRevealWidth;
      _leadingPrimaryWidth = _measuredWidth(_leadingPrimaryKey) ?? _leadingPrimaryWidth;
    }
  }

  double? _measuredWidth(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size.width : null;
  }

  // ── Settling ───────────────────────────────────────────────────────────────

  void _close() => _settleTo(0);

  void _settleToNearest() {
    final side = _extent.sign;
    final reveal = _revealOf(side);
    _settleTo(_extent.abs() > reveal / 2 ? side * reveal : 0);
  }

  void _settleTo(double target) {
    // The close callback escapes to host action handlers, which may hold it
    // across an await that outlives the row.
    if (!mounted || _rowWidth <= 0) return;
    final value = (target / _rowWidth).clamp(-1.0, 1.0);
    if (prefersReducedMotion(context)) {
      _controller.value = value;
      return;
    }
    unawaited(_controller.animateTo(value, duration: _settleDuration, curve: Curves.easeOutCubic));
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
