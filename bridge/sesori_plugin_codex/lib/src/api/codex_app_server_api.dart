import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../codex_app_server_client.dart";
import "models/codex_thread_dto.dart";

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
