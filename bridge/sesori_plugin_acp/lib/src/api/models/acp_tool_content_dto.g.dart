// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'acp_tool_content_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AcpStandardToolContentDto _$AcpStandardToolContentDtoFromJson(Map json) => AcpStandardToolContentDto(
  content: AcpContentBlockDto.fromJson(
    Map<String, dynamic>.from(json['content'] as Map),
  ),
  $type: json['type'] as String?,
);

AcpDiffToolContentDto _$AcpDiffToolContentDtoFromJson(Map json) => AcpDiffToolContentDto(
  path: json['path'] as String,
  oldText: json['oldText'] as String?,
  newText: json['newText'] as String,
  $type: json['type'] as String?,
);

AcpTerminalToolContentDto _$AcpTerminalToolContentDtoFromJson(Map json) => AcpTerminalToolContentDto(
  terminalId: json['terminalId'] as String,
  $type: json['type'] as String?,
);

AcpUnknownToolContentDto _$AcpUnknownToolContentDtoFromJson(Map json) =>
    AcpUnknownToolContentDto($type: json['type'] as String?);
