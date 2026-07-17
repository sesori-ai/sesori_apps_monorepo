import "package:freezed_annotation/freezed_annotation.dart";

import "../codex_app_server_client.dart";

part "codex_app_server_api.freezed.dart";
part "codex_app_server_api.g.dart";

/// Typed app-server request surface for the Codex tool.
class CodexAppServerApi {
  CodexAppServerApi({required CodexAppServerClient client}) : _client = client;

  final CodexAppServerClient _client;

  Stream<CodexNotificationDto> get notifications => _client.notifications.map(parseNotification);

  Future<CodexThreadResponseDto> startThread({
    required CodexThreadStartArguments arguments,
  }) async {
    final params = <String, dynamic>{"cwd": arguments.directory};
    final model = arguments.model;
    if (model != null) {
      params["model"] = model.modelId;
      params["modelProvider"] = model.providerId;
    }
    final result = await _client.request(method: "thread/start", params: params);
    return CodexThreadResponseDto.fromJson(
      _requireObjectResult(method: "thread/start", result: result),
    );
  }

  Future<CodexThreadResponseDto> resumeThread({
    required String threadId,
  }) async {
    final result = await _client.request(
      method: "thread/resume",
      params: {"threadId": threadId},
    );
    return CodexThreadResponseDto.fromJson(
      _requireObjectResult(method: "thread/resume", result: result),
    );
  }

  Future<CodexTurnResponseDto> startTurn({
    required CodexTurnStartArguments arguments,
  }) async {
    final params = <String, dynamic>{
      "threadId": arguments.threadId,
      "input": arguments.input.map(_turnInputJson).toList(growable: false),
    };
    final model = arguments.model;
    if (model != null) params["model"] = model.modelId;
    final effort = arguments.effort;
    if (effort != null && effort.isNotEmpty) params["effort"] = effort;
    final result = await _client.request(method: "turn/start", params: params);
    return CodexTurnResponseDto.fromJson(
      _requireObjectResult(method: "turn/start", result: result),
    );
  }

  Future<CodexTurnInterruptResponseDto> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {
    await _client.request(
      method: "turn/interrupt",
      params: {"threadId": threadId, "turnId": turnId},
    );
    return const CodexTurnInterruptResponseDto();
  }

  Future<void> setThreadName({
    required String threadId,
    required String name,
  }) async {
    await _client.request(
      method: "thread/name/set",
      params: {"threadId": threadId, "name": name},
    );
  }

  Future<void> archiveThread({required String threadId}) async {
    await _client.request(
      method: "thread/archive",
      params: {"threadId": threadId},
    );
  }

  Future<CodexModelListResponseDto> listModels({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final result = await _client.request(
      method: "model/list",
      params: const <String, dynamic>{},
      timeout: timeout,
    );
    return CodexModelListResponseDto.fromJson(
      _requireObjectResult(method: "model/list", result: result),
    );
  }

  static CodexNotificationDto parseNotification(
    CodexServerNotification notification,
  ) {
    return CodexNotificationDto(
      method: switch (notification.method) {
        "thread/started" => CodexNotificationMethod.threadStarted,
        "thread/name/updated" => CodexNotificationMethod.threadNameUpdated,
        "thread/status/changed" => CodexNotificationMethod.threadStatusChanged,
        "thread/closed" => CodexNotificationMethod.threadClosed,
        "turn/started" => CodexNotificationMethod.turnStarted,
        "turn/completed" => CodexNotificationMethod.turnCompleted,
        "item/started" => CodexNotificationMethod.itemStarted,
        "item/completed" => CodexNotificationMethod.itemCompleted,
        "item/agentMessage/delta" => CodexNotificationMethod.agentMessageDelta,
        "item/reasoning/textDelta" || "item/reasoning/summaryTextDelta" => CodexNotificationMethod.reasoningDelta,
        "item/removed" => CodexNotificationMethod.itemRemoved,
        "item/part/removed" => CodexNotificationMethod.itemPartRemoved,
        "error" => CodexNotificationMethod.error,
        "turn/diff/updated" => CodexNotificationMethod.turnDiffUpdated,
        "skills/changed" || "mcpServer/startupStatus/updated" => CodexNotificationMethod.projectChanged,
        _ => CodexNotificationMethod.other,
      },
      params: CodexNotificationParamsDto.fromJson(notification.params),
    );
  }

  static Map<String, dynamic> _turnInputJson(CodexApiTurnInput input) {
    return switch (input) {
      CodexApiTurnTextInput(:final text) => {
        "type": "text",
        "text": text,
        "text_elements": const <Object?>[],
      },
      CodexApiTurnLocalImageInput(:final path) => {
        "type": "localImage",
        "path": path,
      },
      CodexApiTurnImageUrlInput(:final url) => {
        "type": "image",
        "url": url,
      },
    };
  }

  static Map<String, dynamic> _requireObjectResult({
    required String method,
    required Object? result,
  }) {
    if (result is Map) return result.cast<String, dynamic>();
    throw CodexRpcException(
      method: method,
      code: -32603,
      message: "expected object result, got ${result.runtimeType}",
    );
  }
}

class CodexApiModelSelection {
  const CodexApiModelSelection({
    required this.providerId,
    required this.modelId,
  });

  final String providerId;
  final String modelId;
}

class CodexThreadStartArguments {
  const CodexThreadStartArguments({
    required this.directory,
    required this.model,
  });

  final String directory;
  final CodexApiModelSelection? model;
}

class CodexTurnStartArguments {
  const CodexTurnStartArguments({
    required this.threadId,
    required this.input,
    required this.model,
    required this.effort,
  });

  final String threadId;
  final List<CodexApiTurnInput> input;
  final CodexApiModelSelection? model;
  final String? effort;
}

sealed class CodexApiTurnInput {
  const CodexApiTurnInput();
}

final class CodexApiTurnTextInput extends CodexApiTurnInput {
  const CodexApiTurnTextInput({required this.text});

  final String text;
}

final class CodexApiTurnLocalImageInput extends CodexApiTurnInput {
  const CodexApiTurnLocalImageInput({required this.path});

  final String path;
}

final class CodexApiTurnImageUrlInput extends CodexApiTurnInput {
  const CodexApiTurnImageUrlInput({required this.url});

  final String url;
}

enum CodexNotificationMethod {
  threadStarted,
  threadNameUpdated,
  threadStatusChanged,
  threadClosed,
  turnStarted,
  turnCompleted,
  itemStarted,
  itemCompleted,
  agentMessageDelta,
  reasoningDelta,
  itemRemoved,
  itemPartRemoved,
  error,
  turnDiffUpdated,
  projectChanged,
  other,
}

class CodexNotificationDto {
  const CodexNotificationDto({
    required this.method,
    required this.params,
  });

  final CodexNotificationMethod method;
  final CodexNotificationParamsDto params;
}

@freezed
sealed class CodexNotificationParamsDto with _$CodexNotificationParamsDto {
  const factory CodexNotificationParamsDto({
    required String? threadId,
    required String? turnId,
    required CodexThreadDto? thread,
    required CodexTurnDto? turn,
    required String? threadName,
    required CodexThreadStatusDto? status,
    required CodexItemDto? item,
    required String? itemId,
    required String? partId,
    required String? delta,
    required String? model,
    required String? modelProvider,
    required String? cwd,
  }) = _CodexNotificationParamsDto;

  factory CodexNotificationParamsDto.fromJson(Map<String, dynamic> json) => _$CodexNotificationParamsDtoFromJson(json);
}

@freezed
sealed class CodexThreadStatusDto with _$CodexThreadStatusDto {
  const factory CodexThreadStatusDto({
    required String? type,
    required CodexThreadStatusDto? status,
  }) = _CodexThreadStatusDto;

  factory CodexThreadStatusDto.fromJson(Map<String, dynamic> json) => _$CodexThreadStatusDtoFromJson(json);
}

@freezed
sealed class CodexItemDto with _$CodexItemDto {
  const factory CodexItemDto({
    required String? type,
    required String? id,
    @CodexTextValuesMapper() required List<String> content,
    @CodexTextValuesMapper() required List<String> summary,
    required String? text,
    required String? command,
    required String? status,
    required String? aggregatedOutput,
    @Default(<CodexFileChangeDto>[]) List<CodexFileChangeDto> changes,
    required String? tool,
    required String? server,
    required CodexMcpResultDto? result,
    required CodexErrorDto? error,
    required String? query,
  }) = _CodexItemDto;

  factory CodexItemDto.fromJson(Map<String, dynamic> json) => _$CodexItemDtoFromJson(json);
}

@freezed
sealed class CodexFileChangeDto with _$CodexFileChangeDto {
  const factory CodexFileChangeDto({
    required String? path,
    required String? diff,
  }) = _CodexFileChangeDto;

  factory CodexFileChangeDto.fromJson(Map<String, dynamic> json) => _$CodexFileChangeDtoFromJson(json);
}

@freezed
sealed class CodexMcpResultDto with _$CodexMcpResultDto {
  const factory CodexMcpResultDto({
    @CodexTextValuesMapper() required List<String> content,
  }) = _CodexMcpResultDto;

  factory CodexMcpResultDto.fromJson(Map<String, dynamic> json) => _$CodexMcpResultDtoFromJson(json);
}

@freezed
sealed class CodexErrorDto with _$CodexErrorDto {
  const factory CodexErrorDto({required String? message}) = _CodexErrorDto;

  factory CodexErrorDto.fromJson(Map<String, dynamic> json) => _$CodexErrorDtoFromJson(json);
}

@freezed
sealed class CodexThreadResponseDto with _$CodexThreadResponseDto {
  const factory CodexThreadResponseDto({
    required CodexThreadDto? thread,
    required String? model,
    required String? modelProvider,
    required String? cwd,
  }) = _CodexThreadResponseDto;

  factory CodexThreadResponseDto.fromJson(Map<String, dynamic> json) => _$CodexThreadResponseDtoFromJson(json);
}

@freezed
sealed class CodexThreadDto with _$CodexThreadDto {
  const factory CodexThreadDto({
    required String? id,
    required String? cwd,
    required String? name,
    required String? modelProvider,
    required num? createdAt,
    required num? updatedAt,
  }) = _CodexThreadDto;

  factory CodexThreadDto.fromJson(Map<String, dynamic> json) => _$CodexThreadDtoFromJson(json);
}

@freezed
sealed class CodexTurnResponseDto with _$CodexTurnResponseDto {
  const factory CodexTurnResponseDto({
    required CodexTurnDto? turn,
    required String? turnId,
    required String? id,
  }) = _CodexTurnResponseDto;

  factory CodexTurnResponseDto.fromJson(Map<String, dynamic> json) => _$CodexTurnResponseDtoFromJson(json);
}

@freezed
sealed class CodexTurnDto with _$CodexTurnDto {
  const factory CodexTurnDto({required String? id}) = _CodexTurnDto;

  factory CodexTurnDto.fromJson(Map<String, dynamic> json) => _$CodexTurnDtoFromJson(json);
}

@freezed
sealed class CodexTurnInterruptResponseDto with _$CodexTurnInterruptResponseDto {
  const factory CodexTurnInterruptResponseDto() = _CodexTurnInterruptResponseDto;

  factory CodexTurnInterruptResponseDto.fromJson(Map<String, dynamic> json) =>
      _$CodexTurnInterruptResponseDtoFromJson(json);
}

@freezed
sealed class CodexModelListResponseDto with _$CodexModelListResponseDto {
  const factory CodexModelListResponseDto({
    @Default(<CodexModelDto>[]) List<CodexModelDto> data,
  }) = _CodexModelListResponseDto;

  factory CodexModelListResponseDto.fromJson(Map<String, dynamic> json) => _$CodexModelListResponseDtoFromJson(json);
}

@freezed
sealed class CodexModelDto with _$CodexModelDto {
  const factory CodexModelDto({
    required String? id,
    required String? displayName,
    required bool? hidden,
    required bool? isDefault,
    required String? defaultReasoningEffort,
    @CodexReasoningEffortsMapper() required List<CodexReasoningEffortDto> supportedReasoningEfforts,
  }) = _CodexModelDto;

  factory CodexModelDto.fromJson(Map<String, dynamic> json) => _$CodexModelDtoFromJson(json);
}

@freezed
sealed class CodexReasoningEffortDto with _$CodexReasoningEffortDto {
  const factory CodexReasoningEffortDto({
    required String? reasoningEffort,
    required String? description,
  }) = _CodexReasoningEffortDto;

  factory CodexReasoningEffortDto.fromJson(Map<String, dynamic> json) => _$CodexReasoningEffortDtoFromJson(json);
}

@freezed
sealed class CodexTextValueDto with _$CodexTextValueDto {
  const factory CodexTextValueDto({
    required String? type,
    required String? text,
  }) = _CodexTextValueDto;

  factory CodexTextValueDto.fromJson(Map<String, dynamic> json) => _$CodexTextValueDtoFromJson(json);
}

class CodexTextValuesMapper implements JsonConverter<List<String>, Object?> {
  const CodexTextValuesMapper();

  @override
  List<String> fromJson(Object? json) {
    if (json is! List) return const [];
    final values = <String>[];
    for (final entry in json) {
      if (entry is String) {
        values.add(entry);
        continue;
      }
      if (entry is! Map) continue;
      final value = CodexTextValueDto.fromJson(
        entry.cast<String, dynamic>(),
      );
      final type = value.type;
      if (type != null && type != "text" && type != "input_text" && type != "output_text") {
        continue;
      }
      final text = value.text;
      if (text != null) values.add(text);
    }
    return values;
  }

  @override
  Object? toJson(List<String> value) => [
    for (final text in value) {"type": "text", "text": text},
  ];
}

class CodexReasoningEffortsMapper implements JsonConverter<List<CodexReasoningEffortDto>, Object?> {
  const CodexReasoningEffortsMapper();

  @override
  List<CodexReasoningEffortDto> fromJson(Object? json) {
    if (json is! List) return const [];
    return [
      for (final entry in json)
        if (entry is String)
          CodexReasoningEffortDto(
            reasoningEffort: entry,
            description: null,
          )
        else if (entry is Map)
          CodexReasoningEffortDto.fromJson(entry.cast<String, dynamic>()),
    ];
  }

  @override
  Object? toJson(List<CodexReasoningEffortDto> value) => value.map((effort) => effort.toJson()).toList(growable: false);
}
