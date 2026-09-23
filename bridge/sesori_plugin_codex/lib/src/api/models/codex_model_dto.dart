import "package:freezed_annotation/freezed_annotation.dart";

part "codex_model_dto.freezed.dart";
part "codex_model_dto.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class CodexModelListResponseDto with _$CodexModelListResponseDto {
  const factory({
    @CodexModelListConverter() required List<CodexModelDto> data,
    required String? nextCursor,
  }) = _CodexModelListResponseDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexModelListResponseDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexModelDto with _$CodexModelDto {
  const factory({
    required String? id,
    required String? displayName,
    required bool? hidden,
    @CodexReasoningEffortListConverter() required List<CodexReasoningEffortOptionDto>? supportedReasoningEfforts,
    required String? defaultReasoningEffort,
    required bool? isDefault,
    required List<CodexModelServiceTierDto>? serviceTiers,
  }) = _CodexModelDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexModelDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexReasoningEffortOptionDto with _$CodexReasoningEffortOptionDto {
  const factory({
    required String? reasoningEffort,
    required String? description,
  }) = _CodexReasoningEffortOptionDto;

  factory fromJson(
    Map<String, dynamic> json,
  ) => _$CodexReasoningEffortOptionDtoFromJson(json);
}

/// One entry of a Codex model's `serviceTiers`, e.g. the "priority" (Fast)
/// tier: `{id: "priority", name: "Fast", description: "2x speed, increased
/// usage"}`.
@Freezed(fromJson: true, toJson: false)
sealed class CodexModelServiceTierDto with _$CodexModelServiceTierDto {
  const factory({
    required String? id,
    required String? name,
    required String? description,
  }) = _CodexModelServiceTierDto;

  factory fromJson(
    Map<String, dynamic> json,
  ) => _$CodexModelServiceTierDtoFromJson(json);
}

class const CodexModelListConverter() implements JsonConverter<List<CodexModelDto>, Object?> {
  @override
  List<CodexModelDto> fromJson(Object? json) {
    if (json is! List) {
      throw const FormatException("expected Codex model data to be a list");
    }
    return [
      for (final entry in json)
        if (entry is Map) CodexModelDto.fromJson(Map<String, dynamic>.from(entry)),
    ];
  }

  @override
  Object? toJson(List<CodexModelDto> object) {
    throw UnsupportedError("Codex model DTOs are decode-only");
  }
}

class const CodexReasoningEffortListConverter()
    implements JsonConverter<List<CodexReasoningEffortOptionDto>?, Object?> {
  @override
  List<CodexReasoningEffortOptionDto>? fromJson(Object? json) {
    if (json == null) return null;
    if (json is! List) {
      throw const FormatException(
        "expected Codex reasoning efforts to be a list",
      );
    }
    return [
      for (final entry in json)
        if (entry is String)
          CodexReasoningEffortOptionDto(
            reasoningEffort: entry,
            description: null,
          )
        else if (entry is Map)
          CodexReasoningEffortOptionDto.fromJson(
            Map<String, dynamic>.from(entry),
          ),
    ];
  }

  @override
  Object? toJson(List<CodexReasoningEffortOptionDto>? object) {
    throw UnsupportedError("Codex reasoning-effort DTOs are decode-only");
  }
}
