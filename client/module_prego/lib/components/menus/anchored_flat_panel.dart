import "dart:math" as math;

import "package:cue/cue.dart";
import "package:flutter/material.dart";

import "../../theme/prego_theme.dart";

/// A flat Material bubble anchored to a trigger rect, kept on screen and sprung
/// in with `cue`. It caps its height to the room beside the trigger and scrolls
/// its content past that cap, so callers can supply arbitrary content without
/// each managing overflow.
///
/// It is the shared flat rendering for the design system's anchored popups:
/// `PregoAnchorMenu`'s flat menu panel and `PregoPopover`'s content bubble both
/// build from it, so the two stay visually identical (same chrome, spring, and
/// screen-edge clamping) while each supplies its own body via [childBuilder]. It
/// is the flat counterpart of `GlassMenu`'s `autoAdjustToScreen`.
///
/// [childBuilder] receives a `close` callback that pops the modal route the
/// enclosing `CueModalTransition` pushed — wire it to any dismiss affordance
/// inside the bubble (a tapped menu row, a "Done" button). The transparent
/// tap-outside barrier belongs to that `CueModalTransition`, not to this panel.
class AnchoredFlatPanel extends StatelessWidget {
  const AnchoredFlatPanel({
    super.key,
    required this.triggerRect,
    required this.width,
    required this.maxHeight,
    required this.borderRadius,
    required this.screenPadding,
    required this.childBuilder,
  });

  /// Screen-space rectangle of the trigger the bubble anchors to.
  final Rect triggerRect;

  /// Fixed width of the bubble (clamped down to fit a narrow viewport).
  final double width;

  /// Caps how tall the bubble may grow; past it the content scrolls. Null lets
  /// it grow with its content. Either way it is bounded by the room beside the
  /// trigger — a cap only ever tightens that bound.
  final double? maxHeight;

  /// Corner radius of the bubble.
  final double borderRadius;

  /// Minimum gap kept between the bubble and the screen edges.
  final EdgeInsets screenPadding;

  /// Builds the bubble body. The `close` callback dismisses the popup. The panel
  /// scrolls this content when it exceeds the available height, so it need not
  /// provide its own scroll view.
  final Widget Function(BuildContext context, VoidCallback close) childBuilder;

  /// Gap between the trigger and the bubble it spawns.
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    // Granular getters so re-layout is driven only by the metrics this bubble
    // actually uses, not by any unrelated MediaQueryData change.
    final screen = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    // Expand toward whichever side of the trigger has more room. For a trigger
    // near the bottom (e.g. the session composer) this resolves to "expand up".
    final spaceAbove = triggerRect.top - safe.top - screenPadding.top - _gap;
    final spaceBelow =
        screen.height - keyboard - safe.bottom - screenPadding.bottom - triggerRect.bottom - _gap;
    final expandUp = spaceAbove >= spaceBelow;
    final cap = maxHeight;
    final available = math.max(0.0, expandUp ? spaceAbove : spaceBelow);
    final effectiveMaxHeight = cap != null ? math.min(cap, available) : available;

    // module_prego is a GoRouter-agnostic design module (no go_router dep);
    // this pops the modal route CueModalTransition pushed for the popup.
    // ignore: no_slop_linter/avoid_navigator_of, design module has no go_router dep; pops the modal route CueModalTransition pushed
    void close() => Navigator.of(context).pop();

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: prego.shadows.xl,
      ),
      child: Material(
        color: prego.colors.bgSecondary,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(color: prego.colors.borderSecondary, width: 0.5),
        ),
        // The panel owns overflow: content taller than the available height
        // (the delegate's maxHeight cap) scrolls instead of overflowing, so
        // callers can hand in arbitrary content without each wrapping its own
        // scroll view. Shorter content shrink-wraps as before.
        child: SingleChildScrollView(child: childBuilder(context, close)),
      ),
    );

    return CustomSingleChildLayout(
      delegate: _AnchoredPopupLayoutDelegate(
        triggerRect: triggerRect,
        width: width,
        maxHeight: effectiveMaxHeight,
        expandUp: expandUp,
        screenPadding: screenPadding,
        safe: safe,
        keyboard: keyboard,
        gap: _gap,
      ),
      child: Actor(
        acts: [
          const Act.fadeIn(),
          Act.scale(from: 0.96, alignment: expandUp ? Alignment.bottomCenter : Alignment.topCenter),
          Act.slideY(from: expandUp ? 0.06 : -0.06),
        ],
        child: panel,
      ),
    );
  }
}

/// Positions the flat bubble within the screen: fixed [width], capped to
/// [maxHeight], anchored above or below [triggerRect] per [expandUp], and
/// clamped so it never crosses the screen-edge padding (incl. notches and the
/// keyboard).
class _AnchoredPopupLayoutDelegate extends SingleChildLayoutDelegate {
  _AnchoredPopupLayoutDelegate({
    required this.triggerRect,
    required this.width,
    required this.maxHeight,
    required this.expandUp,
    required this.screenPadding,
    required this.safe,
    required this.keyboard,
    required this.gap,
  });

  final Rect triggerRect;
  final double width;
  final double maxHeight;
  final bool expandUp;
  final EdgeInsets screenPadding;
  final EdgeInsets safe;
  final double keyboard;
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    // Cap to the padded safe area, not the full route width: getPositionForChild
    // can only reposition the child, not shrink it, so a width wider than the
    // viewport (e.g. a 320px bubble on a 320dp screen) would otherwise overflow
    // the edge/safe-area despite the dx clamp.
    final availableWidth =
        constraints.maxWidth - screenPadding.left - screenPadding.right - safe.left - safe.right;
    final width = math.min(this.width, math.max(0.0, availableWidth));
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max(0.0, math.min(maxHeight, constraints.maxHeight)),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final leftBound = screenPadding.left + safe.left;
    final rightBound = size.width - screenPadding.right - safe.right - childSize.width;
    final dx = (triggerRect.center.dx - childSize.width / 2)
        .clamp(leftBound, math.max(leftBound, rightBound))
        .toDouble();

    final topBound = screenPadding.top + safe.top;
    final bottomBound =
        size.height - keyboard - screenPadding.bottom - safe.bottom - childSize.height;
    final preferredDy =
        expandUp ? triggerRect.top - gap - childSize.height : triggerRect.bottom + gap;
    final dy = preferredDy.clamp(topBound, math.max(topBound, bottomBound)).toDouble();

    return Offset(dx, dy);
  }

  @override
  bool shouldRelayout(_AnchoredPopupLayoutDelegate oldDelegate) {
    return triggerRect != oldDelegate.triggerRect ||
        width != oldDelegate.width ||
        maxHeight != oldDelegate.maxHeight ||
        expandUp != oldDelegate.expandUp ||
        keyboard != oldDelegate.keyboard ||
        screenPadding != oldDelegate.screenPadding ||
        safe != oldDelegate.safe;
  }
}
