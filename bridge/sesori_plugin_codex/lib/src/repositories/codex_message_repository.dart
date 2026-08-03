import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/codex_rollout_api.dart";
import "../api/models/codex_rollout_dto.dart";
import "../codex_config_reader.dart";
import "codex_tool_lifecycle_tracker.dart";
import "mappers/codex_rollout_tool_mapper.dart";
import "models/codex_projected_tool.dart";

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

    final toolTracker = CodexToolLifecycleTracker(
      rolloutToolMapper: _rolloutToolMapper,
    );
    final messages = <PluginMessageWithParts?>[];
    final toolMessageIndexById = <String, int>{};
    final submittedUserMessages = <String>{};
    final pendingGeneratedUserMessages = <_PendingGeneratedUserMessage>[];
    var messageCounter = 0;
    String? sessionProvider;
    String? currentModel;

    PluginMessage assistantInfo({
      required String id,
      required PluginMessageTime? time,
    }) => PluginMessage.assistant(
      id: id,
      sessionID: sessionId,
      agent: "codex",
      modelID: currentModel ?? config.model,
      providerID: sessionProvider ?? config.modelProvider ?? "openai",
      time: time,
    );

    void upsertTool({
      required CodexProjectedTool tool,
      required String? timestamp,
    }) {
      final existingIndex = toolMessageIndexById[tool.canonicalId];
      final info = existingIndex == null
          ? assistantInfo(
              id: tool.canonicalId,
              time: _messageTimeFrom(timestamp),
            )
          : messages[existingIndex]!.info;
      final message = _toolMessage(
        messageId: tool.canonicalId,
        sessionId: sessionId,
        info: info,
        tool: tool.tool,
        title: tool.title,
        status: tool.status,
        output: tool.output,
        attachments: tool.attachments,
      );
      if (existingIndex == null) {
        toolMessageIndexById[tool.canonicalId] = messages.length;
        messages.add(message);
      } else {
        messages[existingIndex] = message;
      }
    }

    for (final line in lines) {
      final lineTimestamp = _lineTimestamp(line);
      for (final tool in toolTracker.observeRolloutLine(threadId: sessionId, line: line)) {
        upsertTool(tool: tool, timestamp: lineTimestamp);
      }
      if (line case CodexRolloutEventMessageLineDto(
        payload: CodexRolloutUserMessageEventDto(message: final submittedMessage),
      )) {
        submittedUserMessages.add(submittedMessage);
        for (final pending in pendingGeneratedUserMessages) {
          if (pending.resolved || pending.submittedText != submittedMessage) {
            continue;
          }
          messageCounter += 1;
          final messageId = _persistedOrLegacyMessageId(
            persistedId: pending.persistedId,
            legacyCounter: messageCounter,
          );
          messages[pending.slot] = _textMessage(
            info: PluginMessage.user(
              id: messageId,
              sessionID: sessionId,
              agent: null,
              time: pending.time,
            ),
            messageId: messageId,
            sessionId: sessionId,
            text: pending.text,
          );
          pending.resolved = true;
        }
      }

      final CodexRolloutResponseItemDto payload;
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
                id: messageId,
                time: _messageTimeFrom(timestamp),
              ),
              tool: "compact",
              title: "Context compacted",
              status: PluginToolStatus.completed,
              output: null,
              attachments: const [],
            ),
          );
          continue;
        case CodexRolloutEventMessageLineDto():
          continue;
        case CodexRolloutResponseItemLineDto(
          payload: final responseItem,
        ):
          payload = responseItem;
        case CodexRolloutUnknownLineDto():
          continue;
      }
      final messageTime = _messageTimeFrom(lineTimestamp);

      switch (payload) {
        case CodexRolloutFunctionCallDto() || CodexRolloutCustomToolCallDto():
          continue;
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
              info: assistantInfo(id: messageId, time: messageTime),
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
          if (generation.id != null) continue;
          final messageId = _persistedOrLegacyMessageId(
            persistedId: generation.id,
            legacyCounter: messageCounter,
          );
          messages.add(
            _toolMessage(
              messageId: messageId,
              sessionId: sessionId,
              info: assistantInfo(id: messageId, time: messageTime),
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
              info: assistantInfo(id: messageId, time: messageTime),
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
          final submittedText = _firstInputText(content: content);
          if (role == CodexRolloutRole.user &&
              !submittedUserMessages.contains(submittedText) &&
              _isGeneratedUserContext(content: content)) {
            pendingGeneratedUserMessages.add(
              _PendingGeneratedUserMessage(
                slot: messages.length,
                persistedId: id,
                submittedText: submittedText,
                text: texts.join(),
                time: messageTime,
              ),
            );
            messages.add(null);
            continue;
          }

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
              : assistantInfo(id: messageId, time: messageTime);
          messages.add(
            _textMessage(
              info: info,
              messageId: messageId,
              sessionId: sessionId,
              text: texts.join(),
            ),
          );
        case CodexRolloutUnknownResponseItemDto():
          continue;
      }
    }
    return [for (final message in messages) ?message];
  }

  String? _lineTimestamp(CodexRolloutLineDto line) {
    return switch (line) {
      CodexRolloutSessionMetadataLineDto(:final timestamp) ||
      CodexRolloutTurnContextLineDto(:final timestamp) ||
      CodexRolloutResponseItemLineDto(:final timestamp) ||
      CodexRolloutEventMessageLineDto(:final timestamp) ||
      CodexRolloutCompactedLineDto(:final timestamp) ||
      CodexRolloutUnknownLineDto(:final timestamp) => timestamp,
    };
  }

  String? _firstInputText({required List<CodexRolloutContentDto> content}) {
    for (final item in content) {
      if (item case CodexRolloutInputTextDto(:final text)) return text;
    }
    return null;
  }

  bool _isGeneratedUserContext({
    required List<CodexRolloutContentDto> content,
  }) {
    if (content.isEmpty || content.any((item) => item is! CodexRolloutInputTextDto)) {
      return false;
    }
    final texts = [
      for (final item in content)
        if (item case CodexRolloutInputTextDto(:final text)) text.trim(),
    ];
    return texts.every((text) => _GeneratedContextTag.values.any((tag) => tag.wraps(text)));
  }

  PluginMessageWithParts _textMessage({
    required PluginMessage info,
    required String messageId,
    required String sessionId,
    required String text,
  }) {
    return PluginMessageWithParts(
      info: info,
      parts: [
        PluginMessagePart(
          id: "$messageId-text",
          sessionID: sessionId,
          messageID: messageId,
          type: PluginMessagePartType.text,
          text: text,
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
    );
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

enum _GeneratedContextTag {
  recommendedPlugins("recommended_plugins"),
  environmentContext("environment_context"),
  turnAborted("turn_aborted");

  const _GeneratedContextTag(this.wireName);

  final String wireName;

  bool wraps(String text) => text.startsWith("<$wireName>") && text.endsWith("</$wireName>");
}

class _PendingGeneratedUserMessage {
  _PendingGeneratedUserMessage({
    required this.slot,
    required this.persistedId,
    required this.submittedText,
    required this.text,
    required this.time,
  });

  final int slot;
  final String? persistedId;
  final String? submittedText;
  final String text;
  final PluginMessageTime? time;
  bool resolved = false;
}
