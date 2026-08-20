import "package:sesori_shared/sesori_shared.dart";

/// Attaches prompt ids to user messages that reach the bridge without one.
///
/// A client retires its own copy of a submitted prompt when the delivered user
/// message carries that prompt's id. Backends differ in whether they can
/// supply it: some replay the exact frame the bridge wrote and can echo it
/// back, while others surface a message they authored themselves, with no
/// notion of the bridge's identifier. Without one a client cannot tell its own
/// submission from another surface's, and is left rendering a stranded copy
/// beside the delivered message.
///
/// The bridge is the one component that knows: it dispatched the prompt, on
/// that session, moments earlier. This records the dispatch and stamps the
/// session's next unattributed user message with it, so the id-carrying
/// contract holds uniformly instead of only where a backend implements it.
/// Nothing here is backend-specific — a plugin that supplies its own id simply
/// never reaches the fallback.
class PromptEchoCorrelator() {
  /// Prompt ids dispatched per session and not yet claimed, oldest first.
  /// Sends are serialized per session, so echoes arrive in the same order.
  final Map<String, List<String>> _pending = {};

  /// Ids already assigned to a delivered message, per session. A backend may
  /// publish one message several times (a started/completed pair, a later
  /// revision); every such update must resolve to the same prompt rather than
  /// consuming the next one.
  final Map<String, Map<String, String>> _claimed = {};

  /// At most one turn's worth of unclaimed ids per session. A backend that
  /// never echoes must not accumulate ids that would later be stamped onto an
  /// unrelated message.
  static const int _maxPendingPerSession = 8;

  /// Bounds remembered assignments per session, keeping recent messages
  /// stable without growing with the transcript.
  static const int _maxClaimedPerSession = 32;

  /// Records a prompt dispatched for [sessionId].
  ///
  /// Called before the dispatch itself: a backend can publish its echo while
  /// the send is still awaiting its response, and that echo must already find
  /// the id here.
  void recordDispatched({required String sessionId, required String promptId}) {
    final pending = _pending.putIfAbsent(sessionId, () => <String>[]);
    if (pending.contains(promptId)) return;
    pending.add(promptId);
    if (pending.length > _maxPendingPerSession) pending.removeAt(0);
  }

  /// Drops a prompt whose dispatch was refused, so it can never be claimed by
  /// an unrelated echo.
  void forgetPrompt({required String sessionId, required String promptId}) {
    final pending = _pending[sessionId];
    if (pending == null) return;
    pending.remove(promptId);
    if (pending.isEmpty) _pending.remove(sessionId);
  }

  /// Returns [message] with a prompt id when it is an unattributed user
  /// message and this session has a dispatch awaiting its echo.
  ///
  /// A message that already carries an id keeps it: a backend that knows its
  /// own correlation is always more authoritative than this ordering.
  Message stamp({required String sessionId, required Message message}) {
    if (message is! MessageUser || message.promptId != null) return message;
    final claimed = _claimed[sessionId]?[message.id];
    if (claimed != null) return message.copyWith(promptId: claimed);
    final pending = _pending[sessionId];
    if (pending == null || pending.isEmpty) return message;
    final promptId = pending.removeAt(0);
    if (pending.isEmpty) _pending.remove(sessionId);
    final claims = _claimed.putIfAbsent(sessionId, () => <String, String>{});
    claims[message.id] = promptId;
    if (claims.length > _maxClaimedPerSession) claims.remove(claims.keys.first);
    return message.copyWith(promptId: promptId);
  }

  /// Drops a session's correlation state — its turn was abandoned (abort) or
  /// the session is gone, so no echo will claim what is left.
  void forgetSession({required String sessionId}) {
    _pending.remove(sessionId);
    _claimed.remove(sessionId);
  }
}
