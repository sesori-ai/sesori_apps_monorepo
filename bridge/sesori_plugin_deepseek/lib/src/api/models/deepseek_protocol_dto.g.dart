// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deepseek_protocol_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeepSeekInitializeMetadataDto _$DeepSeekInitializeMetadataDtoFromJson(
  Map json,
) => DeepSeekInitializeMetadataDto(
  extensionProtocolVersion: _integer(json['extensionProtocolVersion']),
  adapterVersion: json['adapterVersion'] as String,
  harnessVersion: json['harnessVersion'] as String,
  persistenceOwner: json['persistenceOwner'] as String,
);

Map<String, dynamic> _$DeepSeekInitializeMetadataDtoToJson(
  DeepSeekInitializeMetadataDto instance,
) => <String, dynamic>{
  'extensionProtocolVersion': instance.extensionProtocolVersion,
  'adapterVersion': instance.adapterVersion,
  'harnessVersion': instance.harnessVersion,
  'persistenceOwner': instance.persistenceOwner,
};

DeepSeekPromptMetadataDto _$DeepSeekPromptMetadataDtoFromJson(Map json) =>
    DeepSeekPromptMetadataDto(messageId: json['messageId'] as String?);

Map<String, dynamic> _$DeepSeekPromptMetadataDtoToJson(
  DeepSeekPromptMetadataDto instance,
) => <String, dynamic>{'messageId': ?instance.messageId};

DeepSeekCatalogRequestDto _$DeepSeekCatalogRequestDtoFromJson(Map json) =>
    DeepSeekCatalogRequestDto(cwd: json['cwd'] as String);

Map<String, dynamic> _$DeepSeekCatalogRequestDtoToJson(
  DeepSeekCatalogRequestDto instance,
) => <String, dynamic>{'cwd': instance.cwd};

DeepSeekCatalogResponseDto _$DeepSeekCatalogResponseDtoFromJson(Map json) {
  $checkKeys(json, requiredKeys: const ['defaultSelectionId']);
  return DeepSeekCatalogResponseDto(
    agent: DeepSeekAgentDto.fromJson(
      Map<String, dynamic>.from(json['agent'] as Map),
    ),
    providers: (json['providers'] as List<dynamic>)
        .map(
          (e) =>
              DeepSeekProviderDto.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    defaultSelectionId: json['defaultSelectionId'] as String?,
    commands: (json['commands'] as List<dynamic>)
        .map(
          (e) =>
              DeepSeekCommandDto.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    failures: (json['failures'] as List<dynamic>)
        .map(
          (e) => DeepSeekProviderFailureDto.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList(),
  );
}

Map<String, dynamic> _$DeepSeekCatalogResponseDtoToJson(
  DeepSeekCatalogResponseDto instance,
) => <String, dynamic>{
  'agent': instance.agent.toJson(),
  'providers': instance.providers.map((e) => e.toJson()).toList(),
  'defaultSelectionId': instance.defaultSelectionId,
  'commands': instance.commands.map((e) => e.toJson()).toList(),
  'failures': instance.failures.map((e) => e.toJson()).toList(),
};

DeepSeekAgentDto _$DeepSeekAgentDtoFromJson(Map json) => DeepSeekAgentDto(
  id: json['id'] as String,
  name: json['name'] as String,
  primary: json['primary'] as bool,
);

Map<String, dynamic> _$DeepSeekAgentDtoToJson(DeepSeekAgentDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'primary': instance.primary,
    };

DeepSeekProviderDto _$DeepSeekProviderDtoFromJson(Map json) =>
    DeepSeekProviderDto(
      id: json['id'] as String,
      name: json['name'] as String,
      models: (json['models'] as List<dynamic>)
          .map(
            (e) =>
                DeepSeekModelDto.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );

Map<String, dynamic> _$DeepSeekProviderDtoToJson(
  DeepSeekProviderDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'models': instance.models.map((e) => e.toJson()).toList(),
};

DeepSeekModelDto _$DeepSeekModelDtoFromJson(Map json) {
  $checkKeys(json, requiredKeys: const ['defaultReasoningEffort']);
  return DeepSeekModelDto(
    id: json['id'] as String,
    upstreamModelId: json['upstreamModelId'] as String,
    name: json['name'] as String,
    reasoningEfforts: (json['reasoningEfforts'] as List<dynamic>)
        .map((e) => e as String)
        .toList(),
    defaultReasoningEffort: json['defaultReasoningEffort'] as String?,
    supportsImages: json['supportsImages'] as bool,
  );
}

Map<String, dynamic> _$DeepSeekModelDtoToJson(DeepSeekModelDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'upstreamModelId': instance.upstreamModelId,
      'name': instance.name,
      'reasoningEfforts': instance.reasoningEfforts,
      'defaultReasoningEffort': instance.defaultReasoningEffort,
      'supportsImages': instance.supportsImages,
    };

DeepSeekCommandDto _$DeepSeekCommandDtoFromJson(Map json) => DeepSeekCommandDto(
  name: json['name'] as String,
  description: json['description'] as String,
);

Map<String, dynamic> _$DeepSeekCommandDtoToJson(DeepSeekCommandDto instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
    };

DeepSeekProviderFailureDto _$DeepSeekProviderFailureDtoFromJson(Map json) =>
    DeepSeekProviderFailureDto(
      providerId: json['providerId'] as String,
      category: json['category'] as String,
      message: json['message'] as String,
    );

Map<String, dynamic> _$DeepSeekProviderFailureDtoToJson(
  DeepSeekProviderFailureDto instance,
) => <String, dynamic>{
  'providerId': instance.providerId,
  'category': instance.category,
  'message': instance.message,
};

DeepSeekHistoryRequestDto _$DeepSeekHistoryRequestDtoFromJson(Map json) =>
    DeepSeekHistoryRequestDto(
      sessionId: json['sessionId'] as String,
      beforeSeq: _nullableInteger(json['beforeSeq']),
      maxMessages: json['maxMessages'] == null
          ? 50
          : _integer(json['maxMessages']),
    );

Map<String, dynamic> _$DeepSeekHistoryRequestDtoToJson(
  DeepSeekHistoryRequestDto instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'beforeSeq': ?instance.beforeSeq,
  'maxMessages': instance.maxMessages,
};

DeepSeekPaginatedHistoryResponseDto
_$DeepSeekPaginatedHistoryResponseDtoFromJson(Map json) =>
    DeepSeekPaginatedHistoryResponseDto(
      updates: (json['updates'] as List<dynamic>)
          .map(
            (e) => DeepSeekSessionUpdateEnvelopeDto.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      nextBeforeSeq: _integer(json['nextBeforeSeq']),
    );

Map<String, dynamic> _$DeepSeekPaginatedHistoryResponseDtoToJson(
  DeepSeekPaginatedHistoryResponseDto instance,
) => <String, dynamic>{
  'updates': instance.updates.map((e) => e.toJson()).toList(),
  'nextBeforeSeq': instance.nextBeforeSeq,
  'hasMore': instance.hasMore,
};

DeepSeekTerminalHistoryResponseDto _$DeepSeekTerminalHistoryResponseDtoFromJson(
  Map json,
) => DeepSeekTerminalHistoryResponseDto(
  updates: (json['updates'] as List<dynamic>)
      .map(
        (e) => DeepSeekSessionUpdateEnvelopeDto.fromJson(
          Map<String, dynamic>.from(e as Map),
        ),
      )
      .toList(),
);

Map<String, dynamic> _$DeepSeekTerminalHistoryResponseDtoToJson(
  DeepSeekTerminalHistoryResponseDto instance,
) => <String, dynamic>{
  'updates': instance.updates.map((e) => e.toJson()).toList(),
  'hasMore': instance.hasMore,
};

DeepSeekSessionUpdateEnvelopeDto _$DeepSeekSessionUpdateEnvelopeDtoFromJson(
  Map json,
) => DeepSeekSessionUpdateEnvelopeDto(
  metadata: (json['_meta'] as Map?)?.map((k, e) => MapEntry(k as String, e)),
  sessionId: json['sessionId'] as String,
  update: Map<String, dynamic>.from(json['update'] as Map),
);

Map<String, dynamic> _$DeepSeekSessionUpdateEnvelopeDtoToJson(
  DeepSeekSessionUpdateEnvelopeDto instance,
) => <String, dynamic>{
  '_meta': ?instance.metadata,
  'sessionId': instance.sessionId,
  'update': instance.update,
};

DeepSeekEnvelopeDeepSeekMetadataDto
_$DeepSeekEnvelopeDeepSeekMetadataDtoFromJson(Map json) =>
    DeepSeekEnvelopeDeepSeekMetadataDto(
      messageCreatedAt: _nullableInteger(json['messageCreatedAt']),
      subagent: json['subagent'] == null
          ? null
          : DeepSeekSubagentReplayDto.fromJson(
              Map<String, dynamic>.from(json['subagent'] as Map),
            ),
    );

Map<String, dynamic> _$DeepSeekEnvelopeDeepSeekMetadataDtoToJson(
  DeepSeekEnvelopeDeepSeekMetadataDto instance,
) => <String, dynamic>{
  'messageCreatedAt': ?instance.messageCreatedAt,
  'subagent': ?instance.subagent?.toJson(),
};

DeepSeekSubagentStartedDto _$DeepSeekSubagentStartedDtoFromJson(Map json) =>
    DeepSeekSubagentStartedDto(
      sessionId: json['sessionId'] as String,
      childSessionId: json['childSessionId'] as String,
      toolCallId: json['toolCallId'] as String,
      prompt: json['prompt'] as String,
      label: json['label'] as String,
      mode: $enumDecode(
        _$DeepSeekSubagentModeEnumMap,
        json['mode'],
        unknownValue: DeepSeekSubagentMode.unknown,
      ),
    );

Map<String, dynamic> _$DeepSeekSubagentStartedDtoToJson(
  DeepSeekSubagentStartedDto instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'childSessionId': instance.childSessionId,
  'toolCallId': instance.toolCallId,
  'prompt': instance.prompt,
  'label': instance.label,
  'mode': _$DeepSeekSubagentModeEnumMap[instance.mode]!,
  'kind': instance.kind,
};

const _$DeepSeekSubagentModeEnumMap = {
  DeepSeekSubagentMode.foreground: 'foreground',
  DeepSeekSubagentMode.background: 'background',
  DeepSeekSubagentMode.unknown: 'unknown',
};

DeepSeekSubagentEndedDto _$DeepSeekSubagentEndedDtoFromJson(Map json) =>
    DeepSeekSubagentEndedDto(
      sessionId: json['sessionId'] as String,
      childSessionId: json['childSessionId'] as String,
      stopReason: $enumDecode(
        _$DeepSeekSubagentStopReasonEnumMap,
        json['stopReason'],
        unknownValue: DeepSeekSubagentStopReason.unknown,
      ),
      summary: json['summary'] as String?,
    );

Map<String, dynamic> _$DeepSeekSubagentEndedDtoToJson(
  DeepSeekSubagentEndedDto instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'childSessionId': instance.childSessionId,
  'stopReason': _$DeepSeekSubagentStopReasonEnumMap[instance.stopReason]!,
  'summary': ?instance.summary,
  'kind': instance.kind,
};

const _$DeepSeekSubagentStopReasonEnumMap = {
  DeepSeekSubagentStopReason.completed: 'completed',
  DeepSeekSubagentStopReason.aborted: 'aborted',
  DeepSeekSubagentStopReason.error: 'error',
  DeepSeekSubagentStopReason.maxTokens: 'max-tokens',
  DeepSeekSubagentStopReason.refusal: 'refusal',
  DeepSeekSubagentStopReason.unknown: 'unknown',
};

DeepSeekSubagentReplayDto _$DeepSeekSubagentReplayDtoFromJson(Map json) =>
    DeepSeekSubagentReplayDto(
      prompt: json['prompt'] as String,
      label: json['label'] as String,
      mode: $enumDecode(
        _$DeepSeekSubagentModeEnumMap,
        json['mode'],
        unknownValue: DeepSeekSubagentMode.unknown,
      ),
      childSessionId: json['childSessionId'] as String?,
      ended: json['ended'] == null
          ? null
          : DeepSeekSubagentReplayEndedDto.fromJson(
              Map<String, dynamic>.from(json['ended'] as Map),
            ),
    );

Map<String, dynamic> _$DeepSeekSubagentReplayDtoToJson(
  DeepSeekSubagentReplayDto instance,
) => <String, dynamic>{
  'prompt': instance.prompt,
  'label': instance.label,
  'mode': _$DeepSeekSubagentModeEnumMap[instance.mode]!,
  'childSessionId': ?instance.childSessionId,
  'ended': ?instance.ended?.toJson(),
};

DeepSeekSubagentReplayEndedDto _$DeepSeekSubagentReplayEndedDtoFromJson(
  Map json,
) => DeepSeekSubagentReplayEndedDto(
  stopReason: $enumDecode(
    _$DeepSeekSubagentStopReasonEnumMap,
    json['stopReason'],
    unknownValue: DeepSeekSubagentStopReason.unknown,
  ),
  summary: json['summary'] as String?,
);

Map<String, dynamic> _$DeepSeekSubagentReplayEndedDtoToJson(
  DeepSeekSubagentReplayEndedDto instance,
) => <String, dynamic>{
  'stopReason': _$DeepSeekSubagentStopReasonEnumMap[instance.stopReason]!,
  'summary': ?instance.summary,
};

DeepSeekRenameRequestDto _$DeepSeekRenameRequestDtoFromJson(Map json) =>
    DeepSeekRenameRequestDto(
      sessionId: json['sessionId'] as String,
      title: json['title'] as String,
    );

Map<String, dynamic> _$DeepSeekRenameRequestDtoToJson(
  DeepSeekRenameRequestDto instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'title': instance.title,
};

DeepSeekRenameResponseDto _$DeepSeekRenameResponseDtoFromJson(Map json) =>
    DeepSeekRenameResponseDto(title: json['title'] as String);

Map<String, dynamic> _$DeepSeekRenameResponseDtoToJson(
  DeepSeekRenameResponseDto instance,
) => <String, dynamic>{'title': instance.title};

DeepSeekOrdinaryQuestionDto _$DeepSeekOrdinaryQuestionDtoFromJson(Map json) =>
    DeepSeekOrdinaryQuestionDto(
      id: json['id'] as String,
      text: json['text'] as String,
      header: json['header'] as String?,
      detail: json['detail'] as String?,
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      multiSelect: json['multiSelect'] as bool?,
    );

Map<String, dynamic> _$DeepSeekOrdinaryQuestionDtoToJson(
  DeepSeekOrdinaryQuestionDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'text': instance.text,
  'header': ?instance.header,
  'detail': ?instance.detail,
  'options': ?instance.options,
  'multiSelect': ?instance.multiSelect,
};

DeepSeekPlanReviewQuestionDto _$DeepSeekPlanReviewQuestionDtoFromJson(
  Map json,
) => DeepSeekPlanReviewQuestionDto(
  id: json['id'] as String,
  text: json['text'] as String,
  approveLabel: json['approveLabel'] as String,
  header: json['header'] as String?,
  detail: json['detail'] as String?,
  options: (json['options'] as List<dynamic>).map((e) => e as String).toList(),
  multiSelect: json['multiSelect'] as bool?,
);

Map<String, dynamic> _$DeepSeekPlanReviewQuestionDtoToJson(
  DeepSeekPlanReviewQuestionDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'text': instance.text,
  'approveLabel': instance.approveLabel,
  'header': ?instance.header,
  'detail': ?instance.detail,
  'options': instance.options,
  'multiSelect': ?instance.multiSelect,
  'intent': instance.intent,
};

DeepSeekAskUserQuestionRequestDto _$DeepSeekAskUserQuestionRequestDtoFromJson(
  Map json,
) => DeepSeekAskUserQuestionRequestDto(
  sessionId: json['sessionId'] as String,
  questions: (json['questions'] as List<dynamic>)
      .map(
        (e) =>
            DeepSeekQuestionDto.fromJson(Map<String, dynamic>.from(e as Map)),
      )
      .toList(),
);

Map<String, dynamic> _$DeepSeekAskUserQuestionRequestDtoToJson(
  DeepSeekAskUserQuestionRequestDto instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'questions': instance.questions.map((e) => e.toJson()).toList(),
};

DeepSeekQuestionAnswerDto _$DeepSeekQuestionAnswerDtoFromJson(Map json) =>
    DeepSeekQuestionAnswerDto._(
      questionId: json['questionId'] as String,
      selectedLabels: (json['selectedLabels'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      customAnswer: json['customAnswer'] as String?,
    );

Map<String, dynamic> _$DeepSeekQuestionAnswerDtoToJson(
  DeepSeekQuestionAnswerDto instance,
) => <String, dynamic>{
  'questionId': instance.questionId,
  'selectedLabels': instance.selectedLabels,
  'customAnswer': ?instance.customAnswer,
};

DeepSeekAskUserQuestionResponseDto _$DeepSeekAskUserQuestionResponseDtoFromJson(
  Map json,
) => DeepSeekAskUserQuestionResponseDto(
  answers: (json['answers'] as List<dynamic>)
      .map(
        (e) => DeepSeekQuestionAnswerDto.fromJson(
          Map<String, dynamic>.from(e as Map),
        ),
      )
      .toList(),
);

Map<String, dynamic> _$DeepSeekAskUserQuestionResponseDtoToJson(
  DeepSeekAskUserQuestionResponseDto instance,
) => <String, dynamic>{
  'answers': instance.answers.map((e) => e.toJson()).toList(),
};

DeepSeekRetryStatusDto _$DeepSeekRetryStatusDtoFromJson(Map json) =>
    DeepSeekRetryStatusDto(
      sessionId: json['sessionId'] as String,
      attempt: _integer(json['attempt']),
      limit: _nullableInteger(json['limit']),
    );

Map<String, dynamic> _$DeepSeekRetryStatusDtoToJson(
  DeepSeekRetryStatusDto instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'attempt': instance.attempt,
  'limit': ?instance.limit,
  'kind': instance.kind,
};

DeepSeekCompactionStartedStatusDto _$DeepSeekCompactionStartedStatusDtoFromJson(
  Map json,
) => DeepSeekCompactionStartedStatusDto(sessionId: json['sessionId'] as String);

Map<String, dynamic> _$DeepSeekCompactionStartedStatusDtoToJson(
  DeepSeekCompactionStartedStatusDto instance,
) => <String, dynamic>{'sessionId': instance.sessionId, 'kind': instance.kind};

DeepSeekCompactionCompletedStatusDto
_$DeepSeekCompactionCompletedStatusDtoFromJson(Map json) =>
    DeepSeekCompactionCompletedStatusDto(
      sessionId: json['sessionId'] as String,
    );

Map<String, dynamic> _$DeepSeekCompactionCompletedStatusDtoToJson(
  DeepSeekCompactionCompletedStatusDto instance,
) => <String, dynamic>{'sessionId': instance.sessionId, 'kind': instance.kind};

DeepSeekWarningStatusDto _$DeepSeekWarningStatusDtoFromJson(Map json) =>
    DeepSeekWarningStatusDto(
      sessionId: json['sessionId'] as String,
      message: json['message'] as String,
    );

Map<String, dynamic> _$DeepSeekWarningStatusDtoToJson(
  DeepSeekWarningStatusDto instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'message': instance.message,
  'kind': instance.kind,
};
