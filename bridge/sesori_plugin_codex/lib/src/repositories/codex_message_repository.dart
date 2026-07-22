import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../api/codex_rollout_api.dart";
import "../api/models/codex_rollout_dto.dart";
import "../codex_config_reader.dart";

/// Layer-2 mapping from typed rollout transcript DTOs to plugin messages.
class CodexMessageRepository {
  CodexMessageRepository({required CodexRolloutApi rolloutApi}) : _rolloutApi = rolloutApi;

  final CodexRolloutApi _rolloutApi;

  List<PluginMessageWithParts> readMessages({
    required String rolloutPath,
    required String sessionId,
    CodexConfigDefaults config = const CodexConfigDefaults.empty(),
  }) {
    final List<CodexRolloutLineDto> lines;
    try {
      lines = _rolloutApi.readTranscript(rolloutPath: rolloutPath);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PluginOperationException(
          "read Codex session transcript",
          message: "history read for $sessionId failed",
          cause: error,
        ),
        stackTrace,
      );
    }

    final toolOutputs = <String, String>{};
    for (final line in lines) {
      final payload = line.payload;
      if (payload?.type != CodexRolloutPayloadType.functionCallOutput) {
        continue;
      }
      final callId = payload?.callId;
      final output = payload?.output;
      if (callId != null && output != null) toolOutputs[callId] = output;
    }

    final messages = <PluginMessageWithParts>[];
    var messageCounter = 0;
    String? sessionProvider;
    String? currentModel;

    PluginMessage assistantInfo(String id, PluginMessageTime? time) => PluginMessage.assistant(
      id: id,
      sessionID: sessionId,
      agent: "codex",
      modelID: currentModel ?? config.model,
      providerID: sessionProvider ?? config.modelProvider ?? "openai",
      time: time,
    );

    for (final line in lines) {
      final payload = line.payload;
      switch (line.type) {
        case CodexRolloutLineType.sessionMeta:
          sessionProvider ??= payload?.modelProvider;
          continue;
        case CodexRolloutLineType.turnContext:
          final model = payload?.model;
          if (model != null && model.isNotEmpty) currentModel = model;
          continue;
        case CodexRolloutLineType.responseItem:
          break;
        case CodexRolloutLineType.unknown:
        case null:
          continue;
      }
      if (payload == null) continue;
      final messageTime = _messageTimeFrom(line.timestamp);

      if (payload.type == CodexRolloutPayloadType.functionCall) {
        final callId = payload.callId;
        final name = payload.name ?? "tool";
        final output = callId == null ? null : toolOutputs[callId];
        messageCounter += 1;
        messages.add(
          _toolMessage(
            messageId: "m-$messageCounter",
            sessionId: sessionId,
            info: assistantInfo("m-$messageCounter", messageTime),
            tool: _normalizeToolName(name),
            title: _toolCallTitle(payload.arguments),
            status: output != null ? PluginToolStatus.completed : PluginToolStatus.running,
            output: output,
          ),
        );
        continue;
      }
      if (payload.type == CodexRolloutPayloadType.functionCallOutput) {
        continue;
      }
      if (payload.type == CodexRolloutPayloadType.webSearchCall) {
        messageCounter += 1;
        messages.add(
          _toolMessage(
            messageId: "m-$messageCounter",
            sessionId: sessionId,
            info: assistantInfo("m-$messageCounter", messageTime),
            tool: "web_search",
            title: payload.action?.query,
            status: PluginToolStatus.completed,
            output: null,
          ),
        );
        continue;
      }

      if (payload.role != CodexRolloutRole.user && payload.role != CodexRolloutRole.assistant) {
        continue;
      }
      final texts = [
        for (final content in payload.content ?? const <CodexRolloutContentDto>[])
          if ((content.type == CodexRolloutContentType.inputText ||
                  content.type == CodexRolloutContentType.outputText) &&
              content.text != null &&
              content.text!.isNotEmpty)
            content.text!,
      ];
      if (texts.isEmpty) continue;

      messageCounter += 1;
      final messageId = "m-$messageCounter";
      final info = payload.role == CodexRolloutRole.user
          ? PluginMessage.user(
              id: messageId,
              sessionID: sessionId,
              agent: null,
              time: messageTime,
            )
          : assistantInfo(messageId, messageTime);
      messages.add(
        PluginMessageWithParts(
          info: info,
          parts: [
            for (var i = 0; i < texts.length; i++)
              PluginMessagePart(
                id: "$messageId-p$i",
                sessionID: sessionId,
                messageID: messageId,
                type: PluginMessagePartType.text,
                text: texts[i],
                tool: null,
                state: null,
                prompt: null,
                description: null,
                agent: null,
                agentName: null,
                attempt: null,
                retryError: null,
              ),
          ],
        ),
      );
    }
    return messages;
  }

  PluginMessageWithParts _toolMessage({
    required String messageId,
    required String sessionId,
    required PluginMessage info,
    required String tool,
    required PluginToolStatus status,
    required String? title,
    required String? output,
  }) {
    final clipped = output != null && output.runes.length > maxToolOutputLength
        ? String.fromCharCodes(output.runes.take(maxToolOutputLength))
        : output;
    return PluginMessageWithParts(
      info: info,
      parts: [
        PluginMessagePart(
          id: "$messageId-tool",
          sessionID: sessionId,
          messageID: messageId,
          type: PluginMessagePartType.tool,
          text: "",
          tool: tool,
          state: PluginToolState(
            status: status,
            title: title,
            output: clipped,
            error: null,
          ),
          prompt: null,
          description: null,
          agent: null,
          agentName: null,
          attempt: null,
          retryError: null,
        ),
      ],
    );
  }

  String _normalizeToolName(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains("patch") || normalized.contains("edit") || normalized.contains("write")) {
      return "edit";
    }
    if (normalized.contains("exec") ||
        normalized.contains("shell") ||
        normalized.contains("bash") ||
        normalized.contains("command")) {
      return "shell";
    }
    return name;
  }

  String? _toolCallTitle(String? argumentsJson) {
    if (argumentsJson == null || argumentsJson.isEmpty) return null;
    try {
      final arguments = CodexToolArgumentsDto.fromJson(
        jsonDecodeMap(argumentsJson),
      );
      for (final value in [
        arguments.cmd,
        arguments.command,
        arguments.path,
        arguments.filePath,
        arguments.query,
      ]) {
        if (value is String && value.isNotEmpty) return value;
        if (value is List && value.isNotEmpty) return value.join(" ");
      }
    } on Object {
      // Fall through to the raw arguments.
    }
    return argumentsJson.length > 120 ? argumentsJson.substring(0, 120) : argumentsJson;
  }

  PluginMessageTime? _messageTimeFrom(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return PluginMessageTime(
      created: parsed.millisecondsSinceEpoch,
      completed: null,
    );
  }
}
