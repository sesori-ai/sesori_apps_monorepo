import "package:freezed_annotation/freezed_annotation.dart";

part "pi_catalog_dto.freezed.dart";
part "pi_catalog_dto.g.dart";

enum PiCatalogCommandSource() { extension, promptTemplate, prompt, skill, unknown }

@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class PiCatalogModelDto with _$PiCatalogModelDto {
  const factory({
    @JsonKey(fromJson: _stringOrNull) required String? provider,
    @JsonKey(fromJson: _stringOrNull) required String? id,
    @JsonKey(fromJson: _stringOrNull) required String? name,
    @JsonKey(fromJson: _boolOrFalse) required bool reasoning,
    @JsonKey(fromJson: _stringList) required List<String> input,
  }) = _PiCatalogModelDto;

  factory fromJson(Map<String, dynamic> json) => _$PiCatalogModelDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class PiStateCatalogDto with _$PiStateCatalogDto {
  const factory({
    @JsonKey(fromJson: _modelOrNull) required PiCatalogModelDto? model,
  }) = _PiStateCatalogDto;

  factory fromJson(Map<String, dynamic> json) => _$PiStateCatalogDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class PiAvailableModelsDto with _$PiAvailableModelsDto {
  const factory({
    @JsonKey(fromJson: _modelList) required List<PiCatalogModelDto> models,
  }) = _PiAvailableModelsDto;

  factory fromJson(Map<String, dynamic> json) => _$PiAvailableModelsDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class PiThinkingLevelsDto with _$PiThinkingLevelsDto {
  const factory({
    @JsonKey(fromJson: _stringList) required List<String> levels,
  }) = _PiThinkingLevelsDto;

  factory fromJson(Map<String, dynamic> json) => _$PiThinkingLevelsDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class PiCatalogCommandDto with _$PiCatalogCommandDto {
  const factory({
    @JsonKey(fromJson: _stringOrNull) required String? name,
    @JsonKey(fromJson: _stringOrNull) required String? description,
    @JsonKey(fromJson: _commandSource) required PiCatalogCommandSource source,
  }) = _PiCatalogCommandDto;

  factory fromJson(Map<String, dynamic> json) => _$PiCatalogCommandDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class PiCommandsDto with _$PiCommandsDto {
  const factory({
    @JsonKey(fromJson: _commandList) required List<PiCatalogCommandDto> commands,
  }) = _PiCommandsDto;

  factory fromJson(Map<String, dynamic> json) => _$PiCommandsDtoFromJson(json);
}

String? _stringOrNull(Object? value) => value is String ? value : null;

bool _boolOrFalse(Object? value) => value is bool && value;

List<String> _stringList(Object? value) => value is List ? value.whereType<String>().toList() : const [];

PiCatalogModelDto? _modelOrNull(Object? value) =>
    value is Map ? PiCatalogModelDto.fromJson(value.cast<String, dynamic>()) : null;

List<PiCatalogModelDto> _modelList(Object? value) => value is List
    ? [
        for (final model in value.whereType<Map<dynamic, dynamic>>())
          PiCatalogModelDto.fromJson(model.cast<String, dynamic>()),
      ]
    : const [];

PiCatalogCommandSource _commandSource(Object? value) => switch (value) {
  "extension" => PiCatalogCommandSource.extension,
  "prompt-template" => PiCatalogCommandSource.promptTemplate,
  "prompt" => PiCatalogCommandSource.prompt,
  "skill" => PiCatalogCommandSource.skill,
  _ => PiCatalogCommandSource.unknown,
};

List<PiCatalogCommandDto> _commandList(Object? value) => value is List
    ? [
        for (final command in value.whereType<Map<dynamic, dynamic>>())
          PiCatalogCommandDto.fromJson(command.cast<String, dynamic>()),
      ]
    : const [];
