import "dart:math";

import "package:flutter/rendering.dart";
import "package:flutter/scheduler.dart";
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
/// While [detached] says the reader has scrolled away from that end, a change
/// in the inset or in the viewport's height, as when the keyboard opens, leaves
/// the rows where they are. When such a shrink carries the list all the way
/// back to that end, [onCarriedToNewestEnd] runs after the frame. While
/// [rowsLeaving] says rows are folding away, the topmost row in view stays
/// where it is on screen too, unless the fold carries the list back to that end.
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
  required final ValueGetter<bool> detached,
  required final ValueGetter<bool> rowsLeaving,
  required final VoidCallback onCarriedToNewestEnd,
}) extends ListView {
  this : super.builder();

  @override
  Widget buildChildLayout(BuildContext context) => _BottomInsetPadding(
    detached: detached,
    onCarriedToNewestEnd: onCarriedToNewestEnd,
    sliver: _RowsHeldInPlace(
      delegate: childrenDelegate,
      detached: detached,
      rowsLeaving: rowsLeaving,
      onCarriedToNewestEnd: onCarriedToNewestEnd,
    ),
  );

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
class const _BottomInsetPadding({
  required final ValueGetter<bool> detached,
  required final VoidCallback onCarriedToNewestEnd,
  required final Widget sliver,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _RowsStillPadding(
    detached: detached,
    onCarriedToNewestEnd: onCarriedToNewestEnd,
    padding: EdgeInsets.only(bottom: TranscriptBottomInset.of(context)),
    sliver: sliver,
  );
}

class const _RowsStillPadding({
  required final ValueGetter<bool> detached,
  required final VoidCallback onCarriedToNewestEnd,
  required super.padding,
  required super.sliver,
}) extends SliverPadding {
  @override
  RenderSliverPadding createRenderObject(BuildContext context) => _RenderRowsStillPadding(
    detached: detached,
    onCarriedToNewestEnd: onCarriedToNewestEnd,
    padding: padding,
    textDirection: Directionality.of(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderSliverPadding renderObject) {
    super.updateRenderObject(context, renderObject);
    if (renderObject is _RenderRowsStillPadding) {
      renderObject
        ..detached = detached
        ..onCarriedToNewestEnd = onCarriedToNewestEnd;
    }
  }
}

/// Following the newest end, the rows rise and fall with the inset and the
/// viewport's bottom edge, staying clear of the controls. Detached, the
/// reader's rows stay where they are on screen: the scroll offset moves by the
/// change in the same layout, so it happens out of sight below them. A glide
/// back to the newest end follows again, so it is left to drive the offset.
class _RenderRowsStillPadding({
  required var ValueGetter<bool> detached,
  required var VoidCallback onCarriedToNewestEnd,
  required super.padding,
  required super.textDirection,
}) extends RenderSliverPadding {
  double? _laidOutInset;
  double? _laidOutExtent;

  @override
  void performLayout() {
    final inset = padding.resolve(textDirection).bottom;
    final extent = constraints.viewportMainAxisExtent;
    // The viewport's top stays put on screen, so its bottom edge, which the
    // rows are placed from, moves by its change in height.
    final change = inset - (_laidOutInset ?? inset) + (_laidOutExtent ?? extent) - extent;
    _laidOutInset = inset;
    _laidOutExtent = extent;
    final scrolled = switch (RenderAbstractViewport.maybeOf(this)) {
      final RenderViewportBase viewport => viewport.offset.pixels,
      _ => 0.0,
    };
    if (change == 0 || !detached()) return super.performLayout();
    // A shrink can take the offset back to the newest end, not past it. There
    // the reader sees the latest rows, so the list may follow them again.
    if (scrolled > 0 && change <= -scrolled) {
      SchedulerBinding.instance.addPostFrameCallback((_) => onCarriedToNewestEnd());
    }
    final correction = max(change, -scrolled);
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

class const _RowsHeldInPlace({
  required super.delegate,
  required final ValueGetter<bool> detached,
  required final ValueGetter<bool> rowsLeaving,
  required final VoidCallback onCarriedToNewestEnd,
}) extends SliverList {
  @override
  RenderSliverList createRenderObject(BuildContext context) => switch (context) {
    final SliverMultiBoxAdaptorElement element => _RenderRowsHeldInPlace(
      childManager: element,
      detached: detached,
      rowsLeaving: rowsLeaving,
      onCarriedToNewestEnd: onCarriedToNewestEnd,
    ),
    _ => throw StateError("A sliver list builds under its own element."),
  };

  @override
  void updateRenderObject(BuildContext context, RenderSliverList renderObject) {
    if (renderObject is _RenderRowsHeldInPlace) {
      renderObject
        ..detached = detached
        ..rowsLeaving = rowsLeaving
        ..onCarriedToNewestEnd = onCarriedToNewestEnd;
    }
  }
}

/// A row joining or leaving the newest end moves every built row along one
/// index, and the framework then places each where the row that held that index
/// was, or nowhere when no built row held it. Scrolled away from that end, the
/// list would step by a row's height for a row nobody sees, and step back on
/// reaching it. This lays out from where the first row was, and layout builds
/// the rows before that one again from there.
///
/// While [rowsLeaving] fold away below a [detached] reader, they would carry
/// the topmost row in view down; the scroll offset moves by as much in the same
/// layout, so it stays where it is, up to the layout that drops the last of them.
class _RenderRowsHeldInPlace({
  required super.childManager,
  required var ValueGetter<bool> detached,
  required var ValueGetter<bool> rowsLeaving,
  required var VoidCallback onCarriedToNewestEnd,
}) extends RenderSliverList {
  RenderBox? _heldRow;
  double? _heldOffset;

  /// The topmost row in view, and how far into the scrolled content it was
  /// laid out.
  ({RenderBox row, double offset})? _readerRow;

  @override
  void performLayout() {
    // Moved to an index no built row held, the first row has lost its place,
    // and layout would drop it and start from the next row instead.
    if (_heldRow case final held? when identical(held, firstChild) && childScrollOffset(held) == null) {
      _place(row: held, offset: _heldOffset);
    }
    super.performLayout();
    if (geometry?.scrollOffsetCorrection == null && _putHeldRowBack()) super.performLayout();
    final listCorrection = geometry?.scrollOffsetCorrection;
    if (listCorrection == null) {
      final correction = _keepReaderRowStill();
      if (correction != 0) {
        geometry = SliverGeometry(scrollOffsetCorrection: correction);
        return;
      }
    }
    final first = firstChild;
    _heldRow = first;
    _heldOffset = first == null ? null : childScrollOffset(first);
    _readerRow = switch ((listCorrection, _readerRow)) {
      (null, _) => detached() && rowsLeaving() ? _topmostRowInView() : null,
      // The list moves every row and the scroll offset by as much, which leaves
      // the reader's row where it is on screen.
      (final correction?, final reader?) => (row: reader.row, offset: reader.offset + correction),
      (_, null) => null,
    };
  }

  /// How far the scroll offset must move for the reader's row to stay where it
  /// was: no further than the newest end, where the list may follow again. Only
  /// layout moves a row within the content, so the reader's own scrolling
  /// stands.
  double _keepReaderRowStill() {
    final reader = _readerRow;
    if (reader == null || !detached()) return 0;
    final offset = _contentOffsetOf(row: reader.row);
    if (offset == null) return 0;
    final change = offset - reader.offset;
    if (change == 0) return 0;
    _readerRow = (row: reader.row, offset: offset);
    final scrolled = _scrolled();
    if (scrolled > 0 && change <= -scrolled) {
      SchedulerBinding.instance.addPostFrameCallback((_) => onCarriedToNewestEnd());
    }
    return max(change, -scrolled);
  }

  ({RenderBox row, double offset})? _topmostRowInView() {
    ({RenderBox row, double offset})? topmost;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final offset = _contentOffsetOf(row: child);
      if (offset == null) continue;
      final position = offset - _scrolled();
      if (position < constraints.viewportMainAxisExtent && position + paintExtentOf(child) > 0) {
        topmost = (row: child, offset: offset);
      }
    }
    return topmost;
  }

  /// How far into the scrolled content [row] is laid out, or null once it is
  /// not one of the rows.
  double? _contentOffsetOf({required RenderBox row}) {
    if (row.parent != this) return null;
    final offset = childScrollOffset(row);
    if (offset == null) return null;
    return constraints.precedingScrollExtent + offset;
  }

  double _scrolled() => switch (RenderAbstractViewport.maybeOf(this)) {
    final RenderViewportBase viewport => viewport.offset.pixels,
    _ => 0.0,
  };

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
