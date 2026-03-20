import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../opencode_plugin.dart";
import "sse/sse_connection.dart";

class OpenCodePlugin implements BridgePlugin {
  final OpenCodeService _service;
  final SseEventParser _parser;
  final BufferedUntilFirstListener<BridgeSseEvent> _eventBuffer;
  final String _serverUrl;
  final String? _password;
  late final SseConnection _sseConnection;

  OpenCodePlugin({
    required String serverUrl,
    String? password,
  }) : _serverUrl = serverUrl,
       _password = password,
       _service = _createService(serverUrl, password),
       _parser = SseEventParser(),
       _eventBuffer = BufferedUntilFirstListener<BridgeSseEvent>() {
    _sseConnection = SseConnection(
      targetUrl: serverUrl,
      password: password,
      onEvent: _handleRawSseEvent,
      onReconnect: () async {
        _service.reset();
        await _service.coldStart();
        _emitProjectsSummary();
      },
    );
    unawaited(_initialize());
  }

  static OpenCodeService _createService(String serverUrl, String? password) {
    final api = OpenCodeApi(serverURL: serverUrl, password: password);
    final repository = OpenCodeRepository(api);
    final tracker = ActiveSessionTracker(repository);
    return OpenCodeService(repository, tracker);
  }

  Future<void> _initialize() async {
    try {
      await _service.coldStart();
      _emitProjectsSummary();
    } catch (_) {
      // Initialization errors should not crash plugin creation.
    }
    _sseConnection.start();
  }

  @override
  String get id => "opencode";

  @override
  Stream<BridgeSseEvent> get events => _eventBuffer.stream;

  @override
  Future<String> healthCheck() async {
    final client = http.Client();
    try {
      final headers = <String, String>{};
      if (_password != null) {
        final creds = base64.encode(utf8.encode("opencode:$_password"));
        headers["Authorization"] = "Basic $creds";
      }
      final response = await client
          .get(Uri.parse("$_serverUrl/global/health"), headers: headers)
          .timeout(const Duration(seconds: 5));
      return response.body;
    } finally {
      client.close();
    }
  }

  // ignore: remove_deprecations_in_breaking_versions
  @Deprecated("Temporary proxy — replace with typed plugin methods")
  @override
  Future<({int status, Map<String, String> headers, String? body})> proxyRequest({
    required String method,
    required String path,
    required Map<String, String> headers,
    String? body,
  }) async {
    final client = http.Client();
    try {
      final uri = Uri.parse("$_serverUrl$path");
      final reqHeaders = Map<String, String>.from(headers);
      if (_password != null) {
        final creds = base64.encode(utf8.encode("opencode:$_password"));
        reqHeaders["Authorization"] = "Basic $creds";
      }

      final request = http.Request(method, uri)..headers.addAll(reqHeaders);
      if (body != null) {
        request.body = body;
      }

      final streamed = await client.send(request).timeout(const Duration(seconds: 30));
      final responseBody = await streamed.stream.bytesToString();
      return (
        status: streamed.statusCode,
        headers: streamed.headers,
        body: responseBody.isEmpty ? null : responseBody,
      );
    } on TimeoutException {
      return (status: 504, headers: <String, String>{}, body: "Gateway Timeout");
    } catch (e) {
      return (status: 502, headers: <String, String>{}, body: "upstream unreachable: $e");
    } finally {
      client.close();
    }
  }

  @override
  Future<PluginProvidersResult> getProviders({required bool connectedOnly}) async {
    final response = await _service.repository.api.listProviders();
    final connectedIds = response.connected.toSet();
    final source = connectedOnly ? response.all.where((p) => connectedIds.contains(p.id)).toList() : response.all;
    final providers = source.map((providerInfo) {
      final models = providerInfo.models.values
          .map((m) => PluginModel(id: m.id, name: m.name, family: m.family))
          .toList();
      return _mapProvider(
        id: providerInfo.id,
        name: providerInfo.name,
        models: models,
        defaultModels: response.defaults,
      );
    }).toList();
    return PluginProvidersResult(providers: providers);
  }

  PluginProvider _mapProvider({
    required String id,
    required String name,
    required List<PluginModel> models,
    required Map<String, String> defaultModels,
  }) {
    final defaultModelID = defaultModels[id];

    return switch (id.toLowerCase()) {
      "anthropic" => PluginProvider.anthropic(
        id: id,
        name: name,
        authType: PluginProviderAuthType.apiKey,
        models: models,
        defaultModelID: defaultModelID,
      ),
      "openai" => PluginProvider.openAI(
        id: id,
        name: name,
        authType: PluginProviderAuthType.apiKey,
        models: models,
        defaultModelID: defaultModelID,
      ),
      "google" => PluginProvider.google(
        id: id,
        name: name,
        authType: PluginProviderAuthType.apiKey,
        models: models,
        defaultModelID: defaultModelID,
      ),
      "mistral" => PluginProvider.mistral(
        id: id,
        name: name,
        authType: PluginProviderAuthType.apiKey,
        models: models,
        defaultModelID: defaultModelID,
      ),
      "groq" => PluginProvider.groq(
        id: id,
        name: name,
        authType: PluginProviderAuthType.apiKey,
        models: models,
        defaultModelID: defaultModelID,
      ),
      "xai" => PluginProvider.xAI(
        id: id,
        name: name,
        authType: PluginProviderAuthType.apiKey,
        models: models,
        defaultModelID: defaultModelID,
      ),
      "deepseek" => PluginProvider.deepseek(
        id: id,
        name: name,
        authType: PluginProviderAuthType.apiKey,
        models: models,
        defaultModelID: defaultModelID,
      ),
      "amazon-bedrock" || "bedrock" => PluginProvider.amazonBedrock(
        id: id,
        name: name,
        authType: PluginProviderAuthType.unknown,
        models: models,
        defaultModelID: defaultModelID,
      ),
      "azure" => PluginProvider.azure(
        id: id,
        name: name,
        authType: PluginProviderAuthType.apiKey,
        models: models,
        defaultModelID: defaultModelID,
      ),
      _ => PluginProvider.custom(
        id: id,
        name: name,
        authType: PluginProviderAuthType.unknown,
        models: models,
        defaultModelID: defaultModelID,
      ),
    };
  }

  @override
  Future<void> dispose() async {
    _sseConnection.stop();
    await _eventBuffer.close();
  }

  @override
  Future<List<PluginProject>> getProjects() async {
    return (await _service.getProjects()).map(_mapProject).toList();
  }

  @override
  Future<List<PluginSession>> getSessions(
    String worktree, {
    int? start,
    int? limit,
  }) async {
    final sessions = await _service.getSessions(
      worktree: worktree,
      start: start,
      limit: limit,
    );
    return sessions.map(_mapSession).toList();
  }

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) async {
    final messages = await _service.getLastExchange(sessionId);
    return messages.map(_mapMessage).toList();
  }

  void _handleRawSseEvent(String rawData) {
    try {
      final parseResult = _parser.parse(rawData);
      final event = parseResult.event;
      if (event == null) return;

      final changed = _service.handleSseEvent(event, parseResult.directory);
      if (changed) {
        _emitProjectsSummary();
      }

      final bridgeEvent = _mapSseEvent(event);
      if (bridgeEvent != null) {
        _eventBuffer.add(bridgeEvent);
      }
    } catch (_) {
      // processSseEvent must never throw.
    }
  }

  void _emitProjectsSummary() {
    _eventBuffer.add(const BridgeSseProjectUpdated());
  }

  PluginProject _mapProject(Project p) => PluginProject(
    id: p.id,
    worktree: p.worktree,
    name: p.name,
    time: switch (p.time) {
      ProjectTime(:final created, :final updated) => PluginProjectTime(
        created: created,
        updated: updated,
      ),
      null => null,
    },
  );

  PluginSession _mapSession(Session s) => PluginSession(
    id: s.id,
    projectID: s.projectID,
    directory: s.directory,
    parentID: s.parentID,
    title: s.title,
    summary: switch (s.summary) {
      SessionSummary(:final additions, :final deletions, :final files) => PluginSessionSummary(
        additions: additions,
        deletions: deletions,
        files: files,
      ),
      null => null,
    },
    time: switch (s.time) {
      SessionTime(:final created, :final updated, :final archived) => PluginSessionTime(
        created: created,
        updated: updated,
        archived: archived,
      ),
      null => null,
    },
  );

  PluginMessageWithParts _mapMessage(MessageWithParts raw) {
    final info = raw.info;
    final parts = raw.parts;
    return PluginMessageWithParts(
      info: PluginMessage(
        role: info.role,
        id: info.id,
        sessionID: info.sessionID,
        parentID: info.parentID,
        agent: info.agent,
        modelID: info.modelID,
        providerID: info.providerID,
        cost: info.cost,
        time: switch (info.time) {
          MessageTime(:final created, :final completed) => PluginMessageTime(
            created: created,
            completed: completed,
          ),
          null => null,
        },
        finish: info.finish,
      ),
      parts: parts.map(_mapMessagePart).toList(),
    );
  }

  PluginMessagePart _mapMessagePart(MessagePart raw) {
    return PluginMessagePart(
      id: raw.id,
      sessionID: raw.sessionID,
      messageID: raw.messageID,
      type: raw.type,
      text: raw.text,
      tool: raw.tool,
      callID: raw.callID,
      state: switch (raw.state) {
        ToolState(:final status, :final title, :final output, :final error) => PluginToolState(
          status: status,
          title: title,
          output: output,
          error: error,
        ),
        null => null,
      },
      mime: raw.mime,
      url: raw.url,
      filename: raw.filename,
      cost: raw.cost,
      reason: raw.reason,
      prompt: raw.prompt,
      description: raw.description,
      agent: raw.agent,
      snapshot: raw.snapshot,
      time: switch (raw.time) {
        PartTime(:final start, :final end) => PluginPartTime(
          start: start,
          end: end,
        ),
        null => null,
      },
    );
  }

  BridgeSseEvent? _mapSseEvent(SseEventData event) {
    return switch (event) {
      SseServerConnected() => const BridgeSseServerConnected(),
      SseServerHeartbeat() => const BridgeSseServerHeartbeat(),
      SseServerInstanceDisposed(:final directory) => BridgeSseServerInstanceDisposed(directory: directory),
      SseGlobalDisposed() => const BridgeSseGlobalDisposed(),
      SseSessionCreated(:final info) => BridgeSseSessionCreated(info: info.toJson()),
      SseSessionUpdated(:final info) => BridgeSseSessionUpdated(info: info.toJson()),
      SseSessionDeleted(:final info) => BridgeSseSessionDeleted(info: info.toJson()),
      SseSessionDiff(:final sessionID, :final diff) => BridgeSseSessionDiff(
        sessionID: sessionID,
        diff: diff.map((item) => item.toJson()).toList(),
      ),
      SseSessionError(:final sessionID) => BridgeSseSessionError(sessionID: sessionID),
      SseSessionCompacted(:final sessionID) => BridgeSseSessionCompacted(sessionID: sessionID),
      SseSessionStatus(:final sessionID, :final status) => BridgeSseSessionStatus(
        sessionID: sessionID,
        status: status.toJson(),
      ),
      SseSessionIdle(:final sessionID) => BridgeSseSessionIdle(sessionID: sessionID),
      SseMessageUpdated(:final info) => BridgeSseMessageUpdated(info: info.toJson()),
      SseMessageRemoved(:final sessionID, :final messageID) => BridgeSseMessageRemoved(
        sessionID: sessionID,
        messageID: messageID,
      ),
      SseMessagePartUpdated(:final part) => BridgeSseMessagePartUpdated(part: part.toJson()),
      SseMessagePartDelta(
        :final sessionID,
        :final messageID,
        :final partID,
        :final field,
        :final delta,
      ) =>
        BridgeSseMessagePartDelta(
          sessionID: sessionID,
          messageID: messageID,
          partID: partID,
          field: field,
          delta: delta,
        ),
      SseMessagePartRemoved(:final sessionID, :final messageID, :final partID) => BridgeSseMessagePartRemoved(
        sessionID: sessionID,
        messageID: messageID,
        partID: partID,
      ),
      SsePtyCreated() => const BridgeSsePtyCreated(),
      SsePtyUpdated() => const BridgeSsePtyUpdated(),
      SsePtyExited(:final id, :final exitCode) => BridgeSsePtyExited(id: id, exitCode: exitCode),
      SsePtyDeleted(:final id) => BridgeSsePtyDeleted(id: id),
      SsePermissionAsked(:final requestID, :final sessionID, :final tool, :final description) =>
        BridgeSsePermissionAsked(
          requestID: requestID,
          sessionID: sessionID,
          tool: tool,
          description: description,
        ),
      SsePermissionReplied(:final requestID, :final reply) => BridgeSsePermissionReplied(
        requestID: requestID,
        reply: reply,
      ),
      SsePermissionUpdated() => const BridgeSsePermissionUpdated(),
      SseQuestionAsked(:final id, :final sessionID, :final questions) => BridgeSseQuestionAsked(
        id: id,
        sessionID: sessionID,
        questions: questions.map((q) => q.toJson()).toList(),
      ),
      SseQuestionReplied(:final requestID, :final sessionID) => BridgeSseQuestionReplied(
        requestID: requestID,
        sessionID: sessionID,
      ),
      SseQuestionRejected(:final requestID, :final sessionID) => BridgeSseQuestionRejected(
        requestID: requestID,
        sessionID: sessionID,
      ),
      SseTodoUpdated(:final sessionID) => BridgeSseTodoUpdated(sessionID: sessionID),
      SseProjectUpdated() => const BridgeSseProjectUpdated(),
      SseVcsBranchUpdated() => const BridgeSseVcsBranchUpdated(),
      SseFileEdited(:final file) => BridgeSseFileEdited(file: file),
      SseFileWatcherUpdated(:final file, :final event) => BridgeSseFileWatcherUpdated(file: file, event: event),
      SseLspUpdated() => const BridgeSseLspUpdated(),
      SseLspClientDiagnostics(:final serverID, :final path) => BridgeSseLspClientDiagnostics(
        serverID: serverID,
        path: path,
      ),
      SseMcpToolsChanged() => const BridgeSseMcpToolsChanged(),
      SseMcpBrowserOpenFailed() => const BridgeSseMcpBrowserOpenFailed(),
      SseInstallationUpdated(:final version) => BridgeSseInstallationUpdated(version: version),
      SseInstallationUpdateAvailable(:final version) => BridgeSseInstallationUpdateAvailable(version: version),
      SseWorkspaceReady(:final name) => BridgeSseWorkspaceReady(name: name),
      SseWorkspaceFailed(:final message) => BridgeSseWorkspaceFailed(message: message),
      SseTuiToastShow(:final title, :final message, :final variant) => BridgeSseTuiToastShow(
        title: title,
        message: message,
        variant: variant,
      ),
      SseWorktreeReady() => const BridgeSseWorktreeReady(),
      SseWorktreeFailed() => const BridgeSseWorktreeFailed(),
    };
  }

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    return _service
        .buildSummary()
        .map(
          (s) => PluginProjectActivitySummary(
            id: s.id,
            activeSessions: s.activeSessions,
            activeSessionIds: s.activeSessionIds,
          ),
        )
        .toList();
  }
}
