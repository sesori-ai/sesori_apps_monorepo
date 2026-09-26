import "package:flutter/foundation.dart";

/// The prompt pinned at the transcript's top edge: the opener of the turn
/// being read, while that opener sits above the edge or is not built.
@immutable
final class const TranscriptStickyPosition({
  required final String openerMessageId,

  /// How far below the top edge the next turn's opener starts, or null while
  /// that opener is not built. The pinned prompt slides up once the next
  /// opener reaches it, so the next prompt pushes it out.
  required final double? nextOpenerTop,
}) {
  @override
  bool operator ==(Object other) =>
      other is TranscriptStickyPosition &&
      other.openerMessageId == openerMessageId &&
      other.nextOpenerTop == nextOpenerTop;

  @override
  int get hashCode => Object.hash(openerMessageId, nextOpenerTop);
}
