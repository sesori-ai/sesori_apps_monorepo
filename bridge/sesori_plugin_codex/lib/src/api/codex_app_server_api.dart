import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../codex_app_server_client.dart";
import "../models/codex_collaboration_mode.dart";
import "models/codex_account_dto.dart";
import "models/codex_collaboration_mode_dto.dart";
import "models/codex_model_dto.dart";
import "models/codex_skill_dto.dart";
import "models/codex_thread_dto.dart";
import "models/codex_turn_dto.dart";
import "models/codex_turn_input_dto.dart";

/// Layer-1 typed boundary for migrated Codex app-server operations.
class CodexAppServerApi({required final CodexAppServerTransport _client}) {
  Stream<CodexAccountLoginCompletedNotificationDto> get accountLoginCompletions => _client.notifications
      .where((notification) => notification.method == "account/login/completed")
      .map(
        (notification) => CodexAccountLoginCompletedNotificationDto.fromJson(
          notification.params,
        ),
      );

  Future<CodexDeviceLoginStartResponseDto> startDeviceLogin({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    const params = CodexDeviceLoginStartParamsDto(
      type: CodexAccountLoginType.chatgptDeviceCode,
    );
    final result = await _client.request(
      method: "account/login/start",
      params: params.toJson(),
      timeout: timeout,
    );
    return await _decodeAccountResponse(
      result: result,
      operation: "account/login/start",
      decode: CodexDeviceLoginStartResponseDto.fromJson,
    );
  }

  Future<CodexAccountLoginCancelResponseDto> cancelLogin({
    required String loginId,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final result = await _client.request(
      method: "account/login/cancel",
      params: CodexAccountLoginCancelParamsDto(loginId: loginId).toJson(),
      timeout: timeout,
    );
    return await _decodeAccountResponse(
      result: result,
      operation: "account/login/cancel",
      decode: CodexAccountLoginCancelResponseDto.fromJson,
    );
  }

  Future<CodexThreadEnvelopeDto> startThread({
    required String cwd,
    required String? model,
    required String? modelProvider,
  }) async {
    final params = <String, dynamic>{"cwd": cwd};
    if (model != null) {
      params["model"] = model;
      params["modelProvider"] = modelProvider;
    }
    final result = await _client.request(method: "thread/start", params: params);
    return _decodeResponse(result: result, operation: "thread/start");
  }

  Future<CodexThreadEnvelopeDto> resumeThread({
    required String threadId,
  }) async {
    final result = await _client.request(
      method: "thread/resume",
      params: {"threadId": threadId},
    );
    return _decodeResponse(result: result, operation: "thread/resume");
  }

  Future<CodexSkillsListResponseDto> listSkills({required String cwd}) async {
    final result = await _client.request(
      method: "skills/list",
      params: {
        "cwds": [cwd],
      },
    );
    if (result is! Map) {
      throw StateError(
        "expected a Codex skills response object, got ${result.runtimeType}",
      );
    }
    return CodexSkillsListResponseDto.fromJson(
      result.cast<String, dynamic>(),
    );
  }

  Future<CodexModelListResponseDto> listModels() async {
    final result = await _client.request(
      method: "model/list",
      params: const <String, dynamic>{},
    );
    if (result is! Map) {
      throw StateError(
        "expected a Codex model response object, got ${result.runtimeType}",
      );
    }
    return CodexModelListResponseDto.fromJson(
      result.cast<String, dynamic>(),
    );
  }

  Future<CodexTurnStartResponseDto> startTurn({
    required String threadId,
    required List<CodexTurnInputDto> input,
    required String? model,
    required String? effort,
    required CodexCollaborationMode? collaborationMode,
  }) async {
    final params = <String, dynamic>{
      "threadId": threadId,
      "input": input.map((item) => item.toJson()).toList(growable: false),
    };
    if (collaborationMode == null) {
      if (model != null) params["model"] = model;
      if (effort != null) params["effort"] = effort;
    } else {
      if (model == null || model.isEmpty) {
        throw StateError(
          "turn/start collaborationMode requires a resolved model",
        );
      }
      params["collaborationMode"] = CodexCollaborationModeDto(
        mode: collaborationMode.wireValue,
        settings: CodexCollaborationModeSettingsDto(
          model: model,
          reasoningEffort: effort,
          // Null asks Codex to supply its version-matched built-in mode prompt.
          developerInstructions: null,
        ),
      ).toJson();
    }
    final result = await _client.request(method: "turn/start", params: params);
    if (result is! Map) {
      throw StateError(
        "expected a Codex turn response object from turn/start, got "
        "${result.runtimeType}",
      );
    }
    return CodexTurnStartResponseDto.fromJson(result.cast<String, dynamic>());
  }

  Future<void> compactThread({required String threadId}) async {
    await _client.request(
      method: "thread/compact/start",
      params: {"threadId": threadId},
    );
  }

  CodexThreadEnvelopeDto? decodeThreadStartedParams({
    required Map<String, dynamic> params,
  }) {
    try {
      return CodexThreadEnvelopeDto.fromJson(params);
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex] failed to decode thread/started notification",
        error,
        stackTrace,
      );
      return null;
    }
  }

  CodexThreadEnvelopeDto _decodeResponse({
    required Object? result,
    required String operation,
  }) {
    if (result is! Map) {
      throw StateError(
        "expected a Codex thread response object from $operation, got "
        "${result.runtimeType}",
      );
    }
    return CodexThreadEnvelopeDto.fromJson(result.cast<String, dynamic>());
  }

  T _decodeAccountResponse<T>({
    required Object? result,
    required String operation,
    required T Function(Map<String, dynamic>) decode,
  }) {
    if (result is! Map) {
      throw StateError(
        "expected a Codex account response object from $operation, got "
        "${result.runtimeType}",
      );
    }
    return decode(result.cast<String, dynamic>());
  }
}
