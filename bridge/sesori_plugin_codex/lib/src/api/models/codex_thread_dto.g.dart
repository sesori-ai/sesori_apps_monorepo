// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_thread_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexThreadEnvelopeDto _$CodexThreadEnvelopeDtoFromJson(Map json) =>
    _CodexThreadEnvelopeDto(
      thread: json['thread'] == null
          ? null
          : CodexThreadDto.fromJson(
              Map<String, dynamic>.from(json['thread'] as Map),
            ),
      model: json['model'] as String?,
      modelProvider: json['modelProvider'] as String?,
      cwd: json['cwd'] as String?,
    );

_CodexThreadDto _$CodexThreadDtoFromJson(Map json) => _CodexThreadDto(
  id: json['id'] as String?,
  name: json['name'] as String?,
  cwd: json['cwd'] as String?,
  createdAt: json['createdAt'] as num?,
  updatedAt: json['updatedAt'] as num?,
  modelProvider: json['modelProvider'] as String?,
  gitInfo: json['gitInfo'] == null
      ? null
      : CodexThreadGitInfoDto.fromJson(
          Map<String, dynamic>.from(json['gitInfo'] as Map),
        ),
);

_CodexThreadGitInfoDto _$CodexThreadGitInfoDtoFromJson(Map json) =>
    _CodexThreadGitInfoDto(branch: json['branch'] as String?);
