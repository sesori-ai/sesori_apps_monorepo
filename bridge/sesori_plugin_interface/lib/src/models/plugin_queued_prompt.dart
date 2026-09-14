import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_queued_prompt.freezed.dart";

part "plugin_queued_prompt.g.dart";

/// Whether an accepted prompt can still be cancelled before backend dispatch.
enum PluginQueuedPromptDispatchState() {
  queued,
  dispatched,
}

/// An accepted prompt retained until its user message becomes visible.
/// Plugins project dispatch ownership through [dispatchState] and announce
/// changes with `BridgeSseQueuedPromptsUpdated`.
@freezed
sealed class PluginQueuedPrompt with _$PluginQueuedPrompt {
  const factory({
    /// The prompt id handed to `sendPrompt`/`sendCommand`.
    required String id,

    required PluginQueuedPromptDispatchState dispatchState,

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
