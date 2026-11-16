/// Optional support for a session-wide "edits run without asking" grant, which
/// a backend turns on when the user allows file edits for the rest of the
/// session. Backends emit `BridgeSseSessionEditsAutoAcceptedChanged` when it
/// changes.
abstract interface class SessionEditsAutoAcceptPluginApi() {
  bool editsAutoAccepted({required String sessionId});

  /// Ends the grant so the session's next file edit asks again. A no-op when
  /// the session holds none.
  Future<void> stopAcceptingEdits({required String sessionId});
}
