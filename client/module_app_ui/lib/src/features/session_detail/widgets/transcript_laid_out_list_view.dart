import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";

/// A [ListView.builder] that calls [onLaidOut] each time its viewport has laid
/// out its rows, including every frame that scrolls it, while layout still
/// runs. What it positions from the rows therefore moves in the frame the rows
/// do, where a post-frame measurement would trail them by one.
///
/// [onLaidOut] runs inside a layout callback, so it may read any laid-out
/// box's size and position and mark render objects for paint.
///
/// A row joining below the built rows also leaves them where they were.
class TranscriptLaidOutListView({
  super.key,
  super.reverse,
  super.controller,
  super.padding,
  super.keyboardDismissBehavior,
  super.physics,
  required super.itemCount,
  super.findChildIndexCallback,
  required super.itemBuilder,
  required final VoidCallback onLaidOut,
}) extends ListView {
  this : super.builder();

  @override
  Widget buildChildLayout(BuildContext context) => _RowsHeldInPlace(delegate: childrenDelegate);

  @override
  Widget buildViewport(BuildContext context, ViewportOffset offset, AxisDirection axisDirection, List<Widget> slivers) {
    return _LaidOutViewport(
      axisDirection: axisDirection,
      offset: offset,
      slivers: slivers,
      scrollCacheExtent: scrollCacheExtent,
      center: center,
      anchor: anchor,
      paintOrder: paintOrder,
      clipBehavior: clipBehavior,
      onLaidOut: onLaidOut,
    );
  }
}

class _LaidOutViewport({
  required super.axisDirection,
  required super.offset,
  required super.slivers,
  required super.scrollCacheExtent,
  required super.center,
  required super.anchor,
  required super.paintOrder,
  required super.clipBehavior,
  required final VoidCallback onLaidOut,
}) extends Viewport {
  @override
  RenderViewport createRenderObject(BuildContext context) {
    final viewport = _RenderLaidOutViewport(
      axisDirection: axisDirection,
      crossAxisDirection: Viewport.getDefaultCrossAxisDirection(context, axisDirection),
      offset: offset,
      onLaidOut: onLaidOut,
    );
    // The stock update applies every other setting, as it does on a rebuild.
    super.updateRenderObject(context, viewport);
    return viewport;
  }

  @override
  void updateRenderObject(BuildContext context, RenderViewport renderObject) {
    super.updateRenderObject(context, renderObject);
    if (renderObject is _RenderLaidOutViewport) renderObject.onLaidOut = onLaidOut;
  }
}

class _RenderLaidOutViewport({
  required super.axisDirection,
  required super.crossAxisDirection,
  required super.offset,
  required var VoidCallback onLaidOut,
}) extends RenderViewport {
  @override
  void performLayout() {
    super.performLayout();
    invokeLayoutCallback<BoxConstraints>((_) => onLaidOut());
  }
}

class const _RowsHeldInPlace({required super.delegate}) extends SliverList {
  @override
  RenderSliverList createRenderObject(BuildContext context) => switch (context) {
    final SliverMultiBoxAdaptorElement element => _RenderRowsHeldInPlace(childManager: element),
    _ => throw StateError("A sliver list builds under its own element."),
  };
}

/// A row joining the newest end moves every built row along one index, and the
/// framework then places each where the row that held that index was. Scrolled
/// away from that end, the list would step by a row's height for a row nobody
/// sees yet, and step back on reaching it. This lays out again from where the
/// first row was, and layout builds the rows before that one again from there.
class _RenderRowsHeldInPlace({required super.childManager}) extends RenderSliverList {
  RenderBox? _heldRow;
  double? _heldOffset;

  @override
  void performLayout() {
    super.performLayout();
    if (geometry?.scrollOffsetCorrection == null && _putHeldRowBack()) super.performLayout();
    final first = firstChild;
    _heldRow = first;
    _heldOffset = first == null ? null : childScrollOffset(first);
  }

  bool _putHeldRowBack() {
    final held = _heldRow;
    final first = firstChild;
    // The newest row always rests at zero, and everything is placed from it.
    if (held == null || first == null || indexOf(first) == 0) return false;
    final before = <RenderBox>[];
    var child = first;
    while (!identical(child, held)) {
      before.add(child);
      final next = childAfter(child);
      if (next == null) return false;
      child = next;
    }
    if (childScrollOffset(held) == _heldOffset) return false;
    for (final row in before) {
      _place(row: row, offset: null);
    }
    _place(row: held, offset: _heldOffset);
    return true;
  }

  void _place({required RenderBox row, required double? offset}) {
    if (row.parentData case final SliverMultiBoxAdaptorParentData data) data.layoutOffset = offset;
  }
}
