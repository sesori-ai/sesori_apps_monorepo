import "package:freezed_annotation/freezed_annotation.dart";

part "hermes_session_update_dto.freezed.dart";
part "hermes_session_update_dto.g.dart";

/// The parts of a `session/update` update that Hermes marks with its `_meta`.
@freezed
sealed class HermesSessionUpdateDto with _$HermesSessionUpdateDto {
  const factory({
    required String? sessionUpdate,
    @JsonKey(name: "_meta") required HermesUpdateMetaDto? meta,
    required HermesTextContentDto? content,
  }) = _HermesSessionUpdateDto;

  factory fromJson(Map<String, dynamic> json) => _$HermesSessionUpdateDtoFromJson(json);
}

@freezed
sealed class HermesUpdateMetaDto with _$HermesUpdateMetaDto {
  const factory({required HermesMetaDto? hermes}) = _HermesUpdateMetaDto;

  factory fromJson(Map<String, dynamic> json) => _$HermesUpdateMetaDtoFromJson(json);
}

@freezed
sealed class HermesMetaDto with _$HermesMetaDto {
  const factory({
    required bool? compactionSummary,
    required HermesSessionProvenanceDto? sessionProvenance,
  }) = _HermesMetaDto;

  factory fromJson(Map<String, dynamic> json) => _$HermesMetaDtoFromJson(json);
}

@freezed
sealed class HermesTextContentDto with _$HermesTextContentDto {
  const factory({required String? type, required String? text}) = _HermesTextContentDto;

  factory fromJson(Map<String, dynamic> json) => _$HermesTextContentDtoFromJson(json);
}

/// Hermes's `sessionProvenance` on a `session_info_update`
/// (`acp_adapter/provenance.py`).
@freezed
sealed class HermesSessionProvenanceDto with _$HermesSessionProvenanceDto {
  const factory({required String? reason}) = _HermesSessionProvenanceDto;

  factory fromJson(Map<String, dynamic> json) => _$HermesSessionProvenanceDtoFromJson(json);
}
