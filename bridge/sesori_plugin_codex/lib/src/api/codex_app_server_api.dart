import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, SesoriMcpLaunch;

import "../codex_app_server_client.dart";
import "../models/codex_collaboration_mode.dart";
import "../models/codex_service_tier.dart";
import "models/codex_account_dto.dart";
import "models/codex_apps_dto.dart";
import "models/codex_collaboration_mode_dto.dart";
import "models/codex_config_read_dto.dart";
import "models/codex_mcp_oauth_dto.dart";
import "models/codex_mcp_status_dto.dart";
import "models/codex_model_dto.dart";
import "models/codex_skill_dto.dart";
import "models/codex_thread_dto.dart";
import "models/codex_thread_sample_dto.dart";
import "models/codex_turn_dto.dart";
import "models/codex_turn_input_dto.dart";

final class const CodexMcpThreadNotLoadedException({required final CodexRpcException innerError}) implements Exception {
  @override
  String toString() => "Codex MCP inventory requires a loaded thread";
}

/// Layer-1 typed boundary for migrated Codex app-server operations.
class CodexAppServerApi({required final CodexAppServerTransport _client}) {
  /// Codex stops a sample after 30 s with its own "sample timed out" error;
  /// waiting longer lets that error arrive instead of a local timeout.
  static const _sampleTimeout = Duration(seconds: 40);

  Stream<CodexMcpOAuthCompletionDto> get mcpOAuthCompletions => _client.notifications
      .where((notification) => notification.method == "mcpServer/oauthLogin/completed")
      .map((notification) => CodexMcpOAuthCompletionDto.fromJson(notification.params));

  Future<CodexMcpOAuthLoginDto> startMcpOAuth({
    required String name,
    required String? threadId,
    required int timeoutSecs,
  }) async {
    final result = await _client.request(
      method: "mcpServer/oauth/login",
      params: {
        "name": name,
        "threadId": ?threadId,
        "timeoutSecs": timeoutSecs,
      },
      timeout: codexRequestTimeout,
    );
    if (result is! Map) throw StateError("expected a Codex MCP login response, got ${result.runtimeType}");
    return CodexMcpOAuthLoginDto.fromJson(result.cast<String, dynamic>());
  }

  Future<CodexAppsPageDto> listAppsPage({required String? threadId, required String? cursor}) async {
    final result = await _client.request(
      method: "app/list",
      params: {
        "threadId": ?threadId,
        "cursor": ?cursor,
        "limit": 100,
        "forceRefetch": cursor == null,
      },
      timeout: codexRequestTimeout,
    );
    if (result is! Map) throw StateError("expected a Codex app catalog page, got ${result.runtimeType}");
    return CodexAppsPageDto.fromJson(result.cast<String, dynamic>());
  }

  Future<CodexMcpStatusPageDto> listMcpServersPage({required String? threadId, required String? cursor}) async {
    final result = await _client
        .request(
          method: "mcpServerStatus/list",
          params: {
            "threadId": ?threadId,
            "cursor": ?cursor,
            "limit": 100,
            "detail": "toolsAndAuthOnly",
          },
          timeout: codexRequestTimeout,
        )
        .onError<CodexRpcException>((error, stackTrace) {
          if (threadId != null && error.code == -32600 && error.message == "thread not found: $threadId") {
            Error.throwWithStackTrace(CodexMcpThreadNotLoadedException(innerError: error), stackTrace);
          }
          Error.throwWithStackTrace(error, stackTrace);
        });
    if (result is! Map) {
      throw StateError("expected a Codex MCP status page, got ${result.runtimeType}");
    }
    return CodexMcpStatusPageDto.fromJson(result.cast<String, dynamic>());
  }

  Stream<CodexAccountLoginCompletedNotificationDto> get accountLoginCompletions => _client.notifications
      .where((notification) => notification.method == "account/login/completed")
      .map(
        (notification) => CodexAccountLoginCompletedNotificationDto.fromJson(
          notification.params,
        ),
      );

  Future<CodexDeviceLoginStartResponseDto> startDeviceLogin({
    required Duration timeout,
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
    required Duration timeout,
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
    required bool fastMode,
    required String developerInstructions,
    required SesoriMcpLaunch? sesoriMcp,
  }) async {
    // No `modelProvider`: since 0.166.0 Codex rejects input on a thread whose
    // provider differs from the configured one, so a thread must use the
    // provider Codex itself resolves from config and profiles.
    final params = <String, dynamic>{"cwd": cwd, "developerInstructions": developerInstructions};
    if (model != null) params["model"] = model;
    // Only set when true: an unset thread tier lets Codex apply the model's
    // own default rather than forcing standard speed on every new thread.
    // The first turn/start (below) always carries an explicit tier, so this
    // only matters for a thread created without an immediate turn.
    if (fastMode) params["serviceTier"] = CodexServiceTier.fast;
    if (sesoriMcp != null) params["config"] = _sesoriMcpConfig(launch: sesoriMcp);
    final result = await _client.request(method: "thread/start", params: params, timeout: codexRequestTimeout);
    return _decodeResponse(result: result, operation: "thread/start");
  }

  /// Codex does not persist a thread's developer instructions, so a resume
  /// sends them again, and the same holds for the thread's Sesori MCP server.
  /// A resume of a thread that is still running ignores both.
  Future<CodexThreadEnvelopeDto> resumeThread({
    required String threadId,
    required String developerInstructions,
    required SesoriMcpLaunch? sesoriMcp,
  }) async {
    final result = await _client.request(
      method: "thread/resume",
      params: {
        "threadId": threadId,
        "developerInstructions": developerInstructions,
        if (sesoriMcp != null) "config": _sesoriMcpConfig(launch: sesoriMcp),
      },
      timeout: codexRequestTimeout,
    );
    return _decodeResponse(result: result, operation: "thread/resume");
  }

  /// One thread's Sesori MCP server as per-thread config overrides. Dotted
  /// keys merge into the user's `mcp_servers` table; a nested `mcp_servers`
  /// object would replace it and drop the user's own servers. The token goes
  /// in a header, never the URL. The bridge asks the user before any proposed
  /// change takes effect, so the tools skip Codex's own approval prompt.
  static Map<String, Object> _sesoriMcpConfig({required SesoriMcpLaunch launch}) {
    final server = "mcp_servers.${launch.serverName}";
    return {
      "$server.url": launch.url,
      "$server.http_headers": {"Authorization": "Bearer ${launch.token}"},
      "$server.default_tools_approval_mode": "approve",
    };
  }

  /// The user's effective config. [cwd] adds the project config layers seen
  /// from that directory.
  Future<CodexConfigReadResponseDto> readConfig({required String? cwd}) async {
    final result = await _client.request(
      method: "config/read",
      params: {"cwd": ?cwd},
      timeout: codexRequestTimeout,
    );
    if (result is! Map) {
      throw StateError("expected a Codex config response object, got ${result.runtimeType}");
    }
    return CodexConfigReadResponseDto.fromJson(result.cast<String, dynamic>());
  }

  Future<CodexThreadEnvelopeDto> readThread({
    required String threadId,
  }) async {
    final result = await _client.request(
      method: "thread/read",
      params: {"threadId": threadId, "includeTurns": false},
      timeout: codexRequestTimeout,
    );
    return _decodeResponse(result: result, operation: "thread/read");
  }

  Future<CodexSkillsListResponseDto> listSkills({required String cwd}) async {
    final result = await _client.request(
      method: "skills/list",
      params: {
        "cwds": [cwd],
      },
      timeout: codexRequestTimeout,
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

  /// Replaces the folders, beyond the user's and the project's, that Codex
  /// loads skills from, for every thread of this app-server.
  Future<void> setSkillExtraRoots({required List<String> roots}) async {
    await _client.request(
      method: "skills/extraRoots/set",
      params: {"extraRoots": roots},
      timeout: codexRequestTimeout,
    );
  }

  Future<CodexModelListResponseDto> listModels() async {
    final result = await _client.request(
      method: "model/list",
      params: const <String, dynamic>{},
      timeout: codexRequestTimeout,
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
    required String? clientUserMessageId,
    required String? model,
    required String? effort,
    required CodexCollaborationMode? collaborationMode,
    required bool? fastMode,
  }) async {
    final params = <String, dynamic>{
      "threadId": threadId,
      "input": input.map((item) => item.toJson()).toList(growable: false),
      // Codex echoes this back as the user item's `clientId`, which is how the
      // item it publishes is traced to the send that caused it.
      "clientUserMessageId": ?clientUserMessageId,
    };
    // serviceTier applies to this turn and subsequent ones. Sent on every
    // turn issued through a bridge fastMode selection (true -> the "priority"
    // fast tier, false -> the "default" tier, which explicitly returns the
    // thread to standard speed); omitted (null) only for turns started
    // outside that selection (e.g. an async approval answer), which inherit
    // the thread's current tier instead of resetting it.
    final serviceTier = switch (fastMode) {
      null => null,
      true => CodexServiceTier.fast,
      false => CodexServiceTier.standard,
    };
    if (serviceTier != null) params["serviceTier"] = serviceTier;
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
    final result = await _client.request(method: "turn/start", params: params, timeout: codexRequestTimeout);
    if (result is! Map) {
      throw StateError(
        "expected a Codex turn response object from turn/start, got "
        "${result.runtimeType}",
      );
    }
    return CodexTurnStartResponseDto.fromJson(result.cast<String, dynamic>());
  }

  /// Removes [beforeTurnId] and every later turn from the loaded thread's
  /// persisted history. Codex writes the kept history to a new rollout and
  /// leaves local files alone.
  Future<void> revertThread({required String threadId, required String beforeTurnId}) async {
    await _client.request(
      method: "thread/revert",
      params: {"threadId": threadId, "beforeTurnId": beforeTurnId},
      timeout: codexRequestTimeout,
    );
  }

  /// Forks the stored thread through [lastTurnId], inclusive, into a new
  /// persisted thread in the source's directory. The source is left as it is
  /// and need not be loaded or idle. Codex sends `thread/started` for the fork.
  Future<CodexThreadEnvelopeDto> forkThread({
    required String threadId,
    required String lastTurnId,
    required String developerInstructions,
    required SesoriMcpLaunch? sesoriMcp,
  }) async {
    final result = await _client.request(
      method: "thread/fork",
      params: {
        "threadId": threadId,
        "lastTurnId": lastTurnId,
        "developerInstructions": developerInstructions,
        if (sesoriMcp != null) "config": _sesoriMcpConfig(launch: sesoriMcp),
        // Codex deprecates returning a paginated thread's whole history here.
        "excludeTurns": true,
      },
      timeout: codexRequestTimeout,
    );
    return _decodeResponse(result: result, operation: "thread/fork");
  }

  /// The thread's newest turn, without its items, as a one-turn page.
  Future<CodexThreadTurnsPageDto> listLatestTurn({required String threadId}) async {
    final result = await _client.request(
      method: "thread/turns/list",
      params: {"threadId": threadId, "limit": 1, "sortDirection": "desc", "itemsView": "notLoaded"},
      timeout: codexRequestTimeout,
    );
    if (result is! Map) {
      throw StateError("expected a Codex turns page from thread/turns/list, got ${result.runtimeType}");
    }
    return CodexThreadTurnsPageDto.fromJson(result.cast<String, dynamic>());
  }

  /// Asks the model [prompt] on a throwaway copy of the loaded thread, whose
  /// latest turn is [expectedTurnId]. Codex runs no tools, writes nothing to
  /// the thread, and leaves a running turn alone.
  Future<CodexThreadSampleDto> sampleThread({
    required String threadId,
    required String expectedTurnId,
    required String prompt,
  }) async {
    final result = await _client.request(
      method: "thread/sample",
      params: {
        "threadId": threadId,
        "expectedTurnId": expectedTurnId,
        // Codex 0.169.0 and newer may copy a turn that is still running.
        // Earlier releases ignore the field and refuse a running source.
        "allowInProgressTurn": true,
        "prompt": prompt,
      },
      timeout: _sampleTimeout,
    );
    if (result is! Map) {
      throw StateError("expected a Codex sample from thread/sample, got ${result.runtimeType}");
    }
    return CodexThreadSampleDto.fromJson(result.cast<String, dynamic>());
  }

  Future<void> archiveThread({required String threadId}) async {
    await _client.request(method: "thread/archive", params: {"threadId": threadId}, timeout: codexRequestTimeout);
  }

  Future<void> compactThread({required String threadId}) async {
    await _client.request(
      method: "thread/compact/start",
      params: {"threadId": threadId},
      timeout: codexRequestTimeout,
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
