import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;

import "../api/codex_app_server_api.dart" as api;
import "../codex_app_server_client.dart";
import "models/codex_app_server_repository_models.dart";

/// Typed persistence boundary for all Codex app-server operations.
class CodexAppServerRepository {
  CodexAppServerRepository({
    required api.CodexAppServerApi api,
  }) : _api = api;

  final api.CodexAppServerApi _api;

  Stream<CodexEventRecord> get events => _api.notifications.map(mapNotification);

  Future<CodexStartedThread> startThread({
    required String directory,
    required CodexModelSelection? model,
  }) async {
    final response = await _api.startThread(
      arguments: api.CodexThreadStartArguments(
        directory: directory,
        model: _apiModel(model),
      ),
    );
    final thread = response.thread;
    final threadId = thread?.id;
    if (threadId == null || threadId.isEmpty) {
      throw StateError("thread/start response missing thread.id");
    }
    final resolvedDirectory = normalizeProjectDirectory(
      directory: thread?.cwd ?? directory,
    );
    final context = CodexThreadContextFacts(
      threadId: threadId,
      model: response.model ?? model?.modelId,
      provider: response.modelProvider ?? thread?.modelProvider ?? model?.providerId,
      directory: resolvedDirectory,
    );
    return CodexStartedThread(
      id: threadId,
      directory: resolvedDirectory,
      title: thread?.name,
      createdAtSeconds: thread?.createdAt,
      updatedAtSeconds: thread?.updatedAt,
      context: context,
    );
  }

  Future<CodexThreadContextFacts> resumeThread({
    required String threadId,
  }) async {
    final response = await _api.resumeThread(threadId: threadId);
    final thread = response.thread;
    return CodexThreadContextFacts(
      threadId: threadId,
      model: response.model,
      provider: response.modelProvider ?? thread?.modelProvider,
      directory: thread?.cwd ?? response.cwd,
    );
  }

  Future<CodexStartedTurn> startTurn({
    required String threadId,
    required List<CodexTurnInput> input,
    required CodexModelSelection? model,
    required String? effort,
  }) async {
    final arguments = api.CodexTurnStartArguments(
      threadId: threadId,
      input: input.map(_apiInput).toList(growable: false),
      model: _apiModel(model),
      effort: effort,
    );
    late final api.CodexTurnResponseDto response;
    try {
      response = await _api.startTurn(arguments: arguments);
    } on CodexRpcException catch (error) {
      if (_isThreadNotFound(error)) throw const CodexThreadNotFoundException();
      rethrow;
    }
    final turnId = response.turn?.id ?? response.turnId ?? response.id;
    if (turnId == null || turnId.isEmpty) {
      throw StateError("turn/start response missing turn.id");
    }
    return CodexStartedTurn(id: turnId);
  }

  Future<void> interrupt({
    required String threadId,
    required String turnId,
  }) async {
    try {
      await _api.interruptTurn(threadId: threadId, turnId: turnId);
    } on CodexRpcException catch (error) {
      if (error.code == -32602) throw const CodexTurnAlreadyStoppedException();
      rethrow;
    }
  }

  Future<void> setThreadName({
    required String threadId,
    required String name,
  }) => _api.setThreadName(threadId: threadId, name: name);

  Future<void> archiveThread({required String threadId}) => _api.archiveThread(threadId: threadId);

  Future<List<CodexModelRecord>> listModels({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final response = await _api.listModels(timeout: timeout);
    return [
      for (final model in response.data)
        CodexModelRecord(
          id: model.id,
          displayName: model.displayName,
          hidden: model.hidden ?? false,
          isDefault: model.isDefault ?? false,
          defaultReasoningEffort: model.defaultReasoningEffort,
          supportedReasoningEfforts: [
            for (final effort in model.supportedReasoningEfforts)
              if (effort.reasoningEffort case final value? when value.isNotEmpty) value,
          ],
        ),
    ];
  }

  Future<void> sendKeepalive({required Duration timeout}) async {
    await _api.listModels(timeout: timeout);
  }

  CodexEventRecord mapNotification(api.CodexNotificationDto notification) {
    final params = notification.params;
    final thread = params.thread;
    final threadId = params.threadId ?? thread?.id;
    final turnId = params.turnId ?? params.turn?.id;
    final context = threadId == null
        ? null
        : CodexThreadContextFacts(
            threadId: threadId,
            model: params.model,
            provider: params.modelProvider ?? thread?.modelProvider,
            directory: params.cwd ?? thread?.cwd,
          );

    switch (notification.method) {
      case api.CodexNotificationMethod.threadStarted:
        final startedThread = _startedThread(thread: thread, context: context);
        return CodexThreadStartedEventRecord(
          threadId: startedThread?.id,
          thread: startedThread,
          context: context,
        );
      case api.CodexNotificationMethod.threadNameUpdated:
        return CodexThreadNameUpdatedEventRecord(
          threadId: threadId,
          threadName: params.threadName,
          context: context,
        );
      case api.CodexNotificationMethod.threadStatusChanged:
        final status = params.status;
        final type = status?.type ?? status?.status?.type;
        return CodexThreadStatusChangedEventRecord(
          threadId: threadId,
          status: type == "idle" ? CodexThreadStatus.idle : CodexThreadStatus.busy,
          context: context,
        );
      case api.CodexNotificationMethod.threadClosed:
        return CodexThreadClosedEventRecord(
          threadId: threadId,
          context: context,
        );
      case api.CodexNotificationMethod.turnStarted:
        return CodexTurnStartedEventRecord(
          threadId: threadId,
          turnId: turnId,
          context: context,
        );
      case api.CodexNotificationMethod.turnCompleted:
        return CodexTurnCompletedEventRecord(
          threadId: threadId,
          turnId: turnId,
          context: context,
        );
      case api.CodexNotificationMethod.itemStarted:
      case api.CodexNotificationMethod.itemCompleted:
        return CodexItemEventRecord(
          threadId: threadId,
          turnId: turnId,
          item: _itemRecord(
            item: params.item,
            completed: notification.method == api.CodexNotificationMethod.itemCompleted,
          ),
          context: context,
        );
      case api.CodexNotificationMethod.agentMessageDelta:
        return CodexAgentMessageDeltaEventRecord(
          threadId: threadId,
          turnId: turnId,
          itemId: params.itemId,
          delta: params.delta,
          context: context,
        );
      case api.CodexNotificationMethod.reasoningDelta:
        return CodexReasoningDeltaEventRecord(
          threadId: threadId,
          turnId: turnId,
          itemId: params.itemId,
          delta: params.delta,
          context: context,
        );
      case api.CodexNotificationMethod.itemRemoved:
        return CodexItemRemovedEventRecord(
          threadId: threadId,
          turnId: turnId,
          itemId: params.itemId,
          context: context,
        );
      case api.CodexNotificationMethod.itemPartRemoved:
        return CodexItemPartRemovedEventRecord(
          threadId: threadId,
          turnId: turnId,
          itemId: params.itemId,
          partId: params.partId,
          context: context,
        );
      case api.CodexNotificationMethod.error:
        return CodexErrorEventRecord(
          threadId: threadId,
          turnId: turnId,
          context: context,
        );
      case api.CodexNotificationMethod.turnDiffUpdated:
        return CodexTurnDiffUpdatedEventRecord(
          threadId: threadId,
          turnId: turnId,
          context: context,
        );
      case api.CodexNotificationMethod.projectChanged:
        return const CodexProjectChangedEventRecord();
      case api.CodexNotificationMethod.other:
        return CodexIgnoredEventRecord(
          threadId: threadId,
          turnId: turnId,
          context: context,
        );
    }
  }

  CodexStartedThread? _startedThread({
    required api.CodexThreadDto? thread,
    required CodexThreadContextFacts? context,
  }) {
    final id = thread?.id;
    if (thread == null || id == null || id.isEmpty || context == null) {
      return null;
    }
    return CodexStartedThread(
      id: id,
      directory: thread.cwd,
      title: thread.name,
      createdAtSeconds: thread.createdAt,
      updatedAtSeconds: thread.updatedAt,
      context: context,
    );
  }

  CodexItemRecord? _itemRecord({
    required api.CodexItemDto? item,
    required bool completed,
  }) {
    final id = item?.id;
    if (item == null || id == null || id.isEmpty) return null;
    final contentText = _joinedText(item.content);
    return switch (item.type) {
      "userMessage" => CodexUserMessageItemRecord(
        id: id,
        text: contentText,
      ),
      "agentMessage" => CodexAgentMessageItemRecord(
        id: id,
        text: item.text ?? contentText,
      ),
      "reasoning" => CodexReasoningItemRecord(
        id: id,
        text: _joinedText([...item.content, ...item.summary]),
      ),
      "commandExecution" => CodexToolItemRecord(
        id: id,
        tool: "shell",
        title: item.command,
        status: _toolStatus(item.status, completed: completed),
        output: item.aggregatedOutput,
        error: null,
      ),
      "fileChange" => CodexToolItemRecord(
        id: id,
        tool: "edit",
        title: _fileChangeTitle(item.changes),
        status: _toolStatus(item.status, completed: completed),
        output: _fileChangeOutput(item.changes),
        error: null,
      ),
      "mcpToolCall" => CodexToolItemRecord(
        id: id,
        tool: item.tool ?? "mcp",
        title: _mcpToolTitle(server: item.server, tool: item.tool),
        status: _toolStatus(item.status, completed: completed),
        output: _joinedText(item.result?.content ?? const []),
        error: item.error?.message,
      ),
      "webSearch" => CodexToolItemRecord(
        id: id,
        tool: "web_search",
        title: item.query,
        status: completed ? CodexToolStatus.completed : CodexToolStatus.running,
        output: null,
        error: null,
      ),
      _ => CodexUnsupportedItemRecord(id: id),
    };
  }

  static api.CodexApiModelSelection? _apiModel(
    CodexModelSelection? model,
  ) {
    if (model == null) return null;
    return api.CodexApiModelSelection(
      providerId: model.providerId,
      modelId: model.modelId,
    );
  }

  static api.CodexApiTurnInput _apiInput(CodexTurnInput input) {
    return switch (input) {
      CodexTurnTextInput(:final text) => api.CodexApiTurnTextInput(text: text),
      CodexTurnLocalImageInput(:final path) => api.CodexApiTurnLocalImageInput(path: path),
      CodexTurnImageUrlInput(:final url) => api.CodexApiTurnImageUrlInput(url: url),
    };
  }

  static CodexToolStatus _toolStatus(
    String? status, {
    required bool completed,
  }) {
    return switch (status) {
      "inProgress" => CodexToolStatus.running,
      "completed" => CodexToolStatus.completed,
      "failed" || "declined" => CodexToolStatus.error,
      _ => completed ? CodexToolStatus.completed : CodexToolStatus.running,
    };
  }

  static String? _joinedText(List<String> values) {
    final text = values.join();
    return text.isEmpty ? null : text;
  }

  static String? _fileChangeTitle(List<api.CodexFileChangeDto> changes) {
    if (changes.isEmpty) return null;
    final paths = changes.map((change) => change.path).whereType<String>().toList(growable: false);
    if (paths.isEmpty) return "${changes.length} file change(s)";
    final shown = paths.take(3).join(", ");
    return paths.length > 3 ? "$shown +${paths.length - 3} more" : shown;
  }

  static String? _fileChangeOutput(List<api.CodexFileChangeDto> changes) {
    final output = changes.map((change) => change.diff).whereType<String>().where((diff) => diff.isNotEmpty).join("\n");
    return output.isEmpty ? null : output;
  }

  static String? _mcpToolTitle({
    required String? server,
    required String? tool,
  }) {
    if (server != null && tool != null) return "$server/$tool";
    return tool ?? server;
  }

  static bool _isThreadNotFound(CodexRpcException error) {
    final message = error.message.toLowerCase();
    return message.contains("thread not found") ||
        message.contains("no such thread") ||
        (error.code == -32600 && message.contains("not found"));
  }
}
