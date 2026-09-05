// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pi_catalog_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PiCatalogModelDto _$PiCatalogModelDtoFromJson(Map json) => _PiCatalogModelDto(
  provider: _stringOrNull(json['provider']),
  id: _stringOrNull(json['id']),
  name: _stringOrNull(json['name']),
  reasoning: _boolOrFalse(json['reasoning']),
  input: _stringList(json['input']),
);

_PiStateCatalogDto _$PiStateCatalogDtoFromJson(Map json) =>
    _PiStateCatalogDto(model: _modelOrNull(json['model']));

_PiAvailableModelsDto _$PiAvailableModelsDtoFromJson(Map json) =>
    _PiAvailableModelsDto(models: _modelList(json['models']));

_PiThinkingLevelsDto _$PiThinkingLevelsDtoFromJson(Map json) =>
    _PiThinkingLevelsDto(levels: _stringList(json['levels']));

_PiCatalogCommandDto _$PiCatalogCommandDtoFromJson(Map json) =>
    _PiCatalogCommandDto(
      name: _stringOrNull(json['name']),
      description: _stringOrNull(json['description']),
      source: _commandSource(json['source']),
      sourcePath: _commandSourcePath(json['sourceInfo']),
    );

_PiCommandsDto _$PiCommandsDtoFromJson(Map json) =>
    _PiCommandsDto(commands: _commandList(json['commands']));
