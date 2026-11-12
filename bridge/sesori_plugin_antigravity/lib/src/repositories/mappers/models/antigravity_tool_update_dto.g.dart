// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'antigravity_tool_update_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AntigravityToolUpdateDto _$AntigravityToolUpdateDtoFromJson(Map json) => _AntigravityToolUpdateDto(
  sessionUpdate: $enumDecode(
    _$AntigravityUpdateKindEnumMap,
    json['sessionUpdate'],
    unknownValue: AntigravityUpdateKind.unknown,
  ),
  title: json['title'] as String?,
  kind: json['kind'] as String?,
  rawInput: json['rawInput'],
  rawOutput: json['rawOutput'],
  metadata: json['_meta'],
);

const _$AntigravityUpdateKindEnumMap = {
  AntigravityUpdateKind.toolCall: 'tool_call',
  AntigravityUpdateKind.toolCallUpdate: 'tool_call_update',
  AntigravityUpdateKind.unknown: 'unknown',
};

_AntigravityNativeToolFieldsDto _$AntigravityNativeToolFieldsDtoFromJson(
  Map json,
) => _AntigravityNativeToolFieldsDto(
  command: json['command'] as String?,
  upperCommandLine: json['CommandLine'] as String?,
  snakeCommandLine: json['command_line'] as String?,
  commandLine: json['commandLine'] as String?,
  cwd: json['cwd'] as String?,
  upperCwd: json['Cwd'] as String?,
  workingDirectory: json['WorkingDirectory'] as String?,
  snakeWorkingDir: json['working_dir'] as String?,
  workingDir: json['workingDir'] as String?,
  stdout: json['stdout'] as String?,
  stderr: json['stderr'] as String?,
  combinedOutput: json['combinedOutput'] as String?,
  snakeCombinedOutput: json['combined_output'] as String?,
  formattedOutput: json['formatted_output'] as String?,
  exitCode: (json['exitCode'] as num?)?.toInt(),
  snakeExitCode: (json['exit_code'] as num?)?.toInt(),
  imagePath: json['imagePath'] as String?,
);

Map<String, dynamic> _$AntigravityNormalizedUpdateDtoToJson(
  _AntigravityNormalizedUpdateDto instance,
) => <String, dynamic>{
  'title': ?instance.title,
  'kind': ?_$AntigravityNormalizedToolKindEnumMap[instance.kind],
  'rawInput': ?instance.rawInput,
  'rawOutput': ?instance.rawOutput,
  'content': ?instance.content,
  '_meta': ?instance.metadata,
};

const _$AntigravityNormalizedToolKindEnumMap = {
  AntigravityNormalizedToolKind.execute: 'execute',
};

Map<String, dynamic> _$AntigravityNormalizedToolFieldsDtoToJson(
  _AntigravityNormalizedToolFieldsDto instance,
) => <String, dynamic>{
  'command': ?instance.command,
  'cwd': ?instance.cwd,
  'stdout': ?instance.stdout,
  'exitCode': ?instance.exitCode,
  'imagePath': ?instance.imagePath,
};

AntigravityWrappedToolContentDto _$AntigravityWrappedToolContentDtoFromJson(
  Map json,
) => AntigravityWrappedToolContentDto(
  content: AntigravityToolContentDto.fromJson(
    Map<String, dynamic>.from(json['content'] as Map),
  ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$AntigravityWrappedToolContentDtoToJson(
  AntigravityWrappedToolContentDto instance,
) => <String, dynamic>{
  'content': instance.content.toJson(),
  'type': instance.$type,
};

AntigravityTextToolContentDto _$AntigravityTextToolContentDtoFromJson(
  Map json,
) => AntigravityTextToolContentDto(
  text: json['text'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$AntigravityTextToolContentDtoToJson(
  AntigravityTextToolContentDto instance,
) => <String, dynamic>{'text': instance.text, 'type': instance.$type};

AntigravityUnknownToolContentDto _$AntigravityUnknownToolContentDtoFromJson(
  Map json,
) => AntigravityUnknownToolContentDto($type: json['type'] as String?);

Map<String, dynamic> _$AntigravityUnknownToolContentDtoToJson(
  AntigravityUnknownToolContentDto instance,
) => <String, dynamic>{'type': instance.$type};
