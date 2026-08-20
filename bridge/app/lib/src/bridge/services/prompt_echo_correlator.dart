import "package:sesori_shared/sesori_shared.dart";

/// Attaches prompt ids to harness echoes that publish none.
///
/// A client retires its own copy of a submitted prompt when the delivered user
/// message carries that prompt's id. Harnesses differ in whether they can
/// supply it: Claude replays its own stdin frame and ACP builds the message
/// itself, so both stamp it, while Codex and OpenCode surface a message their
/// backend authored with no notion of the id. Without one, a client cannot
/// tell its own submission from another surface's and is left rendering a
/// stranded copy beside the delivered message.
///
/// The bridge is the one place that knows: it dispatched the prompt itself,
/// moments earlier, on the same session. This records that dispatch and stamps
/// the session's next unattributed user message with it, so the id-carrying
/// contract holds for every harness rather than only the ones that implement
/// it natively.
class PromptEchoCorrelator() {
  /// Prompt ids dispatched per session and not yet claimed by an echo, oldest
  /// first. Sends are serialized per session, so their echoes arrive in the
  /// same order.
  final Map<String, List<String>> _pending = {};

  /// At most one turn's worth of unclaimed ids per session. A harness that
  /// never echoes (or echoes something invisible) must not accumulate ids that
  /// would later be stamped onto an unrelated message.
  static const int _maxPendingPerSession = 8;

  /// Records a prompt the bridge accepted for [sessionId].
  void recordDispatched({required String sessionId, required String promptId}) {
    final pending = _pending.putIfAbsent(sessionId, () => <String>[]);
    if (pending.contains(promptId)) return;
    pending.add(promptId);
    if (pending.length > _maxPendingPerSession) pending.removeAt(0);
  }

  /// Returns [message] with a prompt id when it is an unattributed user
  /// message and this session has a dispatch awaiting its echo.
  ///
  /// Messages that already carry an id keep it: a harness that knows its own
  /// correlation is always more authoritative than this ordering.
  Message stamp({required String sessionId, required Message message}) {
    if (message is! MessageUser || message.promptId != null) return message;
    final pending = _pending[sessionId];
    if (pending == null || pending.isEmpty) return message;
    final promptId = pending.removeAt(0);
    if (pending.isEmpty) _pending.remove(sessionId);
    return message.copyWith(promptId: promptId);
  }

  /// Drops a session's unclaimed ids — its turn was abandoned (abort) or the
  /// session is gone, so no echo will claim them.
  void forgetSession({required String sessionId}) => _pending.remove(sessionId);
}
