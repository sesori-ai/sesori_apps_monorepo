import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../codex_app_server_client.dart";
import "models/codex_skill_dto.dart";
import "models/codex_thread_dto.dart";
import "models/codex_turn_input_dto.dart";

/// Layer-1 typed boundary for migrated Codex app-server operations.
class CodexAppServerApi {
  CodexAppServerApi({required CodexAppServerClient client}) : _client = client;

  final CodexAppServerClient _client;

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

  Future<void> startTurn({
    required String threadId,
    required List<CodexTurnInputDto> input,
    required String? model,
    required String? effort,
  }) async {
    final params = <String, dynamic>{
      "threadId": threadId,
      "input": input.map((item) => item.toJson()).toList(growable: false),
    };
    if (model != null) params["model"] = model;
    if (effort != null) params["effort"] = effort;
    await _client.request(method: "turn/start", params: params);
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
}
