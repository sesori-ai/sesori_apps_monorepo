import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";

import "../extensions/build_context_x.dart";
import "../features/session_detail/widgets/transcript_motion.dart";

/// What stands in the composer's place: the composer, or a [notice] saying why
/// it cannot send. A change between them cross-fades in the transcript's
/// motion: the one leaving fades out as the one arriving fades in over it,
/// while the room they share eases from one's height to the other's, so the
/// page around them glides rather than jumps. A change within one, such as its
/// pills loading or its Recheck being pressed, shows in place.
/// Reduced motion keeps the cross-fade and gives the room its new height at once.
///
/// A notice hides the composer rather than replacing it, so staged images,
/// which live only in the composer, survive until the notice clears.
class const ComposerOrNotice({
  super.key,

  /// Keyed by which notice it is: one under another key cross-fades in.
  required final Widget? notice,
  required final Widget composer,

  /// Where each rests in the room while it eases. At the edge the page holds
  /// the room to, neither moves as it fades.
  required final Alignment alignment,
}) extends StatefulWidget {
  @override
  State<ComposerOrNotice> createState() => _ComposerOrNoticeState();
}

/// How present one of the things in the composer's place is, from gone (0)
/// to standing there (1), eased both ways in the transcript's motion.
class _Presence({required TickerProvider vsync, required bool shown}) {
  final AnimationController controller = AnimationController(
    vsync: vsync,
    duration: transcriptMotionDuration,
    value: shown ? 1 : 0,
  );
  late final CurvedAnimation eased = CurvedAnimation(
    parent: controller,
    curve: transcriptMotionCurve,
    reverseCurve: transcriptMotionReverseCurve,
  );

  void dispose() {
    eased.dispose();
    controller.dispose();
  }
}

/// A notice in the composer's place or fading out of it, as last built.
class _PlacedNotice({required var Widget notice, required final _Presence presence});

class _ComposerOrNoticeState() extends State<ComposerOrNotice> with TickerProviderStateMixin {
  late final _Presence _composer;

  /// The notices in the composer's place or fading out of it; the one
  /// standing there, if any, is last.
  final _notices = <_PlacedNotice>[];

  @override
  void initState() {
    super.initState();
    _composer = _Presence(vsync: this, shown: widget.notice == null);
    // Gone, the composer stays mounted offstage.
    _composer.controller.addStatusListener((_) => setState(() {}));
    if (widget.notice case final notice?) _notices.add(_placeNotice(notice: notice, shown: true));
  }

  _PlacedNotice _placeNotice({required Widget notice, required bool shown}) {
    final placed = _PlacedNotice(
      notice: notice,
      presence: _Presence(vsync: this, shown: shown),
    );
    placed.presence.controller.addStatusListener((status) {
      if (!status.isDismissed) return;
      setState(() => _notices.remove(placed));
      placed.presence.dispose();
    });
    return placed;
  }

  @override
  void didUpdateWidget(ComposerOrNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    final notice = widget.notice;
    final unchanged = switch ((oldWidget.notice, notice)) {
      (null, null) => true,
      (final before?, final after?) => Widget.canUpdate(before, after),
      _ => false,
    };
    if (!unchanged) _bringIn(notice: notice);
    if (notice != null) _notices.last.notice = notice;
  }

  /// Fades [notice] in, or the composer when it is null, as whatever else is
  /// there fades out. One still fading out turns back from where it is.
  void _bringIn({required Widget? notice}) {
    final _Presence arriving;
    if (notice == null) {
      arriving = _composer;
    } else {
      final placed =
          _notices.where((placed) => Widget.canUpdate(placed.notice, notice)).firstOrNull ??
          _placeNotice(notice: notice, shown: false);
      _notices
        ..remove(placed)
        ..add(placed);
      arriving = placed.presence;
    }
    for (final presence in [_composer, for (final placed in _notices) placed.presence]) {
      if (identical(presence, arriving)) {
        presence.controller.forward();
      } else {
        presence.controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    for (final placed in _notices) {
      placed.presence.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    final composer = _CrossFadeRoomOccupant(
      key: const ValueKey("composer_or_notice_composer"),
      presence: _composer.eased,
      shown: notice == null,
      child: widget.composer,
    );
    // Plugin-provided guidance can outgrow a short phone at large text.
    final noticeMaxHeight = MediaQuery.sizeOf(context).height / 2;
    return _CrossFadeRoom(
      alignment: widget.alignment,
      // The one arriving paints over the one leaving.
      children: [
        if (notice != null) composer,
        for (final placed in _notices)
          _CrossFadeRoomOccupant(
            key: ObjectKey(placed),
            presence: placed.presence.eased,
            shown: notice != null && identical(placed, _notices.last),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: noticeMaxHeight),
              child: SingleChildScrollView(primary: false, child: placed.notice),
            ),
          ),
        if (notice == null) composer,
      ],
    );
  }
}

/// A child of [_CrossFadeRoom] at its [presence]: it fades with it, takes no
/// taps, focus or semantics unless [shown], and once gone stays mounted
/// offstage. One leaving fades out as it was: its own animations hold still,
/// so a Recheck answered as its card leaves keeps showing that it checked.
class const _CrossFadeRoomOccupant({
  super.key,
  required final Animation<double> presence,
  required final bool shown,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final occupant = Visibility(
      visible: !presence.isDismissed,
      maintainState: true,
      child: IgnorePointer(
        ignoring: !shown,
        child: ExcludeSemantics(
          excluding: !shown,
          child: ExcludeFocus(
            excluding: !shown,
            child: FadeTransition(
              opacity: presence,
              child: TickerMode(enabled: shown, child: child),
            ),
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: presence,
      builder: (context, _) => _CrossFadeRoomPresence(
        presence: context.isReducedMotion ? (shown ? 1 : 0) : presence.value,
        child: occupant,
      ),
    );
  }
}

/// Lays its children over one another, each at [alignment], in a room as tall
/// as their heights weighted by their presence. As one fades out while another
/// fades in their presences sum to one, so the room eases from the first's
/// height to the second's; at rest it follows the one standing there as that
/// grows or shrinks. A child taller than the room paints past it.
class const _CrossFadeRoom({required final Alignment alignment, required super.children})
    extends MultiChildRenderObjectWidget {
  @override
  _RenderCrossFadeRoom createRenderObject(BuildContext context) => _RenderCrossFadeRoom(alignment: alignment);

  @override
  void updateRenderObject(BuildContext context, _RenderCrossFadeRoom renderObject) {
    renderObject.update(alignment: alignment);
  }
}

/// How present a child of [_CrossFadeRoom] is, from gone (0) to standing
/// there (1).
class const _CrossFadeRoomPresence({required final double presence, required super.child})
    extends ParentDataWidget<_CrossFadeRoomParentData> {
  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData;
    if (parentData is! _CrossFadeRoomParentData || parentData.presence == presence) return;
    parentData.presence = presence;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _CrossFadeRoom;
}

class _CrossFadeRoomParentData() extends ContainerBoxParentData<RenderBox> {
  double presence = 0;
}

class _RenderCrossFadeRoom({required Alignment alignment})
    extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CrossFadeRoomParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CrossFadeRoomParentData> {
  Alignment _alignment = alignment;

  void update({required Alignment alignment}) {
    if (alignment == _alignment) return;
    _alignment = alignment;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CrossFadeRoomParentData) child.parentData = _CrossFadeRoomParentData();
  }

  @override
  void performLayout() {
    // Each as wide as the room and as tall as it likes, as in a stretched
    // column.
    final childConstraints = BoxConstraints.tightFor(width: constraints.maxWidth);
    var height = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      child.layout(childConstraints, parentUsesSize: true);
      if (child.parentData case _CrossFadeRoomParentData(:final presence)) height += presence * child.size.height;
    }
    size = constraints.constrain(Size(constraints.maxWidth, height));
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (child.parentData case final _CrossFadeRoomParentData parentData) {
        parentData.offset = _alignment.alongOffset(
          Offset(size.width - child.size.width, size.height - child.size.height),
        );
      }
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}
