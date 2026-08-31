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

@Freezed(unionKey: "type")
sealed class const PluginMessagePart._() with _$PluginMessagePart {
  @FreezedUnionValue("text")
  const factory text({required String id, required String sessionID, required String messageID, @JsonKey(includeToJson: true) required String text}) =
      PluginMessagePartText;

  @FreezedUnionValue("reasoning")
  const factory reasoning({
    required String id,
    required String sessionID,
    required String messageID,
    @JsonKey(includeToJson: true) required String text,
  }) = PluginMessagePartReasoning;

  @FreezedUnionValue("tool")
  const factory tool({
    required String id,
    required String sessionID,
    required String messageID,
    @JsonKey(includeToJson: true) required String? tool,
    @JsonKey(includeToJson: true) required PluginToolState state,
  }) = PluginMessagePartTool;

  @FreezedUnionValue("subtask")
  const factory subtask({
    required String id,
    required String sessionID,
    required String messageID,
    required String prompt,
    required String description,
    required String agent,
  }) = PluginMessagePartSubtask;

  @FreezedUnionValue("step-start")
  const factory stepStart({required String id, required String sessionID, required String messageID}) =
      PluginMessagePartStepStart;

  @FreezedUnionValue("step-finish")
  const factory stepFinish({required String id, required String sessionID, required String messageID}) =
      PluginMessagePartStepFinish;

  @FreezedUnionValue("file")
  const factory file({
    required String id,
    required String sessionID,
    required String messageID,
    @JsonKey(includeToJson: true) required PluginMessageAttachment attachment,
  }) = PluginMessagePartFile;

  @FreezedUnionValue("snapshot")
  const factory snapshot({required String id, required String sessionID, required String messageID}) =
      PluginMessagePartSnapshot;

  @FreezedUnionValue("patch")
  const factory patch({required String id, required String sessionID, required String messageID}) =
      PluginMessagePartPatch;

  @FreezedUnionValue("agent")
  const factory agent({
    required String id,
    required String sessionID,
    required String messageID,
    @JsonKey(includeToJson: true) required String agentName,
  }) = PluginMessagePartAgent;

  @FreezedUnionValue("retry")
  const factory retry({
    required String id,
    required String sessionID,
    required String messageID,
    @JsonKey(includeToJson: true) required int attempt,
    @JsonKey(includeToJson: true) required String retryError,
  }) = PluginMessagePartRetry;

  @FreezedUnionValue("compaction")
  const factory compaction({required String id, required String sessionID, required String messageID}) =
      PluginMessagePartCompaction;

  @FreezedUnionValue("unknown")
  const factory unknown({required String id, required String sessionID, required String messageID}) =
      PluginMessagePartUnknown;

  @JsonKey(includeFromJson: false, includeToJson: false)
  String get text {
    if (this case PluginMessagePartText(:final text) || PluginMessagePartReasoning(:final text)) return text;
    throw StateError("Expected textual message part, got ${type.name}");
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  String? get tool => asTool.tool;

  @JsonKey(includeFromJson: false, includeToJson: false)
  PluginToolState get state => asTool.state;

  @JsonKey(includeFromJson: false, includeToJson: false)
  PluginMessageAttachment get attachment => asFile.attachment;

  @JsonKey(includeFromJson: false, includeToJson: false)
  String get agentName => asAgent.agentName;

  @JsonKey(includeFromJson: false, includeToJson: false)
  int get attempt => asRetry.attempt;

  @JsonKey(includeFromJson: false, includeToJson: false)
  String get retryError => asRetry.retryError;

  @JsonKey(includeFromJson: false, includeToJson: false)
  PluginMessagePartText get asText {
    if (this case final PluginMessagePartText part) return part;
    throw StateError("Expected text message part, got ${type.name}");
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  PluginMessagePartReasoning get asReasoning {
    if (this case final PluginMessagePartReasoning part) return part;
    throw StateError("Expected reasoning message part, got ${type.name}");
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  PluginMessagePartTool get asTool {
    if (this case final PluginMessagePartTool part) return part;
    throw StateError("Expected tool message part, got ${type.name}");
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  PluginMessagePartFile get asFile {
    if (this case final PluginMessagePartFile part) return part;
    throw StateError("Expected file message part, got ${type.name}");
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  PluginMessagePartAgent get asAgent {
    if (this case final PluginMessagePartAgent part) return part;
    throw StateError("Expected agent message part, got ${type.name}");
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  PluginMessagePartRetry get asRetry {
    if (this case final PluginMessagePartRetry part) return part;
    throw StateError("Expected retry message part, got ${type.name}");
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  PluginMessagePartType get type => switch (this) {
    PluginMessagePartText() => PluginMessagePartType.text,
    PluginMessagePartReasoning() => PluginMessagePartType.reasoning,
    PluginMessagePartTool() => PluginMessagePartType.tool,
    PluginMessagePartSubtask() => PluginMessagePartType.subtask,
    PluginMessagePartStepStart() => PluginMessagePartType.stepStart,
    PluginMessagePartStepFinish() => PluginMessagePartType.stepFinish,
    PluginMessagePartFile() => PluginMessagePartType.file,
    PluginMessagePartSnapshot() => PluginMessagePartType.snapshot,
    PluginMessagePartPatch() => PluginMessagePartType.patch,
    PluginMessagePartAgent() => PluginMessagePartType.agent,
    PluginMessagePartRetry() => PluginMessagePartType.retry,
    PluginMessagePartCompaction() => PluginMessagePartType.compaction,
    PluginMessagePartUnknown() => PluginMessagePartType.unknown,
  };

  static PluginMessagePart fromText({
    required String id,
    required String sessionID,
    required String messageID,
    @JsonKey(includeToJson: true) required String text,
  }) => .text(id: id, sessionID: sessionID, messageID: messageID, text: text);

  static PluginMessagePart fromThinking({
    required String id,
    required String sessionID,
    required String messageID,
    @JsonKey(includeToJson: true) required String text,
  }) => .reasoning(id: id, sessionID: sessionID, messageID: messageID, text: text);

  static PluginMessagePart fromTool({
    required String id,
    required String sessionID,
    required String messageID,
    required String tool,
    required PluginToolState state,
  }) => .tool(id: id, sessionID: sessionID, messageID: messageID, tool: tool, state: state);
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

/// Lifecycle status of a tool invocation. Mirrors the OpenCode `ToolState`
/// union discriminator so consumers switch on enum members instead of
/// matching magic strings. The `@JsonValue`s keep the wire form
/// (`"pending"`, `"running"`, …) unchanged.
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
  @JsonValue("unknown")
  unknown;

  bool get isTerminal => this == completed || this == error;
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

/// Identifies who authored a plugin's non-user message envelope.
///
/// [unknown] lets a plugin preserve uncertain attribution without presenting
/// the message as agent-authored.
@JsonEnum()
enum PluginMessageSender() { agent, system, unknown }

/// Sealed class representing a plugin-level message.
///
/// Three variants:
/// - [PluginMessageUser]: a message sent by the user
/// - [PluginMessageAssistant]: a non-user message with explicit sender attribution
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
    required String? variant,
    required PluginMessageSender sender,
    required PluginMessageTime? time,
  }) = PluginMessageAssistant;

  const factory error({
    required String id,
    required String sessionID,
    required String? agent,
    required String? modelID,
    required String? providerID,
    required String? variant,
    required String errorName,

    /// Backend-provided error text must be preserved verbatim when present.
    /// A plugin may synthesize a fallback only when its backend supplied no text.
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
