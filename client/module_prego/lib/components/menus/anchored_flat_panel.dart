import "dart:math" as math;

import "package:cue/cue.dart";
import "package:flutter/rendering.dart" show RenderFollowerLayer;
import "package:material_ui/material_ui.dart";

import "../../interactions/prego_interaction_scope.dart";
import "../../motion/prego_pointer_motion.dart";
import "../../motion/prego_reduced_motion.dart";
import "../../theme/prego_theme.dart";

/// Where an [AnchoredFlatPanel] sits against the rect it anchors to.
enum AnchoredPanelPlacement() {
  /// Centred on the trigger and a gap away from it, toward whichever side has
  /// more room: a popup hung off a button or a long-pressed row.
  besideTrigger,

  /// Its top-left corner on the rect's own, dropping below and flipping above
  /// only when it does not fit: a context menu at the pointer.
  atCorner,

  /// Its right edge on the trigger's and a gap below it, flipping above only
  /// when it does not fit: a menu hung off a button at a row's end.
  belowRightAligned,
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

  /// Lifts the panel off page text with a halo of the page's own colour, for a
  /// panel that hangs over what is being read.
  final bool hasPageHalo = false,

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

  /// The bubble as laid out, read for its height.
  final _bubbleKey = GlobalKey();

  /// The bubble's height at the last layout, null before the first. A
  /// placement that drops below whenever it fits only learns its side from it.
  double? _bubbleHeight;

  /// Reads the bubble's height once a build has been laid out, so the next
  /// build springs it from the side that layout put it on.
  void _readBubbleHeight(Duration _) {
    if (!mounted) return;
    final height = _bubbleKey.currentContext?.size?.height;
    if (height != _bubbleHeight) setState(() => _bubbleHeight = height);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_readTriggerShift);
    final prego = context.prego;
    final AnchoredFlatPanel(:placement, :width, :maxHeight, :borderRadius, :screenPadding) = widget;
    // Under reduced motion the bubble only fades, so it needs no origin.
    final reducedMotion = prefersReducedMotion(context);
    // A bubble beside its trigger knows its side before layout.
    if (!reducedMotion && placement != AnchoredPanelPlacement.besideTrigger) {
      WidgetsBinding.instance.addPostFrameCallback(_readBubbleHeight);
    }
    final triggerRect = widget.triggerRect.shift(_triggerShift);
    // Granular getters so re-layout is driven only by the metrics this bubble
    // actually uses, not by any unrelated MediaQueryData change.
    final screen = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
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
        boxShadow: [
          // Below the panel only: its trigger sits right above and stays fully legible.
          if (widget.hasPageHalo)
            BoxShadow(
              color: Theme.of(context).scaffoldBackgroundColor,
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, 18),
            ),
          ...(!pointer
              ? prego.shadows.xl
              : prego.colors.brightness == .dark
              ? prego.shadows.xl + _pointerLift
              : _pointerLiftLight),
        ],
      ),
      child: Material(
        color: pointer ? prego.colors.bgSurface3 : prego.colors.bgSecondary,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: pointer
              ? BorderSide(color: prego.colors.borderPrimary)
              : BorderSide(color: prego.colors.borderSecondary, width: 0.5),
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

    final layout = _AnchoredPopupLayoutDelegate(
      triggerRect: triggerRect,
      triggerShift: _triggerShift,
      width: width,
      maxHeight: effectiveMaxHeight,
      expandUp: expandUp,
      spaceBelow: spaceBelow,
      placement: placement,
      screenPadding: screenPadding,
      safe: safe,
      keyboard: keyboard,
      gap: gap,
    );
    // A bubble that drops below whenever it fits settles its side only at
    // layout, so it springs from the side the last layout chose. Before the
    // first layout it assumes below, but that first frame is never painted: the
    // fade starts at zero opacity, so the bubble shows only from the next
    // frame, by when it has its side. Swapping the origin keeps the spring's
    // progress, so nothing restarts.
    final above = layout.sitsAbove(childHeight: _bubbleHeight ?? 0);
    final origin = switch (placement) {
      AnchoredPanelPlacement.besideTrigger => above ? Alignment.bottomCenter : Alignment.topCenter,
      AnchoredPanelPlacement.atCorner => above ? Alignment.bottomLeft : Alignment.topLeft,
      AnchoredPanelPlacement.belowRightAligned => above ? Alignment.bottomRight : Alignment.topRight,
    };

    return CustomSingleChildLayout(
      delegate: layout,
      child: Actor(
        key: _bubbleKey,
        acts: [
          // Solid well before the panel settles, so its text never reads over the
          // rows behind it for long.
          if (pointer && !reducedMotion)
            const Act.fadeIn(
              motion: CueMotion.curved(Duration(milliseconds: 12), curve: Curves.easeOut),
              // A click away gets a visible close; the same 12 ms would read as a cut.
              reverse: ReverseBehavior.mirror(
                motion: CueMotion.curved(Duration(milliseconds: 35), curve: Curves.easeOut),
              ),
            )
          else
            const Act.fadeIn(),
          // Grows out of the trigger, toward the side the bubble sits on.
          if (!reducedMotion) ...[
            Act.scale(from: pointer ? 0.97 : 0.96, alignment: origin),
            // A share of the panel's height, so a pointer's smaller one keeps a
            // tall menu from travelling far.
            Act.slideY(from: (above ? 1 : -1) * (pointer ? 0.02 : 0.06)),
          ],
        ],
        child: panel,
      ),
    );
  }
}

/// Lifts a pointer shell's panel off a surface of nearly its own colour.
const List<BoxShadow> _pointerLift = [BoxShadow(color: Color(0x80000000), offset: Offset(0, 12), blurRadius: 32)];

/// Light surfaces separate on a hairline and much less shadow.
const List<BoxShadow> _pointerLiftLight = [BoxShadow(color: Color(0x33000000), offset: Offset(0, 8), blurRadius: 24)];

/// Positions the flat bubble within the screen: fixed [width], capped to
/// [maxHeight], anchored above or below [triggerRect] per [placement], and
/// clamped so it never crosses the screen-edge padding (incl. notches and the
/// keyboard). The follower moves the result by [triggerShift], so that is
/// taken back off.
class _AnchoredPopupLayoutDelegate({
  required final Rect triggerRect,
  required final Offset triggerShift,
  required final double width,
  required final double maxHeight,

  /// Whether there is more room above the trigger than below it.
  required final bool expandUp,

  /// The room below the trigger, which a placement that drops below whenever
  /// the child fits there checks instead of [expandUp].
  required final double spaceBelow,
  required final AnchoredPanelPlacement placement,
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
    final preferredDx = switch (placement) {
      AnchoredPanelPlacement.besideTrigger => triggerRect.center.dx - childSize.width / 2,
      AnchoredPanelPlacement.atCorner => triggerRect.left,
      AnchoredPanelPlacement.belowRightAligned => triggerRect.right - childSize.width,
    };
    final dx = preferredDx.clamp(leftBound, math.max(leftBound, rightBound)).toDouble();

    final topBound = screenPadding.top + safe.top;
    final bottomBound = size.height - keyboard - screenPadding.bottom - safe.bottom - childSize.height;
    final up = sitsAbove(childHeight: childSize.height);
    final preferredDy = up ? triggerRect.top - gap - childSize.height : triggerRect.bottom + gap;
    final dy = preferredDy.clamp(topBound, math.max(topBound, bottomBound)).toDouble();

    return Offset(dx, dy) - triggerShift;
  }

  /// Whether a bubble [childHeight] tall sits above the trigger rather than
  /// below it.
  bool sitsAbove({required double childHeight}) => switch (placement) {
    AnchoredPanelPlacement.besideTrigger => expandUp,
    AnchoredPanelPlacement.atCorner || AnchoredPanelPlacement.belowRightAligned => childHeight > spaceBelow,
  };

  @override
  bool shouldRelayout(_AnchoredPopupLayoutDelegate oldDelegate) {
    return triggerRect != oldDelegate.triggerRect ||
        triggerShift != oldDelegate.triggerShift ||
        width != oldDelegate.width ||
        maxHeight != oldDelegate.maxHeight ||
        expandUp != oldDelegate.expandUp ||
        spaceBelow != oldDelegate.spaceBelow ||
        placement != oldDelegate.placement ||
        keyboard != oldDelegate.keyboard ||
        screenPadding != oldDelegate.screenPadding ||
        safe != oldDelegate.safe;
  }
}

/// Tells a pointer shell's menu whether a key opened it: one summoned from the
/// keyboard appears and leaves at once. [open] runs the opening after the frame
/// that passes the new motion down.
class const PregoMenuOpenMotion({
  super.key,
  required final Widget Function(BuildContext context, bool instant, void Function(VoidCallback show) open) builder,
}) extends StatefulWidget {
  @override
  State<PregoMenuOpenMotion> createState() => _PregoMenuOpenMotionState();
}

class _PregoMenuOpenMotionState() extends State<PregoMenuOpenMotion> {
  bool _instant = false;

  void _open(VoidCallback show) {
    final instant = pregoActivatedByKeyboard;
    if (instant == _instant) return show();
    setState(() => _instant = instant);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) show();
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _instant, _open);
}
