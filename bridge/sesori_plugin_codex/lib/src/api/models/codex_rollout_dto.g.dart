// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_rollout_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexRolloutLineDto _$CodexRolloutLineDtoFromJson(Map json) =>
    _CodexRolloutLineDto(
      type: json['type'] as String?,
      payload: json['payload'] == null
          ? null
          : CodexRolloutPayloadDto.fromJson(
              Map<String, dynamic>.from(json['payload'] as Map),
            ),
    );

_CodexRolloutPayloadDto _$CodexRolloutPayloadDtoFromJson(Map json) =>
    _CodexRolloutPayloadDto(
      id: json['id'] as String?,
      cwd: json['cwd'] as String?,
      timestamp: json['timestamp'] as String?,
      modelProvider: json['model_provider'] as String?,
      cliVersion: json['cli_version'] as String?,
      model: json['model'] as String?,
      git: json['git'] == null
          ? null
          : CodexRolloutGitDto.fromJson(
              Map<String, dynamic>.from(json['git'] as Map),
            ),
    );

_CodexRolloutGitDto _$CodexRolloutGitDtoFromJson(Map json) =>
    _CodexRolloutGitDto(branch: json['branch'] as String?);
