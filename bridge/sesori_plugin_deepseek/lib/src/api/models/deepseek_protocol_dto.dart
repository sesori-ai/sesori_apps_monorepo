import "package:json_annotation/json_annotation.dart";

part "deepseek_protocol_dto.g.dart";

// ignore: no_slop_linter/prefer_specific_type, json_serializable converter input is heterogeneous
int _integer(Object? value) {
  if (value is! int) throw const FormatException("Expected integer");
  return value;
}

// ignore: no_slop_linter/prefer_specific_type, json_serializable converter input is heterogeneous
int? _nullableInteger(Object? value) => value == null ? null : _integer(value);

enum DeepSeekSubagentMode() {
  foreground,
  background,
  unknown,
}

enum DeepSeekSubagentStopReason() {
  completed,
  aborted,
  error,
  @JsonValue("max-tokens")
  maxTokens,
  refusal,
  unknown,
}

@JsonSerializable()
class const DeepSeekInitializeMetadataDto({
  @JsonKey(fromJson: _integer) required final int extensionProtocolVersion,
  required final String adapterVersion,
  required final String harnessVersion,
  required final String persistenceOwner,
}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekInitializeMetadataDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekInitializeMetadataDtoToJson(this);
}

@JsonSerializable()
class const DeepSeekPromptMetadataDto({required final String? messageId}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekPromptMetadataDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekPromptMetadataDtoToJson(this);
}

@JsonSerializable()
class const DeepSeekCatalogRequestDto({required final String cwd}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekCatalogRequestDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekCatalogRequestDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class const DeepSeekCatalogResponseDto({
  required final DeepSeekAgentDto agent,
  required final List<DeepSeekProviderDto> providers,
  @JsonKey(required: true, includeIfNull: true) required final String? defaultSelectionId,
  required final List<DeepSeekCommandDto> commands,
  required final List<DeepSeekProviderFailureDto> failures,
}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekCatalogResponseDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekCatalogResponseDtoToJson(this);
}

@JsonSerializable()
class const DeepSeekAgentDto({required final String id, required final String name, required final bool primary}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekAgentDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekAgentDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class const DeepSeekProviderDto({
  required final String id,
  required final String name,
  required final List<DeepSeekModelDto> models,
}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekProviderDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekProviderDtoToJson(this);
}

@JsonSerializable()
class const DeepSeekModelDto({
  required final String id,
  required final String upstreamModelId,
  required final String name,
  required final List<String> reasoningEfforts,
  @JsonKey(required: true, includeIfNull: true) required final String? defaultReasoningEffort,
  required final bool supportsImages,
}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekModelDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekModelDtoToJson(this);
}

@JsonSerializable()
class const DeepSeekCommandDto({required final String name, required final String description}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekCommandDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekCommandDtoToJson(this);
}

@JsonSerializable()
class const DeepSeekProviderFailureDto({
  required final String providerId,
  required final String category,
  required final String message,
}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekProviderFailureDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekProviderFailureDtoToJson(this);
}

@JsonSerializable()
class const DeepSeekHistoryRequestDto({
  required final String sessionId,
  @JsonKey(fromJson: _nullableInteger) required final int? beforeSeq,
  @JsonKey(fromJson: _integer) final int maxMessages = 50,
}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekHistoryRequestDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekHistoryRequestDtoToJson(this);
}

sealed class const DeepSeekHistoryResponseDto() {
  factory fromJson(Map<String, dynamic> json) {
    final hasMore = json["hasMore"];
    if (hasMore == true && json.containsKey("nextBeforeSeq")) {
      return DeepSeekPaginatedHistoryResponseDto.fromJson(json);
    }
    if (hasMore == false && !json.containsKey("nextBeforeSeq")) {
      return DeepSeekTerminalHistoryResponseDto.fromJson(json);
    }
    throw const FormatException("Invalid DeepSeek history response");
  }
  List<DeepSeekSessionUpdateEnvelopeDto> get updates;
  Map<String, dynamic> toJson();
}

@JsonSerializable(explicitToJson: true)
class const DeepSeekPaginatedHistoryResponseDto({
  @override required final List<DeepSeekSessionUpdateEnvelopeDto> updates,
  @JsonKey(fromJson: _integer) required final int nextBeforeSeq,
}) extends DeepSeekHistoryResponseDto {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekPaginatedHistoryResponseDtoFromJson(json);
  @JsonKey(includeFromJson: false, includeToJson: true)
  bool get hasMore => true;
  @override
  Map<String, dynamic> toJson() => _$DeepSeekPaginatedHistoryResponseDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class const DeepSeekTerminalHistoryResponseDto({
  @override required final List<DeepSeekSessionUpdateEnvelopeDto> updates,
}) extends DeepSeekHistoryResponseDto {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekTerminalHistoryResponseDtoFromJson(json);
  @JsonKey(includeFromJson: false, includeToJson: true)
  bool get hasMore => false;
  @override
  Map<String, dynamic> toJson() => _$DeepSeekTerminalHistoryResponseDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class const DeepSeekSessionUpdateEnvelopeDto({
  @JsonKey(name: "_meta") required final DeepSeekEnvelopeMetadataDto? metadata,
  required final String sessionId,
  // ignore: no_slop_linter/prefer_specific_type, standard ACP update values are heterogeneous
  required final Map<String, dynamic> update,
}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekSessionUpdateEnvelopeDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekSessionUpdateEnvelopeDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class const DeepSeekEnvelopeMetadataDto({
  @JsonKey(name: "sesori.ai/deepseek") required final DeepSeekEnvelopeDeepSeekMetadataDto? deepSeek,
}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekEnvelopeMetadataDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekEnvelopeMetadataDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class const DeepSeekEnvelopeDeepSeekMetadataDto({
  @JsonKey(fromJson: _nullableInteger) required final int? messageCreatedAt,
  required final DeepSeekSubagentReplayDto? subagent,
}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekEnvelopeDeepSeekMetadataDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekEnvelopeDeepSeekMetadataDtoToJson(this);
}

sealed class const DeepSeekSubagentNotificationDto() {
  factory fromJson(Map<String, dynamic> json) => switch (json["kind"]) {
    "started" => DeepSeekSubagentStartedDto.fromJson(json),
    "ended" => DeepSeekSubagentEndedDto.fromJson(json),
    _ => throw const FormatException("Invalid DeepSeek sub-agent notification"),
  };
  String get sessionId;
  String get childSessionId;
  Map<String, dynamic> toJson();
}

@JsonSerializable()
class const DeepSeekSubagentStartedDto({
  @override required final String sessionId,
  @override required final String childSessionId,
  required final String toolCallId,
  required final String prompt,
  required final String label,
  @JsonKey(unknownEnumValue: DeepSeekSubagentMode.unknown) required final DeepSeekSubagentMode mode,
}) extends DeepSeekSubagentNotificationDto {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekSubagentStartedDtoFromJson(json);
  @JsonKey(includeFromJson: false, includeToJson: true)
  String get kind => "started";
  @override
  Map<String, dynamic> toJson() => _$DeepSeekSubagentStartedDtoToJson(this);
}

@JsonSerializable()
class const DeepSeekSubagentEndedDto({
  @override required final String sessionId,
  @override required final String childSessionId,
  @JsonKey(unknownEnumValue: DeepSeekSubagentStopReason.unknown) required final DeepSeekSubagentStopReason stopReason,
  required final String? summary,
}) extends DeepSeekSubagentNotificationDto {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekSubagentEndedDtoFromJson(json);
  @JsonKey(includeFromJson: false, includeToJson: true)
  String get kind => "ended";
  @override
  Map<String, dynamic> toJson() => _$DeepSeekSubagentEndedDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class const DeepSeekSubagentReplayDto({
  required final String prompt,
  required final String label,
  @JsonKey(unknownEnumValue: DeepSeekSubagentMode.unknown) required final DeepSeekSubagentMode mode,
  required final String? childSessionId,
  required final DeepSeekSubagentReplayEndedDto? ended,
}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekSubagentReplayDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekSubagentReplayDtoToJson(this);
}

@JsonSerializable()
class const DeepSeekSubagentReplayEndedDto({
  @JsonKey(unknownEnumValue: DeepSeekSubagentStopReason.unknown) required final DeepSeekSubagentStopReason stopReason,
  required final String? summary,
}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekSubagentReplayEndedDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekSubagentReplayEndedDtoToJson(this);
}

@JsonSerializable()
class const DeepSeekRenameRequestDto({required final String sessionId, required final String title}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekRenameRequestDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekRenameRequestDtoToJson(this);
}

@JsonSerializable()
class const DeepSeekRenameResponseDto({required final String title}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekRenameResponseDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekRenameResponseDtoToJson(this);
}

sealed class const DeepSeekQuestionDto() {
  factory fromJson(Map<String, dynamic> json) {
    if (json["intent"] == "plan_review" && json.containsKey("approveLabel")) {
      return DeepSeekPlanReviewQuestionDto.fromJson(json);
    }
    if (!json.containsKey("intent") && !json.containsKey("approveLabel")) {
      return DeepSeekOrdinaryQuestionDto.fromJson(json);
    }
    throw const FormatException("Invalid DeepSeek question");
  }
  String get id;
  String get text;
  String? get header;
  String? get detail;
  List<String>? get options;
  bool? get multiSelect;
  Map<String, dynamic> toJson();
}

@JsonSerializable()
class const DeepSeekOrdinaryQuestionDto({
  @override required final String id,
  @override required final String text,
  @override required final String? header,
  @override required final String? detail,
  @override required final List<String>? options,
  @override required final bool? multiSelect,
}) extends DeepSeekQuestionDto {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekOrdinaryQuestionDtoFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$DeepSeekOrdinaryQuestionDtoToJson(this);
}

@JsonSerializable()
class const DeepSeekPlanReviewQuestionDto({
  @override required final String id,
  @override required final String text,
  required final String approveLabel,
  @override required final String? header,
  @override required final String? detail,
  @override required final List<String> options,
  @override required final bool? multiSelect,
}) extends DeepSeekQuestionDto {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekPlanReviewQuestionDtoFromJson(json);
  @JsonKey(includeFromJson: false, includeToJson: true)
  String get intent => "plan_review";
  @override
  Map<String, dynamic> toJson() => _$DeepSeekPlanReviewQuestionDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class const DeepSeekAskUserQuestionRequestDto({
  required final String sessionId,
  required final List<DeepSeekQuestionDto> questions,
}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekAskUserQuestionRequestDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekAskUserQuestionRequestDtoToJson(this);
}

@JsonSerializable(constructor: "_")
class const DeepSeekQuestionAnswerDto._({
  required final String questionId,
  required final List<String> selectedLabels,
  required final String? customAnswer,
}) {
  factory custom({required String questionId, required String customAnswer}) =>
      DeepSeekQuestionAnswerDto._(questionId: questionId, selectedLabels: const [], customAnswer: customAnswer);
  factory selected({
    required String questionId,
    required List<String> selectedLabels,
    required String? customAnswer,
  }) {
    if (selectedLabels.isEmpty) throw const FormatException("Selected labels must not be empty");
    return DeepSeekQuestionAnswerDto._(
      questionId: questionId,
      selectedLabels: selectedLabels,
      customAnswer: customAnswer,
    );
  }
  factory fromJson(Map<String, dynamic> json) {
    final labels = json["selectedLabels"];
    if (labels is! List || labels.isEmpty && !json.containsKey("customAnswer")) {
      throw const FormatException("Invalid DeepSeek question answer");
    }
    return _$DeepSeekQuestionAnswerDtoFromJson(json);
  }
  Map<String, dynamic> toJson() => _$DeepSeekQuestionAnswerDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class const DeepSeekAskUserQuestionResponseDto({required final List<DeepSeekQuestionAnswerDto> answers}) {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekAskUserQuestionResponseDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DeepSeekAskUserQuestionResponseDtoToJson(this);
}

sealed class const DeepSeekSessionStatusNotificationDto() {
  factory fromJson(Map<String, dynamic> json) => switch (json["kind"]) {
    "retry" => DeepSeekRetryStatusDto.fromJson(json),
    "compaction_started" => DeepSeekCompactionStartedStatusDto.fromJson(json),
    "compaction_completed" => DeepSeekCompactionCompletedStatusDto.fromJson(json),
    "warning" => DeepSeekWarningStatusDto.fromJson(json),
    _ => throw const FormatException("Invalid DeepSeek session status"),
  };
  String get sessionId;
  Map<String, dynamic> toJson();
}

@JsonSerializable()
class const DeepSeekRetryStatusDto({
  @override required final String sessionId,
  @JsonKey(fromJson: _integer) required final int attempt,
  @JsonKey(fromJson: _nullableInteger) required final int? limit,
}) extends DeepSeekSessionStatusNotificationDto {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekRetryStatusDtoFromJson(json);
  @JsonKey(includeFromJson: false, includeToJson: true)
  String get kind => "retry";
  @override
  Map<String, dynamic> toJson() => _$DeepSeekRetryStatusDtoToJson(this);
}

@JsonSerializable()
class const DeepSeekCompactionStartedStatusDto({@override required final String sessionId})
    extends DeepSeekSessionStatusNotificationDto {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekCompactionStartedStatusDtoFromJson(json);
  @JsonKey(includeFromJson: false, includeToJson: true)
  String get kind => "compaction_started";
  @override
  Map<String, dynamic> toJson() => _$DeepSeekCompactionStartedStatusDtoToJson(this);
}

@JsonSerializable()
class const DeepSeekCompactionCompletedStatusDto({@override required final String sessionId})
    extends DeepSeekSessionStatusNotificationDto {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekCompactionCompletedStatusDtoFromJson(json);
  @JsonKey(includeFromJson: false, includeToJson: true)
  String get kind => "compaction_completed";
  @override
  Map<String, dynamic> toJson() => _$DeepSeekCompactionCompletedStatusDtoToJson(this);
}

@JsonSerializable()
class const DeepSeekWarningStatusDto({@override required final String sessionId, required final String message})
    extends DeepSeekSessionStatusNotificationDto {
  factory fromJson(Map<String, dynamic> json) => _$DeepSeekWarningStatusDtoFromJson(json);
  @JsonKey(includeFromJson: false, includeToJson: true)
  String get kind => "warning";
  @override
  Map<String, dynamic> toJson() => _$DeepSeekWarningStatusDtoToJson(this);
}
