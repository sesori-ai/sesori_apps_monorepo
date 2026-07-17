// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_app_server_api.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexNotificationParamsDto _$CodexNotificationParamsDtoFromJson(
  Map json,
) => _CodexNotificationParamsDto(
  threadId: json['threadId'] as String?,
  turnId: json['turnId'] as String?,
  thread: json['thread'] == null
      ? null
      : CodexThreadDto.fromJson(
          Map<String, dynamic>.from(json['thread'] as Map),
        ),
  turn: json['turn'] == null
      ? null
      : CodexTurnDto.fromJson(Map<String, dynamic>.from(json['turn'] as Map)),
  threadName: json['threadName'] as String?,
  status: json['status'] == null
      ? null
      : CodexThreadStatusDto.fromJson(
          Map<String, dynamic>.from(json['status'] as Map),
        ),
  item: json['item'] == null
      ? null
      : CodexItemDto.fromJson(Map<String, dynamic>.from(json['item'] as Map)),
  itemId: json['itemId'] as String?,
  partId: json['partId'] as String?,
  delta: json['delta'] as String?,
  model: json['model'] as String?,
  modelProvider: json['modelProvider'] as String?,
  cwd: json['cwd'] as String?,
);

Map<String, dynamic> _$CodexNotificationParamsDtoToJson(
  _CodexNotificationParamsDto instance,
) => <String, dynamic>{
  'threadId': instance.threadId,
  'turnId': instance.turnId,
  'thread': instance.thread?.toJson(),
  'turn': instance.turn?.toJson(),
  'threadName': instance.threadName,
  'status': instance.status?.toJson(),
  'item': instance.item?.toJson(),
  'itemId': instance.itemId,
  'partId': instance.partId,
  'delta': instance.delta,
  'model': instance.model,
  'modelProvider': instance.modelProvider,
  'cwd': instance.cwd,
};

_CodexThreadStatusDto _$CodexThreadStatusDtoFromJson(Map json) =>
    _CodexThreadStatusDto(
      type: $enumDecodeNullable(
        _$CodexThreadStatusTypeDtoEnumMap,
        json['type'],
        unknownValue: CodexThreadStatusTypeDto.unknown,
      ),
      status: json['status'] == null
          ? null
          : CodexThreadStatusDto.fromJson(
              Map<String, dynamic>.from(json['status'] as Map),
            ),
    );

Map<String, dynamic> _$CodexThreadStatusDtoToJson(
  _CodexThreadStatusDto instance,
) => <String, dynamic>{
  'type': _$CodexThreadStatusTypeDtoEnumMap[instance.type],
  'status': instance.status?.toJson(),
};

const _$CodexThreadStatusTypeDtoEnumMap = {
  CodexThreadStatusTypeDto.active: 'active',
  CodexThreadStatusTypeDto.idle: 'idle',
  CodexThreadStatusTypeDto.notLoaded: 'notLoaded',
  CodexThreadStatusTypeDto.systemError: 'systemError',
  CodexThreadStatusTypeDto.unknown: 'unknown',
};

_CodexItemDto _$CodexItemDtoFromJson(Map json) => _CodexItemDto(
  type: json['type'] as String?,
  id: json['id'] as String?,
  content: const CodexTextValuesMapper().fromJson(json['content']),
  summary: const CodexTextValuesMapper().fromJson(json['summary']),
  text: json['text'] as String?,
  command: json['command'] as String?,
  status: json['status'] as String?,
  aggregatedOutput: json['aggregatedOutput'] as String?,
  changes:
      (json['changes'] as List<dynamic>?)
          ?.map(
            (e) => CodexFileChangeDto.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList() ??
      const <CodexFileChangeDto>[],
  tool: json['tool'] as String?,
  server: json['server'] as String?,
  result: json['result'] == null
      ? null
      : CodexMcpResultDto.fromJson(
          Map<String, dynamic>.from(json['result'] as Map),
        ),
  error: json['error'] == null
      ? null
      : CodexErrorDto.fromJson(Map<String, dynamic>.from(json['error'] as Map)),
  query: json['query'] as String?,
);

Map<String, dynamic> _$CodexItemDtoToJson(_CodexItemDto instance) =>
    <String, dynamic>{
      'type': instance.type,
      'id': instance.id,
      'content': const CodexTextValuesMapper().toJson(instance.content),
      'summary': const CodexTextValuesMapper().toJson(instance.summary),
      'text': instance.text,
      'command': instance.command,
      'status': instance.status,
      'aggregatedOutput': instance.aggregatedOutput,
      'changes': instance.changes.map((e) => e.toJson()).toList(),
      'tool': instance.tool,
      'server': instance.server,
      'result': instance.result?.toJson(),
      'error': instance.error?.toJson(),
      'query': instance.query,
    };

_CodexFileChangeDto _$CodexFileChangeDtoFromJson(Map json) =>
    _CodexFileChangeDto(
      path: json['path'] as String?,
      diff: json['diff'] as String?,
    );

Map<String, dynamic> _$CodexFileChangeDtoToJson(_CodexFileChangeDto instance) =>
    <String, dynamic>{'path': instance.path, 'diff': instance.diff};

_CodexMcpResultDto _$CodexMcpResultDtoFromJson(Map json) => _CodexMcpResultDto(
  content: const CodexTextValuesMapper().fromJson(json['content']),
);

Map<String, dynamic> _$CodexMcpResultDtoToJson(_CodexMcpResultDto instance) =>
    <String, dynamic>{
      'content': const CodexTextValuesMapper().toJson(instance.content),
    };

_CodexErrorDto _$CodexErrorDtoFromJson(Map json) =>
    _CodexErrorDto(message: json['message'] as String?);

Map<String, dynamic> _$CodexErrorDtoToJson(_CodexErrorDto instance) =>
    <String, dynamic>{'message': instance.message};

_CodexThreadResponseDto _$CodexThreadResponseDtoFromJson(Map json) =>
    _CodexThreadResponseDto(
      thread: json['thread'] == null
          ? null
          : CodexThreadDto.fromJson(
              Map<String, dynamic>.from(json['thread'] as Map),
            ),
      model: json['model'] as String?,
      modelProvider: json['modelProvider'] as String?,
      cwd: json['cwd'] as String?,
    );

Map<String, dynamic> _$CodexThreadResponseDtoToJson(
  _CodexThreadResponseDto instance,
) => <String, dynamic>{
  'thread': instance.thread?.toJson(),
  'model': instance.model,
  'modelProvider': instance.modelProvider,
  'cwd': instance.cwd,
};

_CodexThreadDto _$CodexThreadDtoFromJson(Map json) => _CodexThreadDto(
  id: json['id'] as String?,
  cwd: json['cwd'] as String?,
  name: json['name'] as String?,
  modelProvider: json['modelProvider'] as String?,
  createdAt: json['createdAt'] as num?,
  updatedAt: json['updatedAt'] as num?,
);

Map<String, dynamic> _$CodexThreadDtoToJson(_CodexThreadDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'cwd': instance.cwd,
      'name': instance.name,
      'modelProvider': instance.modelProvider,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };

_CodexTurnResponseDto _$CodexTurnResponseDtoFromJson(Map json) =>
    _CodexTurnResponseDto(
      turn: json['turn'] == null
          ? null
          : CodexTurnDto.fromJson(
              Map<String, dynamic>.from(json['turn'] as Map),
            ),
      turnId: json['turnId'] as String?,
      id: json['id'] as String?,
    );

Map<String, dynamic> _$CodexTurnResponseDtoToJson(
  _CodexTurnResponseDto instance,
) => <String, dynamic>{
  'turn': instance.turn?.toJson(),
  'turnId': instance.turnId,
  'id': instance.id,
};

_CodexTurnDto _$CodexTurnDtoFromJson(Map json) =>
    _CodexTurnDto(id: json['id'] as String?);

Map<String, dynamic> _$CodexTurnDtoToJson(_CodexTurnDto instance) =>
    <String, dynamic>{'id': instance.id};

_CodexTurnInterruptResponseDto _$CodexTurnInterruptResponseDtoFromJson(
  Map json,
) => _CodexTurnInterruptResponseDto();

Map<String, dynamic> _$CodexTurnInterruptResponseDtoToJson(
  _CodexTurnInterruptResponseDto instance,
) => <String, dynamic>{};

_CodexModelListResponseDto _$CodexModelListResponseDtoFromJson(Map json) =>
    _CodexModelListResponseDto(
      data:
          (json['data'] as List<dynamic>?)
              ?.map(
                (e) =>
                    CodexModelDto.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          const <CodexModelDto>[],
    );

Map<String, dynamic> _$CodexModelListResponseDtoToJson(
  _CodexModelListResponseDto instance,
) => <String, dynamic>{'data': instance.data.map((e) => e.toJson()).toList()};

_CodexModelDto _$CodexModelDtoFromJson(Map json) => _CodexModelDto(
  id: json['id'] as String?,
  displayName: json['displayName'] as String?,
  hidden: json['hidden'] as bool?,
  isDefault: json['isDefault'] as bool?,
  defaultReasoningEffort: json['defaultReasoningEffort'] as String?,
  supportedReasoningEfforts: const CodexReasoningEffortsMapper().fromJson(
    json['supportedReasoningEfforts'],
  ),
);

Map<String, dynamic> _$CodexModelDtoToJson(_CodexModelDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'hidden': instance.hidden,
      'isDefault': instance.isDefault,
      'defaultReasoningEffort': instance.defaultReasoningEffort,
      'supportedReasoningEfforts': const CodexReasoningEffortsMapper().toJson(
        instance.supportedReasoningEfforts,
      ),
    };

_CodexReasoningEffortDto _$CodexReasoningEffortDtoFromJson(Map json) =>
    _CodexReasoningEffortDto(
      reasoningEffort: json['reasoningEffort'] as String?,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$CodexReasoningEffortDtoToJson(
  _CodexReasoningEffortDto instance,
) => <String, dynamic>{
  'reasoningEffort': instance.reasoningEffort,
  'description': instance.description,
};

_CodexTextValueDto _$CodexTextValueDtoFromJson(Map json) => _CodexTextValueDto(
  type: json['type'] as String?,
  text: json['text'] as String?,
);

Map<String, dynamic> _$CodexTextValueDtoToJson(_CodexTextValueDto instance) =>
    <String, dynamic>{'type': instance.type, 'text': instance.text};
