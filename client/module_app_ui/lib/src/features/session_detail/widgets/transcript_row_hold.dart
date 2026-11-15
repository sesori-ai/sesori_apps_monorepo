import "dart:math";

import "package:flutter/rendering.dart" show RenderSliver, RenderSliverPadding, RenderViewportBase, ScrollDirection;
import "package:material_ui/material_ui.dart";

/// Keeps the top of the transcript row at [context] still while the row
/// changes height by [growth], negative as it shrinks.
///
/// Call it on every tick of the change, before layout. A reversed transcript
/// grows a row upward, which would push its top and every row above it away;
/// scrolling by the same amount in the same frame grows the row downward
/// instead.
///
/// With [roomBelowOnly], a row only grows downward into the room left below it
/// on screen, and past that grows upward like new content, so what it reveals
/// stays in view. Otherwise it always grows downward, and the rows below it
/// move on past the bottom edge.
///
/// A transcript shorter than its viewport cannot scroll, so there a row with
/// [roomBelowOnly] grows into the empty space above it; one without holds its
/// top once [reserveTranscriptSpaceAbove] has kept that space. A drag or fling
/// already moves the content, where a jump would stop it under the reader's
/// finger.
void holdTranscriptRowTop({required BuildContext context, required double growth, required bool roomBelowOnly}) {
  final scrollable = Scrollable.maybeOf(context);
  final row = context.findRenderObject();
  final viewport = scrollable?.context.findRenderObject();
  if (scrollable == null ||
      scrollable.axisDirection != AxisDirection.up ||
      row is! RenderBox ||
      viewport is! RenderBox ||
      growth == 0) {
    return;
  }
  final position = scrollable.position;
  final canScroll = position.maxScrollExtent > position.minScrollExtent;
  if ((roomBelowOnly && !canScroll) || position.userScrollDirection != ScrollDirection.idle) return;
  final double shift;
  if (growth < 0) {
    shift = max(growth, position.minScrollExtent - position.pixels);
  } else if (roomBelowOnly) {
    final rowBottom = row.localToGlobal(Offset(0, row.size.height)).dy;
    // The list's bottom paddings (its own gap and the floating controls'
    // height) keep the newest row clear of the composer, so that strip is
    // no room.
    var covered = 0.0;
    for (var node = row.parent; node != null && node != viewport; node = node.parent) {
      if (node is RenderSliverPadding) covered += node.resolvedPadding?.bottom ?? 0;
    }
    final viewportBottom = viewport.localToGlobal(Offset(0, viewport.size.height)).dy - covered;
    shift = min(growth, max(0, viewportBottom - rowBottom));
  } else {
    shift = growth;
  }
  if (shift != 0) position.jumpTo(position.pixels + shift);
}

/// The room a transcript adds above its oldest row, which [TranscriptTopReserve]
/// shares with the rows.
class const TranscriptTopReserve({super.key, required final ValueNotifier<double> extent, required super.child})
    extends InheritedWidget {
  static ValueNotifier<double>? _of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TranscriptTopReserve>()?.extent;

  @override
  bool updateShouldNotify(TranscriptTopReserve oldWidget) => extent != oldWidget.extent;
}

/// Keeps the empty space above a transcript shorter than its viewport as room
/// to scroll into, before the row at [context] grows with its top held.
///
/// A reversed transcript sits on its newest edge, so the space is already
/// empty and reserving it moves nothing; it lets the transcript scroll by the
/// row's growth, carrying the rows below it down, where it could not before.
void reserveTranscriptSpaceAbove({required BuildContext context}) {
  final reserve = TranscriptTopReserve._of(context);
  final scrollable = Scrollable.maybeOf(context);
  var node = context.findRenderObject();
  while (node != null && node is! RenderViewportBase) {
    node = node.parent;
  }
  if (reserve == null || scrollable == null || node is! RenderViewportBase) return;
  var content = 0.0;
  node.visitChildren((child) {
    if (child is RenderSliver) content += child.geometry?.scrollExtent ?? 0;
  });
  final empty = scrollable.position.viewportDimension - content;
  if (empty > 0) reserve.value += empty;
}

/// Gives back the space [reserveTranscriptSpaceAbove] kept, once the row that
/// needed it is back to its height; on a short transcript nothing moves.
void releaseTranscriptSpaceAbove({required BuildContext context}) {
  TranscriptTopReserve._of(context)?.value = 0;
}
