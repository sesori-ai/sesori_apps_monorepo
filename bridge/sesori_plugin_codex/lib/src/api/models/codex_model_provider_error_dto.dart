import "package:freezed_annotation/freezed_annotation.dart";

part "codex_model_provider_error_dto.freezed.dart";
part "codex_model_provider_error_dto.g.dart";

/// JSON-RPC `error.data` codex attaches when a stored thread's model provider
/// cannot be used under the current configuration (observed on
/// `thread/resume`, codex-cli 0.167). Other error data falls to [unknown].
@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: false,
)
sealed class CodexModelProviderErrorDto with _$CodexModelProviderErrorDto {
  @FreezedUnionValue("modelProviderMismatch")
  const factory mismatch({
    required String modelProvider,
    required String currentModelProvider,
  }) = CodexModelProviderMismatchDto;

  @FreezedUnionValue("modelProviderNotConfigured")
  const factory notConfigured({required String modelProvider}) = CodexModelProviderNotConfiguredDto;

  @FreezedUnionValue("modelProviderPolicyConflict")
  const factory policyConflict({
    required String modelProvider,
    required String requiredModelProvider,
  }) = CodexModelProviderPolicyConflictDto;

  const factory unknown() = CodexUnknownModelProviderErrorDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexModelProviderErrorDtoFromJson(json);
}
