import "dart:math";

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
///
/// The newest end is padded clear of the nearest [TranscriptBottomInset] too.
/// Scrolled away from that end, a change in the inset leaves the rows where
/// they are.
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
  Widget buildChildLayout(BuildContext context) =>
      _BottomInsetPadding(sliver: _RowsHeldInPlace(delegate: childrenDelegate));

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

/// The height of the controls floating over the transcript's bottom edge.
///
/// It changes on every frame those controls grow or fold, so only the widgets
/// that place something by it read it: the rows themselves do not rebuild.
class const TranscriptBottomInset({
  super.key,
  required final double inset,
  required super.child,
}) extends InheritedWidget {
  /// Rebuilds the caller whenever the inset changes.
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TranscriptBottomInset>()?.inset ?? 0;

  /// The inset now, for a read during layout that must not rebuild the caller.
  static double peek(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TranscriptBottomInset>()?.inset ?? 0;

  @override
  bool updateShouldNotify(TranscriptBottomInset oldWidget) => inset != oldWidget.inset;
}

/// Pads the newest end, which a reversed list lays out first, by the
/// [TranscriptBottomInset]. The same [sliver] instance comes back on an inset
/// change, so the rows are not rebuilt.
class const _BottomInsetPadding({required final Widget sliver}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _RowsStillPadding(
    padding: EdgeInsets.only(bottom: TranscriptBottomInset.of(context)),
    sliver: sliver,
  );
}

class const _RowsStillPadding({required super.padding, required super.sliver}) extends SliverPadding {
  @override
  RenderSliverPadding createRenderObject(BuildContext context) =>
      _RenderRowsStillPadding(padding: padding, textDirection: Directionality.of(context));
}

/// At the newest end the rows rise and fall with the inset, staying clear of
/// the controls. Scrolled away from it, the reader's rows stay where they are
/// on screen: the scroll offset moves by the inset's change in the same
/// layout, so the padding grows or shrinks out of sight below them.
class _RenderRowsStillPadding({required super.padding, required super.textDirection}) extends RenderSliverPadding {
  double? _laidOutInset;

  @override
  void performLayout() {
    final inset = padding.resolve(textDirection).bottom;
    final change = inset - (_laidOutInset ?? inset);
    _laidOutInset = inset;
    final scrolled = switch (RenderAbstractViewport.maybeOf(this)) {
      final RenderViewportBase viewport => viewport.offset.pixels,
      _ => 0.0,
    };
    // A shrink can take the offset back to the newest end, not past it.
    final correction = scrolled > 0 ? max(change, -scrolled) : 0.0;
    if (correction != 0) {
      geometry = SliverGeometry(scrollOffsetCorrection: correction);
      return;
    }
    super.performLayout();
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
