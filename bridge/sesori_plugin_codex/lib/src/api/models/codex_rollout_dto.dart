import "package:freezed_annotation/freezed_annotation.dart";

part "codex_rollout_dto.freezed.dart";
part "codex_rollout_dto.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class CodexRolloutLineDto with _$CodexRolloutLineDto {
  const factory CodexRolloutLineDto({
    required String? type,
    required CodexRolloutPayloadDto? payload,
  }) = _CodexRolloutLineDto;

  factory CodexRolloutLineDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutLineDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexRolloutPayloadDto with _$CodexRolloutPayloadDto {
  const factory CodexRolloutPayloadDto({
    required String? id,
    required String? cwd,
    required String? timestamp,
    @JsonKey(name: "model_provider") required String? modelProvider,
    @JsonKey(name: "cli_version") required String? cliVersion,
    required String? model,
    required CodexRolloutGitDto? git,
  }) = _CodexRolloutPayloadDto;

  factory CodexRolloutPayloadDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutPayloadDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexRolloutGitDto with _$CodexRolloutGitDto {
  const factory CodexRolloutGitDto({required String? branch}) = _CodexRolloutGitDto;

  factory CodexRolloutGitDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutGitDtoFromJson(json);
}
