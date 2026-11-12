import "package:freezed_annotation/freezed_annotation.dart";

part "send_prompt_error_response.freezed.dart";
part "send_prompt_error_response.g.dart";

enum SendPromptErrorCode() {
  /// The send named an agent, model, variant, or command the plugin no longer
  /// offers. The client must refresh its session options, then resend with a
  /// supported selection or surface an unavailable command.
  staleSessionOptions,

  /// The harness refused the prompt for a reason its plugin explained to the
  /// user, such as a conflict with the harness's configuration. The response's
  /// `message` is that explanation, written for the user and safe to show.
  /// Older bridges answer such refusals in plain text instead.
  refused,
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
