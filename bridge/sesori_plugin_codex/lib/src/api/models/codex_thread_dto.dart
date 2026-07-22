import "package:freezed_annotation/freezed_annotation.dart";

part "codex_thread_dto.freezed.dart";
part "codex_thread_dto.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class CodexThreadEnvelopeDto with _$CodexThreadEnvelopeDto {
  const factory CodexThreadEnvelopeDto({
    required CodexThreadDto? thread,
    required String? model,
    required String? modelProvider,
    required String? cwd,
  }) = _CodexThreadEnvelopeDto;

  factory CodexThreadEnvelopeDto.fromJson(Map<String, dynamic> json) => _$CodexThreadEnvelopeDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexThreadDto with _$CodexThreadDto {
  const factory CodexThreadDto({
    required String? id,
    required String? name,
    required String? cwd,
    required num? createdAt,
    required num? updatedAt,
    required String? modelProvider,
  }) = _CodexThreadDto;

  factory CodexThreadDto.fromJson(Map<String, dynamic> json) => _$CodexThreadDtoFromJson(json);
}
