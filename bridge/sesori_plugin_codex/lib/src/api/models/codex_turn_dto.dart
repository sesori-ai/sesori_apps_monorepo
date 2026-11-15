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

/// One page of `thread/turns/list`.
@Freezed(fromJson: true, toJson: false)
sealed class CodexThreadTurnsPageDto with _$CodexThreadTurnsPageDto {
  const factory({
    required List<CodexTurnDto>? data,
  }) = _CodexThreadTurnsPageDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexThreadTurnsPageDtoFromJson(json);
}

/// A Codex app-server turn's lifecycle status.
enum CodexTurnStatus() {
  completed,
  interrupted,
  failed,
  inProgress,
  unknown,
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexTurnDto with _$CodexTurnDto {
  const factory({
    required String? id,
    @JsonKey(unknownEnumValue: CodexTurnStatus.unknown) required CodexTurnStatus? status,
  }) = _CodexTurnDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexTurnDtoFromJson(json);
}
