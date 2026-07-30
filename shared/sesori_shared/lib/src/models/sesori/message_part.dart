import "package:freezed_annotation/freezed_annotation.dart";

part "message_part.freezed.dart";

part "message_part.g.dart";

/// Maximum decoded size for an inline image carried in a message payload.
///
/// Inline data is base64-encoded inside JSON and then encrypted for relay
/// transport, so keeping this bounded protects both relay frames and clients.
const maxInlineMessageAttachmentBytes = 5 * 1024 * 1024;

/// Whether [base64Length] can decode within [maxInlineMessageAttachmentBytes].
bool isInlineMessageAttachmentWithinSizeLimit({required int base64Length}) {
  const maxEncodedLength = ((maxInlineMessageAttachmentBytes + 2) ~/ 3) * 4;
  return base64Length <= maxEncodedLength;
}

@JsonEnum()
enum MessagePartType {
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
}

@Freezed(fromJson: true, toJson: true)
sealed class MessagePart with _$MessagePart {
  const factory MessagePart({
    required String id,
    required String sessionID,
    required String messageID,
    required MessagePartType type,
    required String? text,
    required String? tool,
    required ToolState? state,
    required String? prompt,
    required String? description,
    required String? agent,
    required String? agentName,
    required int? attempt,
    required String? retryError,
    required MessageAttachment? attachment,
  }) = _MessagePart;

  factory MessagePart.fromJson(Map<String, dynamic> json) => _$MessagePartFromJson(json);
}

/// A client-safe attachment source normalized by the owning backend plugin.
///
/// Local host paths never cross this contract. Remote URLs require an explicit
/// user action, while bounded inline image data may be rendered directly.
@Freezed(
  unionKey: "source",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: true,
  toStringOverride: false,
)
sealed class MessageAttachment with _$MessageAttachment {
  @FreezedUnionValue("inline_image")
  const factory MessageAttachment.inlineImage({
    required String mime,
    required String base64,
    required String? filename,
  }) = MessageAttachmentInlineImage;

  @FreezedUnionValue("remote_url")
  const factory MessageAttachment.remoteUrl({
    required String mime,
    required String url,
    required String? filename,
  }) = MessageAttachmentRemoteUrl;

  const factory MessageAttachment.metadata({
    required String mime,
    required String? filename,
  }) = MessageAttachmentMetadata;

  /// Forward-compatible fallback for attachment sources added by newer peers.
  const factory MessageAttachment.unknown() = MessageAttachmentUnknown;

  factory MessageAttachment.fromJson(Map<String, dynamic> json) => _$MessageAttachmentFromJson(json);
}

extension MessageAttachmentSafety on MessageAttachment {
  /// Returns a launchable HTTP(S) URI, or `null` for malformed/unsafe input.
  Uri? get safeRemoteUri {
    final rawUrl = switch (this) {
      MessageAttachmentRemoteUrl(:final url) => url,
      MessageAttachmentInlineImage() || MessageAttachmentMetadata() || MessageAttachmentUnknown() => null,
    };
    if (rawUrl == null) return null;

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
    final scheme = uri.scheme.toLowerCase();
    return scheme == "http" || scheme == "https" ? uri : null;
  }
}

/// Lifecycle of a tool invocation. Wire values mirror OpenCode's tool-state
/// `status` discriminator 1:1; [unknown] is the forward-compatible fallback for
/// any status a newer bridge emits that this client does not yet model.
@JsonEnum()
enum ToolStatus {
  @JsonValue("pending")
  pending,
  @JsonValue("running")
  running,
  @JsonValue("completed")
  completed,
  @JsonValue("error")
  error,
  @JsonValue("unknown")
  unknown,
}

@Freezed(fromJson: true, toJson: true)
sealed class ToolState with _$ToolState {
  const factory ToolState({
    @JsonKey(unknownEnumValue: ToolStatus.unknown) required ToolStatus status,
    required String? title,
    required String? output,
    required String? error,
    // COMPATIBILITY 2026-07-30 (v1.6.1): Older bridges omit attachments, which means the tool returned none. Remove @Default and require attachments after the minimum supported bridge sends it.
    @Default(<MessageAttachment>[]) List<MessageAttachment> attachments,
  }) = _ToolState;

  factory ToolState.fromJson(Map<String, dynamic> json) => _$ToolStateFromJson(json);
}
