import "../acp_content.dart";
import "../acp_protocol.dart";
import "../acp_stdio_client.dart";
import "models/acp_api_notification.dart";

/// Typed operations for one ACP agent over the stdio transport.
class AcpApi {
  const AcpApi({required AcpStdioClient client}) : _client = client;

  final AcpStdioClient _client;

  Stream<AcpApiNotification> get notifications => _client.notifications.map(parseNotification);

  Future<AcpInitializeResult> initialize({
    required AcpInitializeRequest request,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final response = await _client.request(
      method: AcpMethods.initialize,
      params: {
        "protocolVersion": acpProtocolVersion,
        "clientCapabilities": {
          "fs": {"readTextFile": false, "writeTextFile": false},
          "terminal": false,
          "_meta": ?request.capabilityMeta,
        },
        "clientInfo": {
          "name": request.clientName,
          "title": ?request.clientTitle,
          "version": request.clientVersion,
        },
      },
      timeout: timeout,
    );
    return AcpInitializeResult.fromJson(
      _responseMap(method: AcpMethods.initialize, response: response),
    );
  }

  Future<void> authenticate({
    required String methodId,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await _client.request(
      method: AcpMethods.authenticate,
      params: {"methodId": methodId},
      timeout: timeout,
    );
  }

  Future<AcpNewSessionResult> newSession({required String directory}) async {
    final response = await _client.request(
      method: AcpMethods.sessionNew,
      params: {"cwd": directory, "mcpServers": const <Object?>[]},
    );
    return AcpNewSessionResult.fromJson(
      _responseMap(method: AcpMethods.sessionNew, response: response),
    );
  }

  Future<AcpSessionListResult> listSessions({
    required String? directory,
    required String? cursor,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final response = await _client.request(
      method: AcpMethods.sessionList,
      params: {
        "cwd": ?directory,
        "cursor": ?cursor,
      },
      timeout: timeout,
    );
    return AcpSessionListResult.fromJson(
      _responseMap(method: AcpMethods.sessionList, response: response),
    );
  }

  Future<AcpPromptResult> prompt({
    required String sessionId,
    required List<AcpContentBlock> blocks,
  }) async {
    final response = await _client.request(
      method: AcpMethods.sessionPrompt,
      params: {
        "sessionId": sessionId,
        "prompt": blocks.map(_contentBlockToJson).toList(growable: false),
      },
      timeout: const Duration(minutes: 30),
    );
    return AcpPromptResult.fromJson(
      _responseMap(method: AcpMethods.sessionPrompt, response: response),
    );
  }

  Future<AcpNewSessionResult> loadSession({
    required String sessionId,
    required String directory,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final response = await _client.request(
      method: AcpMethods.sessionLoad,
      params: {
        "sessionId": sessionId,
        "cwd": directory,
        "mcpServers": const <Object?>[],
      },
      timeout: timeout,
    );
    return AcpNewSessionResult.fromJson(
      _responseMap(method: AcpMethods.sessionLoad, response: response),
    );
  }

  Future<AcpNewSessionResult> resumeSession({
    required String sessionId,
    required String directory,
  }) async {
    final response = await _client.request(
      method: AcpMethods.sessionResume,
      params: {
        "sessionId": sessionId,
        "cwd": directory,
        "mcpServers": const <Object?>[],
      },
      timeout: const Duration(minutes: 2),
    );
    return AcpNewSessionResult.fromJson(
      _responseMap(method: AcpMethods.sessionResume, response: response),
    );
  }

  Future<AcpNewSessionResult> setConfigOption({
    required String sessionId,
    required String configId,
    required String value,
  }) async {
    final response = await _client.request(
      method: AcpMethods.sessionSetConfigOption,
      params: {
        "sessionId": sessionId,
        "configId": configId,
        "value": value,
      },
    );
    return AcpNewSessionResult.fromJson(
      _responseMap(
        method: AcpMethods.sessionSetConfigOption,
        response: response,
      ),
    );
  }

  void cancelSession({required String sessionId}) {
    _client.notify(
      method: AcpMethods.sessionCancel,
      params: {"sessionId": sessionId},
    );
  }

  static AcpApiNotification parseNotification(AcpNotification notification) {
    if (notification.method != AcpMethods.sessionUpdate) {
      final sessionId = notification.params["sessionId"];
      return AcpApiExtensionNotification(
        method: notification.method,
        sessionId: sessionId is String && sessionId.isNotEmpty ? sessionId : null,
      );
    }
    final sessionId = notification.params["sessionId"];
    final rawUpdate = notification.params["update"];
    if (sessionId is! String || sessionId.isEmpty || rawUpdate is! Map) {
      return AcpApiExtensionNotification(
        method: notification.method,
        sessionId: sessionId is String && sessionId.isNotEmpty ? sessionId : null,
      );
    }
    final update = rawUpdate.cast<String, dynamic>();
    return AcpApiSessionNotification(
      sessionId: sessionId,
      update: _parseSessionUpdate(update),
    );
  }

  static AcpApiSessionUpdate _parseSessionUpdate(Map<String, dynamic> update) {
    return switch (update["sessionUpdate"]) {
      "agent_message_chunk" => _messageChunk(
        role: AcpApiMessageChunkRole.assistant,
        update: update,
      ),
      "agent_thought_chunk" => _messageChunk(
        role: AcpApiMessageChunkRole.thought,
        update: update,
      ),
      "user_message_chunk" => _messageChunk(
        role: AcpApiMessageChunkRole.user,
        update: update,
      ),
      "tool_call" => _toolUpdate(update: update, isInitial: true),
      "tool_call_update" => _toolUpdate(update: update, isInitial: false),
      "plan" => const AcpApiPlanUpdate(),
      "available_commands_update" => AcpApiAvailableCommandsUpdate(
        commands: _availableCommands(update["availableCommands"]),
      ),
      "session_info_update" => AcpApiSessionInfoUpdate(
        hasTitle: update.containsKey("title"),
        title: update["title"] is String && (update["title"] as String).isNotEmpty ? update["title"] as String : null,
        updatedAtMs: const AcpTimestampMsConverter().fromJson(update["updatedAt"]),
      ),
      _ => const AcpApiIgnoredSessionUpdate(),
    };
  }

  static AcpApiMessageChunkUpdate _messageChunk({
    required AcpApiMessageChunkRole role,
    required Map<String, dynamic> update,
  }) {
    final messageId = update["messageId"];
    return AcpApiMessageChunkUpdate(
      role: role,
      messageId: messageId is String && messageId.isNotEmpty ? messageId : null,
      text: acpContentText(update["content"]),
    );
  }

  static AcpApiToolUpdate _toolUpdate({
    required Map<String, dynamic> update,
    required bool isInitial,
  }) {
    final kind = update["kind"];
    final title = update["title"];
    final content = update["content"];
    final hasDiff = content is List && content.any((entry) => entry is Map && entry["type"] == "diff");
    final parsedKind = kind is String && kind.isNotEmpty ? kind : null;
    return AcpApiToolUpdate(
      isInitial: isInitial,
      toolCallId: update["toolCallId"] is String ? update["toolCallId"] as String : null,
      kind: parsedKind,
      title: title is String && title.isNotEmpty ? title : null,
      hasTitle: update.containsKey("title"),
      status: switch (update["status"]) {
        "pending" => AcpApiToolStatus.pending,
        "in_progress" => AcpApiToolStatus.inProgress,
        "completed" => AcpApiToolStatus.completed,
        "failed" => AcpApiToolStatus.failed,
        _ => AcpApiToolStatus.unknown,
      },
      hasStatus: update.containsKey("status"),
      output: acpContentText(content) ?? acpRawOutputText(update["rawOutput"]),
      isFileMutation: parsedKind == "edit" || parsedKind == "delete" || parsedKind == "move" || hasDiff,
      hasDiff: hasDiff,
    );
  }

  static List<AcpApiAvailableCommand> _availableCommands(Object? raw) {
    if (raw is! List) return const [];
    final commands = <AcpApiAvailableCommand>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final command = entry.cast<String, dynamic>();
      final name = command["name"];
      if (name is! String || name.isEmpty) continue;
      final description = command["description"];
      final input = command["input"];
      final hint = input is Map ? input["hint"] : null;
      commands.add(
        AcpApiAvailableCommand(
          name: name,
          description: description is String && description.isNotEmpty ? description : null,
          hint: hint is String && hint.isNotEmpty ? hint : null,
        ),
      );
    }
    return List.unmodifiable(commands);
  }

  Map<String, dynamic> _contentBlockToJson(AcpContentBlock block) {
    return switch (block) {
      AcpTextContentBlock(:final text) => {"type": "text", "text": text},
      AcpResourceLinkContentBlock(:final uri, :final name) => {
        "type": "resource_link",
        "uri": uri,
        "name": name,
      },
      AcpInlineContentBlock(:final type, :final mimeType, :final data) => {
        "type": type.name,
        "mimeType": mimeType,
        "data": data,
      },
    };
  }

  Map<String, dynamic> _responseMap({
    required String method,
    required Object? response,
  }) {
    if (response is Map) return response.cast<String, dynamic>();
    throw FormatException("$method returned a non-object result");
  }
}
