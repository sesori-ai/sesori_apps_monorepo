import "models/plugin_session.dart";

/// Optional native fork. The new session shares the origin's directory;
/// nothing on disk is copied.
abstract interface class SessionForkPluginApi() {
  /// Creates a backend session whose conversation is [sessionId]'s through
  /// [throughMessageId], inclusive, the last message of a finished turn by the
  /// shared turn rule. The origin is left unchanged and stays usable.
  ///
  /// Returns the new session with its real directory, and emits
  /// `BridgeSseSessionCreated` for it the same way `BridgePluginApi.createSession`
  /// does, so every client learns of the fork. The bridge may call it while a
  /// later turn of [sessionId] runs, and for an archived session.
  ///
  /// When [throughMessageId] cannot be mapped to a native boundary, or the
  /// backend no longer has [sessionId]'s conversation, the implementation
  /// throws `PluginBranchPointUnavailableException` before creating anything.
  Future<PluginSession> forkSession({required String sessionId, required String throughMessageId});
}
