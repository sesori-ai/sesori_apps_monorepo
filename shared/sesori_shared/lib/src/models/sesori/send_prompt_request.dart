import "package:freezed_annotation/freezed_annotation.dart";

part "send_prompt_request.freezed.dart";

part "send_prompt_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class SendPromptRequest with _$SendPromptRequest {
  const factory SendPromptRequest({
    required List<PromptPart> parts,
    String? agent,
    PromptModel? model,
  }) = _SendPromptRequest;

  factory SendPromptRequest.fromJson(Map<String, dynamic> json) => _$SendPromptRequestFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PromptPart with _$PromptPart {
  const factory PromptPart({
    required String type,
    String? text,
  }) = _PromptPart;

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
