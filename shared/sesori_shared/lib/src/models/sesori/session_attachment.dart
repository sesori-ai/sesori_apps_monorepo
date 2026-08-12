import "package:freezed_annotation/freezed_annotation.dart";

part "session_attachment.freezed.dart";
part "session_attachment.g.dart";

@JsonEnum()
enum SessionAttachmentRendition() { thumbnail, original }

@Freezed(fromJson: true, toJson: true)
sealed class SessionAttachmentRequest with _$SessionAttachmentRequest {
  const factory({
    required String sessionId,
    required String attachmentId,
    required SessionAttachmentRendition rendition,
  }) = _SessionAttachmentRequest;

  factory fromJson(Map<String, dynamic> json) => _$SessionAttachmentRequestFromJson(json);
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class SessionAttachmentResponse with _$SessionAttachmentResponse {
  const factory({
    required String mime,
    required String base64,
    required int byteLength,
  }) = _SessionAttachmentResponse;

  factory fromJson(Map<String, dynamic> json) => _$SessionAttachmentResponseFromJson(json);
}
