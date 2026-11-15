import "models/plugin_prompt_part.dart";
import "models/plugin_session_variant.dart";

/// Optional native rewind. Conversation only: an implementation never restores
/// or edits files.
abstract interface class SessionRewindPluginApi() {
  /// Removes [beforeMessageId] and every later message from [sessionId]'s
  /// conversation, then sends [parts] as the session's next prompt.
  ///
  /// Same acceptance, [promptId] and stale-options contract as
  /// `BridgePluginApi.sendPrompt`. The bridge calls it only for an idle
  /// session and only with a user message that opens a turn by its shared
  /// turn rule, which is presentation-level: when [beforeMessageId] cannot be
  /// mapped to a native boundary, or does not open the backend's own turn, the
  /// implementation throws `PluginBranchPointUnavailableException` before
  /// changing anything.
  Future<void> rewindAndSendPrompt({
    required String sessionId,
    required String beforeMessageId,
    required String promptId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required ({String providerID, String modelID})? model,
  });
}
