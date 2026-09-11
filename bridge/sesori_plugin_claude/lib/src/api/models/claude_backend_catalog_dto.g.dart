// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claude_backend_catalog_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClaudeBackendCatalogDto _$ClaudeBackendCatalogDtoFromJson(Map json) =>
    _ClaudeBackendCatalogDto(
      commands: _commandsOrEmpty(json['commands']),
      models: _modelsOrEmpty(json['models']),
    );

_ClaudeCommandDto _$ClaudeCommandDtoFromJson(Map json) => _ClaudeCommandDto(
  name: _stringOrNull(json['name']),
  description: _stringOrNull(json['description']),
  argumentHint: _stringOrNull(json['argumentHint']),
);

_ClaudeModelDto _$ClaudeModelDtoFromJson(Map json) => _ClaudeModelDto(
  value: _stringOrNull(json['value']),
  resolvedModel: _stringOrNull(json['resolvedModel']),
  displayName: _stringOrNull(json['displayName']),
  supportsEffort: _boolOrNull(json['supportsEffort']),
  supportedEffortLevels: _stringsOrEmpty(json['supportedEffortLevels']),
);
