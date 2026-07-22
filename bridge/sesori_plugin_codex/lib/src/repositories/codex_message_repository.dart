import "dart:convert";

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

    final toolOutputs = <String, String?>{};
    for (final line in lines) {
      final payload = line.payload;
      if (payload?.type != CodexRolloutPayloadType.functionCallOutput &&
          payload?.type != CodexRolloutPayloadType.customToolCallOutput) {
        continue;
      }
      final callId = payload?.callId;
      if (callId != null && payload?.output != null) {
        toolOutputs[callId] = _toolOutputText(payload?.output);
      }
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

      if (payload.type == CodexRolloutPayloadType.functionCall ||
          payload.type == CodexRolloutPayloadType.customToolCall) {
        final callId = payload.callId;
        final name = payload.name ?? "tool";
        final output = callId == null ? null : toolOutputs[callId];
        final completed = callId != null && toolOutputs.containsKey(callId);
        messageCounter += 1;
        messages.add(
          _toolMessage(
            messageId: "m-$messageCounter",
            sessionId: sessionId,
            info: assistantInfo("m-$messageCounter", messageTime),
            tool: _normalizeToolName(name),
            title: _toolCallTitle(payload.arguments ?? payload.input),
            status: completed ? PluginToolStatus.completed : PluginToolStatus.running,
            output: output,
          ),
        );
        continue;
      }
      if (payload.type == CodexRolloutPayloadType.functionCallOutput ||
          payload.type == CodexRolloutPayloadType.customToolCallOutput) {
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

      if (payload.type == CodexRolloutPayloadType.reasoning) {
        final reasoning = _contentTexts(
          payload.summary,
          acceptedTypes: const {CodexRolloutContentType.summaryText},
        ).join();
        if (reasoning.isEmpty) continue;

        messageCounter += 1;
        final messageId = "m-$messageCounter";
        messages.add(
          PluginMessageWithParts(
            info: assistantInfo(messageId, messageTime),
            parts: [
              PluginMessagePart(
                id: "$messageId-reasoning",
                sessionID: sessionId,
                messageID: messageId,
                type: PluginMessagePartType.reasoning,
                text: reasoning,
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
        continue;
      }

      if (payload.role != CodexRolloutRole.user && payload.role != CodexRolloutRole.assistant) {
        continue;
      }
      final texts = _contentTexts(
        payload.content,
        acceptedTypes: const {
          CodexRolloutContentType.inputText,
          CodexRolloutContentType.outputText,
        },
      );
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

  String? _toolOutputText(List<CodexRolloutContentDto>? output) {
    final texts = _contentTexts(
      output,
      acceptedTypes: const {
        CodexRolloutContentType.inputText,
        CodexRolloutContentType.outputText,
      },
    );
    return texts.isEmpty ? null : texts.join();
  }

  List<String> _contentTexts(
    List<CodexRolloutContentDto>? content, {
    required Set<CodexRolloutContentType> acceptedTypes,
  }) {
    return [
      for (final item in content ?? const <CodexRolloutContentDto>[])
        if (item.text case final text? when acceptedTypes.contains(item.type) && text.isNotEmpty) text,
    ];
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
    final arguments = _tryDecodeToolArguments(raw: argumentsJson);
    if (arguments != null) {
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
    }
    final embeddedCommand = _embeddedExecCommand(source: argumentsJson);
    if (embeddedCommand != null && embeddedCommand.isNotEmpty) {
      return embeddedCommand;
    }
    return argumentsJson.length > 120 ? argumentsJson.substring(0, 120) : argumentsJson;
  }

  CodexToolArgumentsDto? _tryDecodeToolArguments({required String raw}) {
    try {
      return CodexToolArgumentsDto.fromJson(jsonDecodeMap(raw));
    } on Object {
      return null;
    }
  }

  String? _embeddedExecCommand({required String source}) {
    const marker = "tools.exec_command(";
    final markerIndex = source.indexOf(marker);
    if (markerIndex < 0) return null;

    final argumentsStart = markerIndex + marker.length;
    final commandMatch = RegExp(
      r'(?:^|[,{]\s*)(?:"cmd"|cmd)\s*:\s*',
    ).firstMatch(source.substring(argumentsStart));
    if (commandMatch == null) return null;
    final valueStart = argumentsStart + commandMatch.end;
    if (valueStart >= source.length || source.codeUnitAt(valueStart) != 0x22) {
      return null;
    }

    var escaped = false;
    for (var index = valueStart + 1; index < source.length; index++) {
      final codeUnit = source.codeUnitAt(index);
      if (escaped) {
        escaped = false;
      } else if (codeUnit == 0x5C) {
        escaped = true;
      } else if (codeUnit == 0x22) {
        try {
          final decoded = jsonDecode(source.substring(valueStart, index + 1));
          return decoded is String ? decoded : null;
        } on FormatException {
          return null;
        }
      }
    }
    return null;
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
