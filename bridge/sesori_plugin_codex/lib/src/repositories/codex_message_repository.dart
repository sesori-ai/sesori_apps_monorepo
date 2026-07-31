import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/codex_rollout_api.dart";
import "../api/models/codex_rollout_dto.dart";
import "../codex_config_reader.dart";
import "mappers/codex_rollout_tool_mapper.dart";

/// Layer-2 mapping from typed rollout transcript DTOs to plugin messages.
class CodexMessageRepository {
  CodexMessageRepository({
    required CodexRolloutApi rolloutApi,
    required CodexRolloutToolMapper rolloutToolMapper,
  }) : _rolloutApi = rolloutApi,
       _rolloutToolMapper = rolloutToolMapper;

  final CodexRolloutApi _rolloutApi;
  final CodexRolloutToolMapper _rolloutToolMapper;

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
      if (line case CodexRolloutResponseItemLineDto(payload: final payload)) {
        final result = _rolloutToolMapper.mapResult(payload);
        if (result != null) toolOutputs[result.callId] = result;
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
      final CodexRolloutResponseItemDto payload;
      final String? lineTimestamp;
      switch (line) {
        case CodexRolloutSessionMetadataLineDto(payload: final metadata):
          sessionProvider ??= metadata.modelProvider;
          continue;
        case CodexRolloutTurnContextLineDto(payload: final context):
          final model = context.model;
          if (model != null && model.isNotEmpty) currentModel = model;
          continue;
        case CodexRolloutCompactedLineDto(timestamp: final timestamp):
          messageCounter += 1;
          final messageId = "codex-compaction-$messageCounter";
          messages.add(
            _toolMessage(
              messageId: messageId,
              sessionId: sessionId,
              info: assistantInfo(
                messageId,
                _messageTimeFrom(timestamp),
              ),
              tool: "compact",
              title: "Context compacted",
              status: PluginToolStatus.completed,
              output: null,
              attachments: const [],
            ),
          );
          continue;
        case CodexRolloutResponseItemLineDto(
          payload: final responseItem,
          timestamp: final timestamp,
        ):
          payload = responseItem;
          lineTimestamp = timestamp;
        case CodexRolloutUnknownLineDto():
          continue;
      }
      final messageTime = _messageTimeFrom(lineTimestamp);

      switch (payload) {
        case CodexRolloutFunctionCallDto() || CodexRolloutCustomToolCallDto():
          final call = _rolloutToolMapper.mapCall(payload);
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
              attachments: result?.attachments ?? const [],
            ),
          );
        case CodexRolloutFunctionCallOutputDto() || CodexRolloutCustomToolCallOutputDto():
          continue;
        case CodexRolloutWebSearchCallDto(:final id, :final action):
          messageCounter += 1;
          final messageId = _persistedOrLegacyMessageId(
            persistedId: id,
            legacyCounter: messageCounter,
          );
          messages.add(
            _toolMessage(
              messageId: messageId,
              sessionId: sessionId,
              info: assistantInfo(messageId, messageTime),
              tool: "web_search",
              title: action?.query,
              status: PluginToolStatus.completed,
              output: null,
              attachments: const [],
            ),
          );
        case CodexRolloutImageGenerationDto():
          final generation = _rolloutToolMapper.mapImageGeneration(item: payload);
          messageCounter += 1;
          final messageId = _persistedOrLegacyMessageId(
            persistedId: generation.id,
            legacyCounter: messageCounter,
          );
          messages.add(
            _toolMessage(
              messageId: messageId,
              sessionId: sessionId,
              info: assistantInfo(messageId, messageTime),
              tool: "image_generation",
              title: null,
              status: generation.status,
              output: null,
              attachments: generation.attachments,
            ),
          );
        case CodexRolloutReasoningDto(:final id, :final summary):
          final reasoning = [
            for (final item in summary)
              if (item case CodexRolloutSummaryTextDto(:final text) when text.isNotEmpty) text,
          ].join();
          if (reasoning.isEmpty) continue;

          messageCounter += 1;
          final messageId = _persistedOrLegacyMessageId(
            persistedId: id,
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
                  attachment: null,
                ),
              ],
            ),
          );
        case CodexRolloutMessageDto(:final id, :final role, :final content):
          if (role != CodexRolloutRole.user && role != CodexRolloutRole.assistant) {
            continue;
          }
          final texts = [
            for (final item in content)
              if (item case CodexRolloutInputTextDto(:final text) || CodexRolloutOutputTextDto(:final text)
                  when text.isNotEmpty)
                text,
          ];
          if (texts.isEmpty) continue;

          messageCounter += 1;
          final messageId = _persistedOrLegacyMessageId(
            persistedId: id,
            legacyCounter: messageCounter,
          );
          final info = role == CodexRolloutRole.user
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
                  attachment: null,
                ),
              ],
            ),
          );
        case CodexRolloutUnknownResponseItemDto():
          continue;
      }
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
    required List<PluginMessageAttachment> attachments,
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
            attachments: attachments,
          ),
          prompt: null,
          description: null,
          agent: null,
          agentName: null,
          attempt: null,
          retryError: null,
          attachment: null,
        ),
      ],
    );
  }

  String _persistedOrLegacyMessageId({
    required String? persistedId,
    required int legacyCounter,
  }) {
    final persisted = persistedId?.trim();
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
