import "package:freezed_annotation/freezed_annotation.dart";

part "send_prompt_error_response.freezed.dart";
part "send_prompt_error_response.g.dart";

enum SendPromptErrorCode() {
  /// The send named an agent, model, or variant the plugin no longer offers.
  /// The client must refresh its session options and resend with a supported
  /// selection.
  staleSessionOptions,
  unknown,
}

@Freezed(fromJson: true, toJson: true)
sealed class SendPromptErrorResponse with _$SendPromptErrorResponse {
  const factory({
    @JsonKey(unknownEnumValue: SendPromptErrorCode.unknown) required SendPromptErrorCode code,
    required String? message,
  }) = _SendPromptErrorResponse;

  factory fromJson(Map<String, dynamic> json) => _$SendPromptErrorResponseFromJson(json);
}
