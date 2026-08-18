import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_queued_prompt.freezed.dart";

part "plugin_queued_prompt.g.dart";

/// One prompt a plugin has accepted for a session but not yet dispatched to
/// its backend.
///
/// Plugins that queue (accept at enqueue and dispatch later) expose these via
/// [BridgePluginApi.getQueuedPrompts] and announce changes with
/// `BridgeSseQueuedPromptsUpdated`. Plugins that hand prompts to their backend
/// immediately never surface any.
@freezed
sealed class PluginQueuedPrompt with _$PluginQueuedPrompt {
  const factory({
    /// The prompt id handed to `sendPrompt`/`sendCommand`.
    required String id,

    /// User-visible prompt text. Null for an attachment-only prompt — never
    /// an empty string.
    required String? text,

    /// Bare slash-command name for a command send, without the leading `/`.
    /// Null for a plain prompt.
    required String? command,

    /// Number of file attachments carried by the prompt.
    required int attachmentCount,

    /// Acceptance time in milliseconds since the Unix epoch.
    required int createdAt,
  }) = _PluginQueuedPrompt;
}
