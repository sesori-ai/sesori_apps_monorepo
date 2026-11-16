import "dart:math";

/// A pinned session and its [pinOrder], as the pinned group lists it.
typedef PinnedSessionOrder = ({String sessionId, int pinOrder});

/// How a move reorders the pinned group. The bridge stores what it answers,
/// and an app shows the same answer while the bridge's is on its way, so the
/// two agree on where every row lands.
class const SessionPinOrderCalculator() {
  /// The new pin orders that place [sessionId] directly below [afterSessionId]
  /// in [pinned], or at its top when [afterSessionId] is null. [pinned] is the
  /// whole group in list order, highest [PinnedSessionOrder.pinOrder] first.
  ///
  /// Only the new order's rows from the top down to the moved one are
  /// rewritten, top first and each above every current value, so the rows
  /// below keep theirs. Empty when [sessionId]
  /// already stands there; null when either session is not in [pinned] or
  /// they are the same session.
  List<PinnedSessionOrder>? move({
    required List<PinnedSessionOrder> pinned,
    required String sessionId,
    required String? afterSessionId,
  }) {
    final ids = [for (final row in pinned) row.sessionId];
    if (!ids.contains(sessionId) || afterSessionId == sessionId) return null;
    if (afterSessionId != null && !ids.contains(afterSessionId)) return null;
    final reordered = [...ids]..remove(sessionId);
    final at = afterSessionId == null ? 0 : reordered.indexOf(afterSessionId) + 1;
    reordered.insert(at, sessionId);
    if (ids.indexOf(sessionId) == at) return const [];
    final top = pinned.map((row) => row.pinOrder).reduce(max);
    return [
      for (final (index, id) in reordered.take(at + 1).indexed) (sessionId: id, pinOrder: top + at + 1 - index),
    ];
  }
}
