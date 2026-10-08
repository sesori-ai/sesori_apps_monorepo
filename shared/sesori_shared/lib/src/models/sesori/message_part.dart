import "dart:developer" as developer;

import "package:freezed_annotation/freezed_annotation.dart";

part "message_part.freezed.dart";

part "message_part.g.dart";

/// Maximum decoded size for an inline image carried in a message payload.
///
/// Inline data is base64-encoded inside JSON and then encrypted for relay
/// transport, so keeping this bounded protects both relay frames and clients.
const maxInlineMessageAttachmentBytes = 5 * 1024 * 1024;

/// Maximum decoded size retained for one backend-produced transcript image.
const maxTranscriptImageBytes = 20 * 1024 * 1024;

/// Maximum decoded image bytes retained for one logical transcript collection.
const maxTranscriptImageCollectionBytes = 50 * 1024 * 1024;

/// Maximum backend-produced image candidates retained in one collection.
const maxTranscriptImageCandidates = 4;

/// Whether [base64Length] can decode within [maxInlineMessageAttachmentBytes].
bool isInlineMessageAttachmentWithinSizeLimit({required int base64Length}) {
  return conservativeDecodedBase64Length(base64Length: base64Length) <= maxInlineMessageAttachmentBytes;
}

/// Whether an unnormalized base64 payload can decode within the transcript
/// image limit. Callers still verify exact decoded size after normalization.
bool isTranscriptImageBase64LengthWithinSizeLimit({required int base64Length}) {
  if (base64Length < 0) return false;
  const maxEncodedLength = ((maxTranscriptImageBytes + 2) ~/ 3) * 4;
  return base64Length <= maxEncodedLength;
}

/// Conservative decoded size for a base64 payload when padding is unknown.
int conservativeDecodedBase64Length({required int base64Length}) => (base64Length * 3 + 3) ~/ 4;

/// Exact decoded size for normalized base64 data, accounting for padding.
int decodedBase64Length({required String base64Data}) {
  if (base64Data.isEmpty) return 0;
  final padding = base64Data.endsWith("==")
      ? 2
      : base64Data.endsWith("=")
      ? 1
      : 0;
  return (base64Data.length * 3 ~/ 4) - padding;
}

final class const _MalformedMessageAttachmentError({required final Object innerError}) implements Exception {
  @override
  String toString() => "Malformed message attachment payload";
}

// ignore: no_slop_linter/prefer_specific_type, JSON converter input
MessageAttachment? _messageAttachmentOrNullFromJson(Object? json) {
  if (json == null) return null;
  if (json is! Map) {
    developer.log("Ignoring malformed message attachment payload", name: "sesori_shared");
    return null;
  }
  try {
    // ignore: no_slop_linter/prefer_specific_type, generated fromJson signature
    return MessageAttachment.fromJson(Map<String, dynamic>.from(json));
  } on Object catch (error, stackTrace) {
    developer.log(
      "Ignoring malformed message attachment payload",
      name: "sesori_shared",
      error: _MalformedMessageAttachmentError(innerError: error),
      stackTrace: stackTrace,
    );
    return null;
  }
}

// ignore: no_slop_linter/prefer_specific_type, JSON converter input
MessageAttachment _messageAttachmentFromJson(Object? json) =>
    _messageAttachmentOrNullFromJson(json) ?? const MessageAttachment.unknown();

// ignore: no_slop_linter/prefer_specific_type, JSON converter input
List<MessageAttachment> _messageAttachmentsFromJson(Object? json) {
  if (json == null) return const [];
  if (json is! List) {
    developer.log("Ignoring malformed message attachments payload", name: "sesori_shared");
    return const [];
  }
  return [
    for (final item in json) ?_messageAttachmentOrNullFromJson(item),
  ];
}

@JsonEnum()
enum MessageAttachmentDelivery() {
  inline,
  storedReference,
}

@Freezed(unionKey: "type", fromJson: true, toJson: true)
sealed class const MessagePart._() with _$MessagePart {
  @FreezedUnionValue("text")
  const factory text({
    required String id,
    required String sessionID,
    required String messageID,
    // COMPATIBILITY 2026-08-25 (v1.8.1): Released bridges can omit text.
    // Remove @Default and require text when the minimum supported bridge always sends it.
    @Default("") String text,
  }) = MessagePartText;

  @FreezedUnionValue("reasoning")
  const factory reasoning({
    required String id,
    required String sessionID,
    required String messageID,
    // COMPATIBILITY 2026-08-25 (v1.8.1): Released bridges can omit text.
    // Remove @Default and require text when the minimum supported bridge always sends it.
    @Default("") String text,
  }) = MessagePartReasoning;

  @FreezedUnionValue("tool")
  const factory tool({
    required String id,
    required String sessionID,
    required String messageID,
    // COMPATIBILITY 2026-08-25 (v1.8.1): Released bridges can omit the tool name.
    // Remove @Default and require tool when the minimum supported bridge always sends it.
    @Default("") String tool,
    // COMPATIBILITY 2026-08-25 (v1.8.1): Released bridges can omit tool state.
    // Remove @Default and require state when the minimum supported bridge always sends it.
    @Default(
      ToolState(
        status: ToolStatus.pending,
        title: null,
        shellCommand: null,
        output: null,
        error: null,
      ),
    )
    ToolState state,
  }) = MessagePartTool;

  @FreezedUnionValue("subtask")
  const factory subtask({
    required String id,
    required String sessionID,
    required String messageID,
    // COMPATIBILITY 2026-08-25 (v1.8.1): Released bridges can omit the subtask prompt.
    // Remove @Default and require prompt when the minimum supported bridge always sends it.
    @Default("") String prompt,
    // COMPATIBILITY 2026-08-25 (v1.8.1): Released bridges can omit the subtask description.
    // Remove @Default and require description when the minimum supported bridge always sends it.
    @Default("") String description,
    // COMPATIBILITY 2026-08-25 (v1.8.1): Released bridges can omit the subtask agent.
    // Remove @Default and require agent when the minimum supported bridge always sends it.
    @Default("") String agent,

    /// The subtask's own lifecycle, authoritative for its inline status. Null
    /// when the backend reports none, leaving consumers to infer it.
    required ToolState? taskState,

    /// The session hosting this subtask's work, when the backend exposes one
    /// and the bridge could resolve it. Null leaves consumers to their own
    /// association, so a part is never withheld for an unresolved reference.
    required String? childSessionID,
  }) = MessagePartSubtask;

  @FreezedUnionValue("step-start")
  const factory stepStart({required String id, required String sessionID, required String messageID}) =
      MessagePartStepStart;

  @FreezedUnionValue("step-finish")
  const factory stepFinish({required String id, required String sessionID, required String messageID}) =
      MessagePartStepFinish;

  @FreezedUnionValue("file")
  const factory file({
    required String id,
    required String sessionID,
    required String messageID,
    // COMPATIBILITY 2026-08-25 (v1.8.1): Released bridges can omit the attachment.
    // Remove @Default and require attachment when the minimum supported bridge always sends it.
    @JsonKey(fromJson: _messageAttachmentFromJson) @Default(MessageAttachment.unknown()) MessageAttachment attachment,
  }) = MessagePartFile;

  @FreezedUnionValue("snapshot")
  const factory snapshot({required String id, required String sessionID, required String messageID}) =
      MessagePartSnapshot;

  @FreezedUnionValue("patch")
  const factory patch({required String id, required String sessionID, required String messageID}) = MessagePartPatch;

  @FreezedUnionValue("agent")
  const factory agent({
    required String id,
    required String sessionID,
    required String messageID,
    // COMPATIBILITY 2026-08-25 (v1.8.1): Released bridges can omit the agent name.
    // Remove @Default and require agentName when the minimum supported bridge always sends it.
    @Default("") String agentName,
  }) = MessagePartAgent;

  @FreezedUnionValue("retry")
  const factory retry({
    required String id,
    required String sessionID,
    required String messageID,
    // COMPATIBILITY 2026-08-25 (v1.8.1): Released bridges can omit the retry attempt.
    // Remove @Default and require attempt when the minimum supported bridge always sends it.
    @Default(0) int attempt,
    // COMPATIBILITY 2026-08-25 (v1.8.1): Released bridges can omit the retry error.
    // Remove @Default and require retryError when the minimum supported bridge always sends it.
    @Default("") String retryError,
  }) = MessagePartRetry;

  /// The harness compacts its context here: running, completed or failed.
  @FreezedUnionValue("compaction")
  const factory compaction({
    required String id,
    required String sessionID,
    required String messageID,
    // COMPATIBILITY 2026-10-07 (v1.9.1): Released bridges send compaction parts only for finished
    // compactions and without a state. Remove @Default and require state when the minimum supported
    // bridge always sends it.
    @Default(CompactionState.completed(summary: null, freedTokens: null, trigger: null)) CompactionState state,
  }) = MessagePartCompaction;

  factory fromJson(Map<String, dynamic> json) => _$MessagePartFromJson(json);
}

/// What started a context compaction. Only reported where the harness says.
@JsonEnum()
enum CompactionTrigger() {
  manual,
  auto,
}

/// How far one context compaction got.
///
/// A status added by a newer bridge decodes as [CompactionState.completed],
/// keeping any completed fields it carries, so the transcript still decodes.
@Freezed(unionKey: "status", fallbackUnion: "completed", fromJson: true, toJson: true)
sealed class CompactionState with _$CompactionState {
  /// Compacting now. [summary] is the text written so far, when the harness
  /// streams it.
  @FreezedUnionValue("running")
  const factory running({required String? summary}) = CompactionStateRunning;

  /// Compacted. [summary] is the continuation summary the harness carried
  /// forward, and [freedTokens] the context it released, each null when the
  /// harness does not report it.
  @FreezedUnionValue("completed")
  const factory completed({
    required String? summary,
    required int? freedTokens,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) required CompactionTrigger? trigger,
  }) = CompactionStateCompleted;

  /// The compaction ended without compacting. [reason] is why, when the cause
  /// is one the bridge recognizes; the raw error stays in the bridge's log.
  @FreezedUnionValue("failed")
  const factory failed({
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) required CompactionFailureReason? reason,
  }) = CompactionStateFailed;

  factory fromJson(Map<String, dynamic> json) => _$CompactionStateFromJson(json);
}

/// Why a context compaction failed, for the causes a harness reports in a
/// recognizable form. Any other cause is null.
@JsonEnum()
enum CompactionFailureReason() {
  /// The conversation is too short to summarize.
  nothingToCompact,

  /// Nothing new has happened since the last compaction.
  alreadyCompacted,

  /// The user or the harness stopped it.
  cancelled,

  /// The turn ended, or the harness exited, before it finished.
  turnEnded,
}

/// A client-safe attachment source normalized by the owning backend plugin.
///
/// Local host paths never cross this contract. Clients may render bounded
/// inline image data and auto-load HTTPS raster image URLs; other remote URLs
/// require an explicit user action.
@Freezed(
  unionKey: "source",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: true,
  toStringOverride: false,
)
sealed class MessageAttachment with _$MessageAttachment {
  @FreezedUnionValue("inline_image")
  const factory inlineImage({
    required String mime,
    required String base64,
    required String? filename,
  }) = MessageAttachmentInlineImage;

  @FreezedUnionValue("remote_url")
  const factory remoteUrl({
    required String mime,
    required String url,
    required String? filename,
  }) = MessageAttachmentRemoteUrl;

  @FreezedUnionValue("stored_image")
  const factory storedImage({
    required String attachmentId,
    required String bridgeId,
    required String mime,
    required String? filename,
    required int byteLength,
  }) = MessageAttachmentStoredImage;

  const factory metadata({
    required String mime,
    required String? filename,
  }) = MessageAttachmentMetadata;

  /// Forward-compatible fallback for attachment sources added by newer peers.
  const factory unknown() = MessageAttachmentUnknown;

  factory fromJson(Map<String, dynamic> json) => _$MessageAttachmentFromJson(json);
}

extension MessageAttachmentSafety on MessageAttachment {
  /// Returns a launchable HTTP(S) URI, or `null` for malformed/unsafe input.
  Uri? get safeRemoteUri {
    final rawUrl = switch (this) {
      MessageAttachmentRemoteUrl(:final url) => url,
      MessageAttachmentInlineImage() ||
      MessageAttachmentStoredImage() ||
      MessageAttachmentMetadata() ||
      MessageAttachmentUnknown() => null,
    };
    if (rawUrl == null) return null;

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
    final scheme = uri.scheme.toLowerCase();
    return scheme == "http" || scheme == "https" ? uri : null;
  }
}

/// Lifecycle of a tool invocation, and of a subtask that reports one. Wire
/// values mirror OpenCode's tool-state `status` discriminator, plus
/// [cancelled] for work a backend stopped before it produced a result;
/// [unknown] is the forward-compatible fallback for any status a newer bridge
/// emits that this client does not yet model, which is how a client older
/// than [cancelled] reads it.
@JsonEnum()
enum ToolStatus() {
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

/// How a page request wants finished tools' output and error delivered.
@JsonEnum()
enum ToolOutputDelivery() {
  /// Every tool part carries its output and error.
  inline,

  /// Finished tool parts that have output or error arrive as
  /// [ToolStateSummary]; the app fetches the detail through
  /// `POST /session/tool-output` when a row expands.
  onExpand,
}

/// A tool part's state, in full or as a summary without its output and error.
///
/// JSON without a `form` key, from stored rows and from bridges that predate
/// summaries, decodes as [ToolStateFull].
@Freezed(unionKey: "form", fallbackUnion: "default", fromJson: true, toJson: true)
sealed class ToolState with _$ToolState {
  @FreezedUnionValue("full")
  const factory({
    @JsonKey(unknownEnumValue: ToolStatus.unknown) required ToolStatus status,
    required String? title,
    required String? shellCommand,
    required String? output,
    required String? error,
    // COMPATIBILITY 2026-07-30 (v1.6.1): Older bridges omit attachments,
    // which means the tool returned none. Remove @Default and require
    // attachments after the minimum supported bridge sends it.
    @JsonKey(fromJson: _messageAttachmentsFromJson) @Default(<MessageAttachment>[]) List<MessageAttachment> attachments,
  }) = ToolStateFull;

  /// A finished tool whose output or error the bridge withheld; the app
  /// fetches them through `POST /session/tool-output`.
  @FreezedUnionValue("summary")
  const factory summary({
    @JsonKey(unknownEnumValue: ToolStatus.unknown) required ToolStatus status,
    required String? title,
    required String? shellCommand,
    @JsonKey(fromJson: _messageAttachmentsFromJson) required List<MessageAttachment> attachments,
  }) = ToolStateSummary;

  factory fromJson(Map<String, dynamic> json) => _$ToolStateFromJson(json);
}
