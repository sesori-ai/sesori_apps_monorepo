import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";

/// A [ListView.builder] that calls [onLaidOut] each time its viewport has laid
/// out its rows, including every frame that scrolls it, while layout still
/// runs. What it positions from the rows therefore moves in the frame the rows
/// do, where a post-frame measurement would trail them by one.
///
/// [onLaidOut] runs inside a layout callback, so it may read any laid-out
/// box's size and position and mark render objects for paint.
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
