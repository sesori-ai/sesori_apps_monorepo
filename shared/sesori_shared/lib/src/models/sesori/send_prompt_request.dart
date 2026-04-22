import "package:freezed_annotation/freezed_annotation.dart";

import "session_effort.dart";

part "send_prompt_request.freezed.dart";

part "send_prompt_request.g.dart";

/// Request body for `POST /session/prompt`.
@Freezed(fromJson: true, toJson: true)
sealed class SendPromptRequest with _$SendPromptRequest {
  const factory SendPromptRequest({
    required String sessionId,
    required List<PromptPart> parts,
    required String? agent,
    required PromptModel? model,
    required String? command,
    required SessionEffort? effort,
  }) = _SendPromptRequest;

  factory SendPromptRequest.fromJson(Map<String, dynamic> json) => _$SendPromptRequestFromJson(json);
}

/// Prompt part types for the mobile ↔ bridge protocol.
@Freezed(unionKey: "type", fromJson: true, toJson: true)
sealed class PromptPart with _$PromptPart {
  /// Plain text content.
  @FreezedUnionValue("text")
  const factory PromptPart.text({required String text}) = PromptPartText;

  /// Local file on the host filesystem, referenced by absolute path.
  @FreezedUnionValue("file_path")
  const factory PromptPart.filePath({
    required String mime,
    required String path,
    required String? filename,
  }) = PromptPartFilePath;

  /// Remote file referenced by URL (`https://`, etc.).
  @FreezedUnionValue("file_url")
  const factory PromptPart.fileUrl({
    required String mime,
    required String url,
    required String? filename,
  }) = PromptPartFileUrl;

  /// Inline file content as base64-encoded data.
  @FreezedUnionValue("file_data")
  const factory PromptPart.fileData({
    required String mime,
    required String base64,
    required String? filename,
  }) = PromptPartFileData;

  factory PromptPart.fromJson(Map<String, dynamic> json) => _$PromptPartFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PromptModel with _$PromptModel {
  const factory PromptModel({
    required String providerID,
    required String modelID,
  }) = _PromptModel;

  factory PromptModel.fromJson(Map<String, dynamic> json) => _$PromptModelFromJson(json);
}
