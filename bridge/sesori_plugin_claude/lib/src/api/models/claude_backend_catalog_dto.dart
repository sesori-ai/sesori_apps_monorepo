import "package:freezed_annotation/freezed_annotation.dart";

part "claude_backend_catalog_dto.freezed.dart";
part "claude_backend_catalog_dto.g.dart";

/// The catalog-bearing subset of Claude's `initialize` response.
///
/// Account and agent fields are deliberately absent: account data contains PII,
/// and Claude's first-party agents are outside this plugin's product contract.
@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeBackendCatalogDto with _$ClaudeBackendCatalogDto {
  const factory ClaudeBackendCatalogDto({
    @JsonKey(fromJson: _commandsOrEmpty) required List<ClaudeCommandDto> commands,
    @JsonKey(fromJson: _modelsOrEmpty) required List<ClaudeModelDto> models,
  }) = _ClaudeBackendCatalogDto;

  factory ClaudeBackendCatalogDto.fromJson(Map<String, dynamic> json) => _$ClaudeBackendCatalogDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeCommandDto with _$ClaudeCommandDto {
  const factory ClaudeCommandDto({
    @JsonKey(fromJson: _stringOrNull) required String? name,
    @JsonKey(fromJson: _stringOrNull) required String? description,
    @JsonKey(fromJson: _stringOrNull) required String? argumentHint,
  }) = _ClaudeCommandDto;

  factory ClaudeCommandDto.fromJson(Map<String, dynamic> json) => _$ClaudeCommandDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeModelDto with _$ClaudeModelDto {
  const factory ClaudeModelDto({
    @JsonKey(fromJson: _stringOrNull) required String? value,
    @JsonKey(fromJson: _stringOrNull) required String? resolvedModel,
    @JsonKey(fromJson: _stringOrNull) required String? displayName,
    @JsonKey(fromJson: _boolOrNull) required bool? supportsEffort,
    @JsonKey(fromJson: _stringsOrEmpty) required List<String> supportedEffortLevels,
  }) = _ClaudeModelDto;

  factory ClaudeModelDto.fromJson(Map<String, dynamic> json) => _$ClaudeModelDtoFromJson(json);
}

List<ClaudeCommandDto> _commandsOrEmpty(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map) ClaudeCommandDto.fromJson(item.cast<String, dynamic>()),
      ]
    : const [];

List<ClaudeModelDto> _modelsOrEmpty(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map) ClaudeModelDto.fromJson(item.cast<String, dynamic>()),
      ]
    : const [];

List<String> _stringsOrEmpty(Object? value) => value is List ? value.whereType<String>().toList() : const [];

String? _stringOrNull(Object? value) => value is String ? value : null;

bool? _boolOrNull(Object? value) => value is bool ? value : null;
