import "package:freezed_annotation/freezed_annotation.dart";

part "hermes_replay_update_dto.freezed.dart";
part "hermes_replay_update_dto.g.dart";

/// The parts of a replayed `session/update` update that Hermes marks.
@freezed
sealed class HermesReplayUpdateDto with _$HermesReplayUpdateDto {
  const factory({
    required String? sessionUpdate,
    @JsonKey(name: "_meta") required HermesUpdateMetaDto? meta,
    required HermesTextContentDto? content,
  }) = _HermesReplayUpdateDto;

  factory fromJson(Map<String, dynamic> json) => _$HermesReplayUpdateDtoFromJson(json);
}

@freezed
sealed class HermesUpdateMetaDto with _$HermesUpdateMetaDto {
  const factory({required HermesMetaDto? hermes}) = _HermesUpdateMetaDto;

  factory fromJson(Map<String, dynamic> json) => _$HermesUpdateMetaDtoFromJson(json);
}

@freezed
sealed class HermesMetaDto with _$HermesMetaDto {
  const factory({required bool? compactionSummary}) = _HermesMetaDto;

  factory fromJson(Map<String, dynamic> json) => _$HermesMetaDtoFromJson(json);
}

@freezed
sealed class HermesTextContentDto with _$HermesTextContentDto {
  const factory({required String? type, required String? text}) = _HermesTextContentDto;

  factory fromJson(Map<String, dynamic> json) => _$HermesTextContentDtoFromJson(json);
}
