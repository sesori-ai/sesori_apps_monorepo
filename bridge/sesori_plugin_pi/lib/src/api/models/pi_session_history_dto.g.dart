// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pi_session_history_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PiSessionEntriesDto _$PiSessionEntriesDtoFromJson(Map json) =>
    _PiSessionEntriesDto(
      entries: (json['entries'] as List<dynamic>)
          .map(
            (e) =>
                PiSessionEntryDto.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      leafId: json['leafId'] as String?,
    );

_PiSessionFileHistoryDto _$PiSessionFileHistoryDtoFromJson(Map json) =>
    _PiSessionFileHistoryDto(
      header: PiSessionFileHeaderDto.fromJson(
        Map<String, dynamic>.from(json['header'] as Map),
      ),
      entries: (json['entries'] as List<dynamic>)
          .map(
            (e) => PiSessionFileEntryDto.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );

_PiSessionFileHeaderDto _$PiSessionFileHeaderDtoFromJson(Map json) =>
    _PiSessionFileHeaderDto(
      version: _intOrNull(json['version']),
      id: json['id'] as String,
    );

PiMessageEntryDto _$PiMessageEntryDtoFromJson(Map json) => PiMessageEntryDto(
  id: json['id'] as String,
  parentId: json['parentId'] as String?,
  timestamp: DateTime.parse(json['timestamp'] as String),
  message: PiAgentMessageDto.fromJson(
    Map<String, dynamic>.from(json['message'] as Map),
  ),
  $type: json['type'] as String?,
);

PiThinkingLevelChangeEntryDto _$PiThinkingLevelChangeEntryDtoFromJson(
  Map json,
) => PiThinkingLevelChangeEntryDto(
  id: json['id'] as String,
  parentId: json['parentId'] as String?,
  timestamp: DateTime.parse(json['timestamp'] as String),
  thinkingLevel: _thinkingLevelOrNull(json['thinkingLevel']),
  $type: json['type'] as String?,
);

PiModelChangeEntryDto _$PiModelChangeEntryDtoFromJson(Map json) =>
    PiModelChangeEntryDto(
      id: json['id'] as String,
      parentId: json['parentId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

PiCompactionEntryDto _$PiCompactionEntryDtoFromJson(Map json) =>
    PiCompactionEntryDto(
      id: json['id'] as String,
      parentId: json['parentId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

PiBranchSummaryEntryDto _$PiBranchSummaryEntryDtoFromJson(Map json) =>
    PiBranchSummaryEntryDto(
      id: json['id'] as String,
      parentId: json['parentId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

PiCustomEntryDto _$PiCustomEntryDtoFromJson(Map json) => PiCustomEntryDto(
  id: json['id'] as String,
  parentId: json['parentId'] as String?,
  timestamp: DateTime.parse(json['timestamp'] as String),
  $type: json['type'] as String?,
);

PiCustomMessageEntryDto _$PiCustomMessageEntryDtoFromJson(Map json) =>
    PiCustomMessageEntryDto(
      id: json['id'] as String,
      parentId: json['parentId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      content: _contentFromJson(json['content']),
      display: json['display'] as bool,
      $type: json['type'] as String?,
    );

PiLabelEntryDto _$PiLabelEntryDtoFromJson(Map json) => PiLabelEntryDto(
  id: json['id'] as String,
  parentId: json['parentId'] as String?,
  timestamp: DateTime.parse(json['timestamp'] as String),
  $type: json['type'] as String?,
);

PiSessionInfoEntryDto _$PiSessionInfoEntryDtoFromJson(Map json) =>
    PiSessionInfoEntryDto(
      id: json['id'] as String,
      parentId: json['parentId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

PiUnknownEntryDto _$PiUnknownEntryDtoFromJson(Map json) => PiUnknownEntryDto(
  id: json['id'] as String,
  parentId: json['parentId'] as String?,
  timestamp: DateTime.parse(json['timestamp'] as String),
  $type: json['type'] as String?,
);

PiSessionFileMessageEntryDto _$PiSessionFileMessageEntryDtoFromJson(Map json) =>
    PiSessionFileMessageEntryDto(
      id: json['id'] as String?,
      parentId: json['parentId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      message: PiSessionFileAgentMessageDto.fromJson(
        Map<String, dynamic>.from(json['message'] as Map),
      ),
      $type: json['type'] as String?,
    );

PiSessionFileThinkingLevelChangeEntryDto
_$PiSessionFileThinkingLevelChangeEntryDtoFromJson(Map json) =>
    PiSessionFileThinkingLevelChangeEntryDto(
      id: json['id'] as String?,
      parentId: json['parentId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      thinkingLevel: _thinkingLevelOrNull(json['thinkingLevel']),
      $type: json['type'] as String?,
    );

PiSessionFileModelChangeEntryDto _$PiSessionFileModelChangeEntryDtoFromJson(
  Map json,
) => PiSessionFileModelChangeEntryDto(
  id: json['id'] as String?,
  parentId: json['parentId'] as String?,
  timestamp: DateTime.parse(json['timestamp'] as String),
  $type: json['type'] as String?,
);

PiSessionFileCompactionEntryDto _$PiSessionFileCompactionEntryDtoFromJson(
  Map json,
) => PiSessionFileCompactionEntryDto(
  id: json['id'] as String?,
  parentId: json['parentId'] as String?,
  timestamp: DateTime.parse(json['timestamp'] as String),
  $type: json['type'] as String?,
);

PiSessionFileBranchSummaryEntryDto _$PiSessionFileBranchSummaryEntryDtoFromJson(
  Map json,
) => PiSessionFileBranchSummaryEntryDto(
  id: json['id'] as String?,
  parentId: json['parentId'] as String?,
  timestamp: DateTime.parse(json['timestamp'] as String),
  $type: json['type'] as String?,
);

PiSessionFileCustomEntryDto _$PiSessionFileCustomEntryDtoFromJson(Map json) =>
    PiSessionFileCustomEntryDto(
      id: json['id'] as String?,
      parentId: json['parentId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

PiSessionFileCustomMessageEntryDto _$PiSessionFileCustomMessageEntryDtoFromJson(
  Map json,
) => PiSessionFileCustomMessageEntryDto(
  id: json['id'] as String?,
  parentId: json['parentId'] as String?,
  timestamp: DateTime.parse(json['timestamp'] as String),
  content: _contentFromJson(json['content']),
  display: json['display'] as bool,
  $type: json['type'] as String?,
);

PiSessionFileLabelEntryDto _$PiSessionFileLabelEntryDtoFromJson(Map json) =>
    PiSessionFileLabelEntryDto(
      id: json['id'] as String?,
      parentId: json['parentId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

PiSessionFileSessionInfoEntryDto _$PiSessionFileSessionInfoEntryDtoFromJson(
  Map json,
) => PiSessionFileSessionInfoEntryDto(
  id: json['id'] as String?,
  parentId: json['parentId'] as String?,
  timestamp: DateTime.parse(json['timestamp'] as String),
  $type: json['type'] as String?,
);

PiSessionFileUnknownEntryDto _$PiSessionFileUnknownEntryDtoFromJson(Map json) =>
    PiSessionFileUnknownEntryDto(
      id: json['id'] as String?,
      parentId: json['parentId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      $type: json['type'] as String?,
    );

PiSessionFileUserMessageDto _$PiSessionFileUserMessageDtoFromJson(Map json) =>
    PiSessionFileUserMessageDto(
      content: _contentFromJson(json['content']),
      timestamp: _intOrNull(json['timestamp']),
      $type: json['role'] as String?,
    );

PiSessionFileAssistantMessageDto _$PiSessionFileAssistantMessageDtoFromJson(
  Map json,
) => PiSessionFileAssistantMessageDto(
  content: _contentFromJson(json['content']),
  provider: json['provider'] as String?,
  model: json['model'] as String?,
  stopReason: _stopReasonOrNull(json['stopReason']),
  errorMessage: json['errorMessage'] as String?,
  timestamp: _intOrNull(json['timestamp']),
  $type: json['role'] as String?,
);

PiSessionFileToolResultMessageDto _$PiSessionFileToolResultMessageDtoFromJson(
  Map json,
) => PiSessionFileToolResultMessageDto(
  toolCallId: json['toolCallId'] as String,
  toolName: json['toolName'] as String,
  content: _contentFromJson(json['content']),
  isError: json['isError'] as bool,
  timestamp: _intOrNull(json['timestamp']),
  $type: json['role'] as String?,
);

PiSessionFileBashExecutionMessageDto
_$PiSessionFileBashExecutionMessageDtoFromJson(Map json) =>
    PiSessionFileBashExecutionMessageDto(
      command: json['command'] as String,
      output: json['output'] as String,
      exitCode: _intOrNull(json['exitCode']),
      cancelled: json['cancelled'] as bool,
      truncated: json['truncated'] as bool,
      timestamp: _intOrNull(json['timestamp']),
      $type: json['role'] as String?,
    );

PiSessionFileCustomMessageDto _$PiSessionFileCustomMessageDtoFromJson(
  Map json,
) => PiSessionFileCustomMessageDto(
  content: _contentFromJson(json['content']),
  display: json['display'] as bool,
  timestamp: _intOrNull(json['timestamp']),
  $type: json['role'] as String?,
);

PiSessionFileHookMessageDto _$PiSessionFileHookMessageDtoFromJson(Map json) =>
    PiSessionFileHookMessageDto(
      content: _contentFromJson(json['content']),
      display: json['display'] as bool,
      timestamp: _intOrNull(json['timestamp']),
      $type: json['role'] as String?,
    );

PiSessionFileBranchSummaryMessageDto
_$PiSessionFileBranchSummaryMessageDtoFromJson(Map json) =>
    PiSessionFileBranchSummaryMessageDto(
      timestamp: _intOrNull(json['timestamp']),
      $type: json['role'] as String?,
    );

PiSessionFileCompactionSummaryMessageDto
_$PiSessionFileCompactionSummaryMessageDtoFromJson(Map json) =>
    PiSessionFileCompactionSummaryMessageDto(
      timestamp: _intOrNull(json['timestamp']),
      $type: json['role'] as String?,
    );

PiSessionFileUnknownMessageDto _$PiSessionFileUnknownMessageDtoFromJson(
  Map json,
) => PiSessionFileUnknownMessageDto(
  timestamp: _intOrNull(json['timestamp']),
  $type: json['role'] as String?,
);

PiUserMessageDto _$PiUserMessageDtoFromJson(Map json) => PiUserMessageDto(
  content: _contentFromJson(json['content']),
  timestamp: _intOrNull(json['timestamp']),
  $type: json['role'] as String?,
);

PiAssistantMessageDto _$PiAssistantMessageDtoFromJson(Map json) =>
    PiAssistantMessageDto(
      content: _contentFromJson(json['content']),
      provider: json['provider'] as String?,
      model: json['model'] as String?,
      stopReason: _stopReasonOrNull(json['stopReason']),
      errorMessage: json['errorMessage'] as String?,
      timestamp: _intOrNull(json['timestamp']),
      $type: json['role'] as String?,
    );

PiToolResultMessageDto _$PiToolResultMessageDtoFromJson(Map json) =>
    PiToolResultMessageDto(
      toolCallId: json['toolCallId'] as String,
      toolName: json['toolName'] as String,
      content: _contentFromJson(json['content']),
      isError: json['isError'] as bool,
      timestamp: _intOrNull(json['timestamp']),
      $type: json['role'] as String?,
    );

PiBashExecutionMessageDto _$PiBashExecutionMessageDtoFromJson(Map json) =>
    PiBashExecutionMessageDto(
      command: json['command'] as String,
      output: json['output'] as String,
      exitCode: _intOrNull(json['exitCode']),
      cancelled: json['cancelled'] as bool,
      truncated: json['truncated'] as bool,
      timestamp: _intOrNull(json['timestamp']),
      $type: json['role'] as String?,
    );

PiCustomMessageDto _$PiCustomMessageDtoFromJson(Map json) => PiCustomMessageDto(
  content: _contentFromJson(json['content']),
  display: json['display'] as bool,
  timestamp: _intOrNull(json['timestamp']),
  $type: json['role'] as String?,
);

PiBranchSummaryMessageDto _$PiBranchSummaryMessageDtoFromJson(Map json) =>
    PiBranchSummaryMessageDto(
      timestamp: _intOrNull(json['timestamp']),
      $type: json['role'] as String?,
    );

PiCompactionSummaryMessageDto _$PiCompactionSummaryMessageDtoFromJson(
  Map json,
) => PiCompactionSummaryMessageDto(
  timestamp: _intOrNull(json['timestamp']),
  $type: json['role'] as String?,
);

PiUnknownMessageDto _$PiUnknownMessageDtoFromJson(Map json) =>
    PiUnknownMessageDto(
      timestamp: _intOrNull(json['timestamp']),
      $type: json['role'] as String?,
    );

PiTextContentDto _$PiTextContentDtoFromJson(Map json) => PiTextContentDto(
  text: json['text'] as String,
  $type: json['type'] as String?,
);

PiImageContentDto _$PiImageContentDtoFromJson(Map json) => PiImageContentDto(
  data: json['data'] as String,
  mimeType: json['mimeType'] as String,
  $type: json['type'] as String?,
);

PiThinkingContentDto _$PiThinkingContentDtoFromJson(Map json) =>
    PiThinkingContentDto(
      thinking: json['thinking'] as String,
      redacted: json['redacted'] as bool?,
      $type: json['type'] as String?,
    );

PiToolCallContentDto _$PiToolCallContentDtoFromJson(Map json) =>
    PiToolCallContentDto(
      id: json['id'] as String,
      name: json['name'] as String,
      arguments: json['arguments'],
      $type: json['type'] as String?,
    );

PiUnknownContentDto _$PiUnknownContentDtoFromJson(Map json) =>
    PiUnknownContentDto($type: json['type'] as String?);
