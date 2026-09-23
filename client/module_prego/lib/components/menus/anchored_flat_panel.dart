import "dart:math" as math;

import "package:cue/cue.dart";
import "package:flutter/rendering.dart" show RenderFollowerLayer;
import "package:material_ui/material_ui.dart";

import "../../theme/prego_theme.dart";

/// Where an [AnchoredFlatPanel] sits against the rect it anchors to.
enum AnchoredPanelPlacement() {
  /// Centred on the trigger and a gap away from it, toward whichever side has
  /// more room: a popup hung off a button or a long-pressed row.
  besideTrigger,

  /// Its top-left corner on the rect's own, dropping below and flipping above
  /// only when it does not fit: a context menu at the pointer.
  atCorner,
}

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
class const AnchoredFlatPanel({
  super.key,

  /// Screen-space rectangle of the trigger the bubble anchors to.
  required final Rect triggerRect,

  /// How the bubble sits against [triggerRect].
  required final AnchoredPanelPlacement placement,

  /// Fixed width of the bubble (clamped down to fit a narrow viewport).
  required final double width,

  /// Caps how tall the bubble may grow; past it the content scrolls. Null lets
  /// it grow with its content. Either way it is bounded by the room beside the
  /// trigger — a cap only ever tightens that bound.
  required final double? maxHeight,

  /// Corner radius of the bubble.
  required final double borderRadius,

  /// Minimum gap kept between the bubble and the screen edges.
  required final EdgeInsets screenPadding,

  /// Starts overflow at the bottom without changing the body's visual order.
  final bool reverseScroll = false,

  /// Whether the body brings its own scroll view, such as a search field
  /// pinned above a list. It then lays itself out within the capped height
  /// instead of the panel scrolling it.
  required final bool contentScrolls,

  /// Builds the bubble body. The `close` callback dismisses the popup. Unless
  /// [contentScrolls], the panel scrolls this content when it exceeds the
  /// available height, so it need not provide its own scroll view.
  required final Widget Function(BuildContext context, VoidCallback close) childBuilder,
}) extends StatefulWidget {
  /// Gap between the trigger and the bubble it spawns.
  static const double _gap = 8;

  @override
  State<AnchoredFlatPanel> createState() => _AnchoredFlatPanelState();
}

class _AnchoredFlatPanelState() extends State<AnchoredFlatPanel> {
  /// How far the trigger has moved since the popup opened, such as a composer
  /// riding up on the keyboard. The enclosing `CompositedTransformFollower`
  /// already carries the bubble along by this much, so the room and the
  /// screen clamps are measured from the moved trigger, and the position hands
  /// the shift back to the follower.
  Offset _triggerShift = Offset.zero;

  /// Reads the shift the follower painted with, after each frame. The bubble
  /// therefore trails a moving trigger by one frame and settles one frame
  /// after it stops.
  void _readTriggerShift(Duration _) {
    if (!mounted) return;
    final follower = context.findAncestorRenderObjectOfType<RenderFollowerLayer>();
    if (follower == null) return;
    final shift = MatrixUtils.transformPoint(follower.getCurrentTransform(), Offset.zero);
    if (shift != _triggerShift) setState(() => _triggerShift = shift);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_readTriggerShift);
    final prego = context.prego;
    final AnchoredFlatPanel(:placement, :width, :maxHeight, :borderRadius, :screenPadding) = widget;
    final triggerRect = widget.triggerRect.shift(_triggerShift);
    // Granular getters so re-layout is driven only by the metrics this bubble
    // actually uses, not by any unrelated MediaQueryData change.
    final screen = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    final atCorner = placement == AnchoredPanelPlacement.atCorner;
    final gap = atCorner ? 0.0 : AnchoredFlatPanel._gap;

    // Expand toward whichever side of the trigger has more room. For a trigger
    // near the bottom (e.g. the session composer) this resolves to "expand up".
    final spaceAbove = triggerRect.top - safe.top - screenPadding.top - gap;
    final spaceBelow = screen.height - keyboard - safe.bottom - screenPadding.bottom - triggerRect.bottom - gap;
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
        // Unless the content scrolls itself, the panel owns overflow: content
        // taller than the available height (the delegate's maxHeight cap)
        // scrolls instead of overflowing, so callers can hand in arbitrary
        // content without each wrapping its own scroll view. Shorter content
        // shrink-wraps as before.
        child: widget.contentScrolls
            ? widget.childBuilder(context, close)
            : SingleChildScrollView(reverse: widget.reverseScroll, child: widget.childBuilder(context, close)),
      ),
    );

    return CustomSingleChildLayout(
      delegate: _AnchoredPopupLayoutDelegate(
        triggerRect: triggerRect,
        triggerShift: _triggerShift,
        width: width,
        maxHeight: effectiveMaxHeight,
        expandUp: expandUp,
        // A context menu drops from its corner whenever it fits there.
        spaceBelowToPrefer: atCorner ? spaceBelow : null,
        screenPadding: screenPadding,
        safe: safe,
        keyboard: keyboard,
        gap: gap,
      ),
      child: Actor(
        acts: [
          const Act.fadeIn(),
          // A context menu simply appears; it does not spring out of a trigger.
          if (!atCorner) ...[
            Act.scale(from: 0.96, alignment: expandUp ? Alignment.bottomCenter : Alignment.topCenter),
            Act.slideY(from: expandUp ? 0.06 : -0.06),
          ],
        ],
        child: panel,
      ),
    );
  }
}

/// Positions the flat bubble within the screen: fixed [width], capped to
/// [maxHeight], anchored above or below [triggerRect] per [expandUp], and
/// clamped so it never crosses the screen-edge padding (incl. notches and the
/// keyboard). The follower moves the result by [triggerShift], so that is
/// taken back off.
class _AnchoredPopupLayoutDelegate({
  required final Rect triggerRect,
  required final Offset triggerShift,
  required final double width,
  required final double maxHeight,
  required final bool expandUp,

  /// Set for a corner placement: the room below the anchor, which wins over
  /// [expandUp] whenever the child fits in it.
  required final double? spaceBelowToPrefer,
  required final EdgeInsets screenPadding,
  required final EdgeInsets safe,
  required final double keyboard,
  required final double gap,
}) extends SingleChildLayoutDelegate {
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    // Cap to the padded safe area, not the full route width: getPositionForChild
    // can only reposition the child, not shrink it, so a width wider than the
    // viewport (e.g. a 320px bubble on a 320dp screen) would otherwise overflow
    // the edge/safe-area despite the dx clamp.
    final availableWidth = constraints.maxWidth - screenPadding.left - screenPadding.right - safe.left - safe.right;
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
    final spaceBelowToPrefer = this.spaceBelowToPrefer;
    final preferredDx = spaceBelowToPrefer == null ? triggerRect.center.dx - childSize.width / 2 : triggerRect.left;
    final dx = preferredDx.clamp(leftBound, math.max(leftBound, rightBound)).toDouble();

    final topBound = screenPadding.top + safe.top;
    final bottomBound = size.height - keyboard - screenPadding.bottom - safe.bottom - childSize.height;
    final up = spaceBelowToPrefer == null ? expandUp : childSize.height > spaceBelowToPrefer;
    final preferredDy = up ? triggerRect.top - gap - childSize.height : triggerRect.bottom + gap;
    final dy = preferredDy.clamp(topBound, math.max(topBound, bottomBound)).toDouble();

    return Offset(dx, dy) - triggerShift;
  }

  @override
  bool shouldRelayout(_AnchoredPopupLayoutDelegate oldDelegate) {
    return triggerRect != oldDelegate.triggerRect ||
        triggerShift != oldDelegate.triggerShift ||
        width != oldDelegate.width ||
        maxHeight != oldDelegate.maxHeight ||
        expandUp != oldDelegate.expandUp ||
        spaceBelowToPrefer != oldDelegate.spaceBelowToPrefer ||
        keyboard != oldDelegate.keyboard ||
        screenPadding != oldDelegate.screenPadding ||
        safe != oldDelegate.safe;
  }
}
