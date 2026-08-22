import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_message.freezed.dart";

part "plugin_message.g.dart";

/// Maximum length for tool output sent to mobile.
/// Mobile truncates to this length anyway, so we truncate at the source.
const maxToolOutputLength = 500;

/// Normalizes untrusted attachment metadata to a display-safe basename.
String? normalizePluginMessageAttachmentFilename({required String? filename}) {
  const maxCharacters = 255;
  final normalized = filename?.trim().replaceAll(r"\", "/");
  if (normalized == null || normalized.isEmpty) return null;
  final segments = normalized.split("/").where((segment) => segment.isNotEmpty);
  return segments.isEmpty ? null : String.fromCharCodes(segments.last.runes.take(maxCharacters));
}

@JsonEnum()
enum PluginMessagePartType() {
  @JsonValue("text")
  text,
  @JsonValue("reasoning")
  reasoning,
  @JsonValue("tool")
  tool,
  @JsonValue("subtask")
  subtask,
  @JsonValue("step-start")
  stepStart,
  @JsonValue("step-finish")
  stepFinish,
  @JsonValue("file")
  file,
  @JsonValue("snapshot")
  snapshot,
  @JsonValue("patch")
  patch,
  @JsonValue("agent")
  agent,
  @JsonValue("retry")
  retry,
  @JsonValue("compaction")
  compaction,
  @JsonValue("unknown")
  unknown;

  /// Whether this part type is visible to mobile (rendered in the UI).
  bool get isVisible => this != snapshot && this != patch && this != compaction && this != unknown;
}

@freezed
sealed class PluginMessageWithParts with _$PluginMessageWithParts {
  const factory({
    required PluginMessage info,
    required List<PluginMessagePart> parts,
  }) = _PluginMessageWithParts;
}

@freezed
sealed class PluginMessagePart with _$PluginMessagePart {
  const factory({
    required String id,
    required String sessionID,
    required String messageID,
    required PluginMessagePartType type,
    // text / reasoning
    required String? text,
    // tool
    required String? tool,
    required PluginToolState? state,
    // subtask
    required String? prompt,
    required String? description,
    required String? agent,

    /// The backend session hosting this subtask's work, when the backend
    /// exposes one. The bridge translates it to a bridge session id.
    required String? childSessionID,
    // agent
    required String? agentName,
    // retry
    required int? attempt,
    required String? retryError,
    // file
    required PluginMessageAttachment? attachment,
  }) = _PluginMessagePart;
}

/// A backend-normalized attachment that is safe to expose outside the plugin.
@Freezed(unionKey: "source", toStringOverride: false)
sealed class PluginMessageAttachment with _$PluginMessageAttachment {
  @FreezedUnionValue("inline_image")
  const factory inlineImage({
    required String mime,
    required String base64,
    required String? filename,
  }) = PluginMessageAttachmentInlineImage;

  @FreezedUnionValue("remote_url")
  const factory remoteUrl({
    required String mime,
    required Uri url,
    required String? filename,
  }) = PluginMessageAttachmentRemoteUrl;

  const factory metadata({
    required String mime,
    required String? filename,
  }) = PluginMessageAttachmentMetadata;
}

/// Lifecycle status of a tool invocation, and of a subtask whose part carries
/// a [PluginToolState]. Mirrors the OpenCode `ToolState` union discriminator
/// so consumers switch on enum members instead of matching magic strings,
/// plus [cancelled] for work a backend stopped before it produced a result.
/// The `@JsonValue`s keep the wire form (`"pending"`, `"running"`, …)
/// unchanged.
@JsonEnum()
enum PluginToolStatus() {
  @JsonValue("pending")
  pending,
  @JsonValue("running")
  running,
  @JsonValue("completed")
  completed,
  @JsonValue("error")
  error,
  @JsonValue("cancelled")
  cancelled,
  @JsonValue("unknown")
  unknown,
}

@freezed
sealed class PluginToolState with _$PluginToolState {
  const factory({
    required PluginToolStatus status,
    required String? title,
    required String? output,
    required String? error,
    required List<PluginMessageAttachment> attachments,
  }) = _PluginToolState;
}

/// Sealed class representing a plugin-level message.
///
/// Three variants:
/// - [PluginMessageUser]: a message sent by the user
/// - [PluginMessageAssistant]: a regular assistant response
/// - [PluginMessageError]: an assistant message that failed with an error
///
/// The JSON serialization uses `"role"` as the union key.
@Freezed(unionKey: "role")
sealed class PluginMessage with _$PluginMessage {
  const factory user({
    required String id,
    required String sessionID,
    required String? agent,
    required PluginMessageTime? time,

    /// The `sendPrompt`/`sendCommand` prompt id this message fulfilled, when
    /// known. Attached on the live event that consumes a queued prompt so
    /// clients can swap the queued bubble for this message atomically.
    /// History reads that cannot reconstruct it carry null.
    required String? promptId,
  }) = PluginMessageUser;

  const factory assistant({
    required String id,
    required String sessionID,
    required String? agent,
    required String? modelID,
    required String? providerID,
    required PluginMessageTime? time,
  }) = PluginMessageAssistant;

  const factory error({
    required String id,
    required String sessionID,
    required String? agent,
    required String? modelID,
    required String? providerID,
    required String errorName,
    required String errorMessage,
    required PluginMessageTime? time,
  }) = PluginMessageError;
}

/// Lifecycle timestamps for a [PluginMessage], in milliseconds since the
/// Unix epoch. Mirrors [PluginSessionTime].
@freezed
sealed class PluginMessageTime with _$PluginMessageTime {
  const factory({
    required int created,
    required int? completed,
  }) = _PluginMessageTime;
}
