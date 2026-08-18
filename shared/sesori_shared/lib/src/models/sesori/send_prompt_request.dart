import "package:freezed_annotation/freezed_annotation.dart";

import "session_variant.dart";

part "send_prompt_request.freezed.dart";

part "send_prompt_request.g.dart";

/// Request body for `POST /session/prompt_async`.
@Freezed(fromJson: true, toJson: true)
sealed class SendPromptRequest with _$SendPromptRequest {
  const factory({
    required String sessionId,
    required List<PromptPart> parts,
    required String? agent,
    required PromptModel? model,
    required String? command,
    required SessionVariant? variant,

    /// Client-generated identity for this prompt, stable across retries.
    ///
    /// The bridge queues, dedupes, and correlates the eventual transcript
    /// message under this id. Null from clients that predate it; the bridge
    /// generates a fallback so plugins always receive one.
    required String? promptId,
  }) = _SendPromptRequest;

  factory fromJson(Map<String, dynamic> json) => _$SendPromptRequestFromJson(json);
}

/// Prompt part types for the mobile ↔ bridge protocol.
@Freezed(unionKey: "type", fromJson: true, toJson: true)
sealed class PromptPart with _$PromptPart {
  /// Plain text content.
  @FreezedUnionValue("text")
  const factory text({required String text}) = PromptPartText;

  /// Local file on the host filesystem, referenced by absolute path.
  @FreezedUnionValue("file_path")
  const factory filePath({
    required String mime,
    required String path,
    required String? filename,
  }) = PromptPartFilePath;

  /// Remote file referenced by URL (`https://`, etc.).
  @FreezedUnionValue("file_url")
  const factory fileUrl({
    required String mime,
    required String url,
    required String? filename,
  }) = PromptPartFileUrl;

  /// Inline file content as base64-encoded data.
  @FreezedUnionValue("file_data")
  const factory fileData({
    required String mime,
    required String base64,
    required String? filename,
  }) = PromptPartFileData;

  factory fromJson(Map<String, dynamic> json) => _$PromptPartFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PromptModel with _$PromptModel {
  const factory({
    required String providerID,
    required String modelID,
  }) = _PromptModel;

  factory fromJson(Map<String, dynamic> json) => _$PromptModelFromJson(json);
}
