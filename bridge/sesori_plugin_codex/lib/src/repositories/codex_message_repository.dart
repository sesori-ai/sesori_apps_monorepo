import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/codex_rollout_api.dart";
import "../api/models/codex_rollout_dto.dart";
import "../codex_config_reader.dart";
import "../codex_rollout_tool_mapper.dart";

/// Layer-2 mapping from typed rollout transcript DTOs to plugin messages.
class CodexMessageRepository {
  CodexMessageRepository({required CodexRolloutApi rolloutApi}) : _rolloutApi = rolloutApi;

  final CodexRolloutApi _rolloutApi;
  static const CodexRolloutToolMapper _toolMapper = CodexRolloutToolMapper();

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

    final toolOutputs = <String, CodexRolloutToolResult>{};
    for (final line in lines) {
      final payload = line.payload;
      if (payload == null) continue;
      final result = _toolMapper.mapResult(payload);
      if (result != null) toolOutputs[result.callId] = result;
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
        final call = _toolMapper.mapCall(payload);
        if (call == null) continue;
        final result = toolOutputs[call.id];
        messages.add(
          _toolMessage(
            messageId: call.id,
            sessionId: sessionId,
            info: assistantInfo(call.id, messageTime),
            tool: call.tool,
            title: call.title,
            status: result?.status ?? PluginToolStatus.running,
            output: result?.output,
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
        final messageId = _persistedOrLegacyMessageId(
          payload: payload,
          legacyCounter: messageCounter,
        );
        messages.add(
          _toolMessage(
            messageId: messageId,
            sessionId: sessionId,
            info: assistantInfo(messageId, messageTime),
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
        final messageId = _persistedOrLegacyMessageId(
          payload: payload,
          legacyCounter: messageCounter,
        );
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
      final messageId = _persistedOrLegacyMessageId(
        payload: payload,
        legacyCounter: messageCounter,
      );
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
            PluginMessagePart(
              id: "$messageId-text",
              sessionID: sessionId,
              messageID: messageId,
              type: PluginMessagePartType.text,
              text: texts.join(),
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
            output: output,
            error: status == PluginToolStatus.error ? output : null,
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

  String _persistedOrLegacyMessageId({
    required CodexRolloutPayloadDto payload,
    required int legacyCounter,
  }) {
    final persisted = payload.id?.trim();
    if (persisted != null && persisted.isNotEmpty) return persisted;
    // COMPATIBILITY 2026-07-23 (legacy Codex rollouts): older response-item
    // messages can omit `payload.id`. Keep a deterministic replay-local id so
    // those histories remain visible. Remove after histories without persisted
    // response-item ids are no longer supported.
    return "m-$legacyCounter";
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
