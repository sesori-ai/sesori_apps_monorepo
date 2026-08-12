import "package:freezed_annotation/freezed_annotation.dart";

part "codex_turn_dto.freezed.dart";
part "codex_turn_dto.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class CodexTurnStartResponseDto with _$CodexTurnStartResponseDto {
  const factory({
    required CodexTurnDto? turn,
  }) = _CodexTurnStartResponseDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexTurnStartResponseDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexTurnDto with _$CodexTurnDto {
  const factory({
    required String? id,
  }) = _CodexTurnDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexTurnDtoFromJson(json);
}
