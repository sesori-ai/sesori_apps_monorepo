import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/codex_rollout_api.dart";
import "../api/models/codex_rollout_dto.dart";
import "../codex_config_reader.dart";
import "../models/codex_replay_tool_disposition.dart";
import "codex_tool_lifecycle_tracker.dart";
import "mappers/codex_rollout_tool_mapper.dart";
import "mappers/codex_user_content_mapper.dart";
import "models/codex_projected_tool.dart";

final class CodexPreparedMessageRead({required Iterable<CodexRolloutLineDto> lines}) {
  final List<CodexRolloutLineDto> _lines = List.unmodifiable(lines);
}

/// Layer-2 mapping from typed rollout transcript DTOs to plugin messages.
class CodexMessageRepository({
  required final CodexRolloutApi _rolloutApi,
  required final CodexRolloutToolMapper _rolloutToolMapper,
  required final CodexUserContentMapper _userContentMapper,
}) {
  List<PluginMessageWithParts> readMessages({
    required String rolloutPath,
    required String sessionId,
    required CodexReplayToolDisposition replayToolDisposition,
    required Map<String, PluginToolStatus> structuredToolStatusByCallId,
    CodexConfigDefaults config = const CodexConfigDefaults.empty(),
  }) {
    return projectMessages(
      read: prepareMessageRead(
        rolloutPath: rolloutPath,
        sessionId: sessionId,
      ),
      sessionId: sessionId,
      replayToolDisposition: replayToolDisposition,
      structuredToolStatusByCallId: structuredToolStatusByCallId,
      config: config,
    );
  }

  CodexPreparedMessageRead prepareMessageRead({
    required String rolloutPath,
    required String sessionId,
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
    return CodexPreparedMessageRead(lines: lines);
  }

  List<PluginMessageWithParts> projectMessages({
    required CodexPreparedMessageRead read,
    required String sessionId,
    required CodexReplayToolDisposition replayToolDisposition,
    required Map<String, PluginToolStatus> structuredToolStatusByCallId,
    CodexConfigDefaults config = const CodexConfigDefaults.empty(),
  }) {
    final lines = read._lines;

    final toolTracker = CodexToolLifecycleTracker(
      rolloutToolMapper: _rolloutToolMapper,
    );
    toolTracker.prepareRolloutReplay(
      threadId: sessionId,
      lines: lines,
    );
    final messages = <PluginMessageWithParts?>[];
    final toolMessageIndexById = <String, int>{};
    final pendingUserMessages = <_PendingUserMessage>[];
    var messageCounter = 0;
    String? sessionProvider;
    String? currentModel;
    String? currentVariant;

    PluginMessage assistantInfo({
      required String id,
      required PluginMessageTime? time,
    }) => PluginMessage.assistant(
      id: id,
      sessionID: sessionId,
      agent: "codex",
      modelID: currentModel ?? config.model,
      providerID: sessionProvider ?? config.modelProvider ?? "openai",
      variant: currentVariant,
      sender: PluginMessageSender.agent,
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
        status: structuredToolStatusByCallId[tool.canonicalId] ?? tool.status,
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
        final submittedText = _userContentMapper.mapSubmittedText(
          text: submittedMessage,
        );
        _PendingUserMessage? pending;
        for (var index = pendingUserMessages.length - 1; index >= 0; index--) {
          final candidate = pendingUserMessages[index];
          if (!candidate.resolved) {
            pending = candidate;
            break;
          }
        }
        if (pending == null) {
          if (submittedText == null) continue;
          messageCounter += 1;
          final messageId = _persistedOrLegacyMessageId(
            persistedId: null,
            legacyCounter: messageCounter,
          );
          messages.add(
            _textMessage(
              info: PluginMessage.user(
                id: messageId,
                sessionID: sessionId,
                agent: null,
                time: _messageTimeFrom(lineTimestamp),
                promptId: null,
              ),
              messageId: messageId,
              sessionId: sessionId,
              text: submittedText,
              attachments: const [],
            ),
          );
        } else {
          if (submittedText == null && pending.attachments.isEmpty) {
            pending.resolved = true;
            continue;
          }
          final legacyCounter = pending.legacyCounter ?? (messageCounter += 1);
          final messageId = _persistedOrLegacyMessageId(
            persistedId: pending.persistedId,
            legacyCounter: legacyCounter,
          );
          messages[pending.slot] = _textMessage(
            info: PluginMessage.user(
              id: messageId,
              sessionID: sessionId,
              agent: null,
              time: pending.time,
              promptId: null,
            ),
            messageId: messageId,
            sessionId: sessionId,
            text: submittedText,
            attachments: pending.attachments,
          );
          pending.resolved = true;
        }
      }
      if (line
          case CodexRolloutEventMessageLineDto(
            payload: CodexRolloutTaskCompleteEventDto(:final turnId, error: final error?),
          )
          when error.message.trim().isNotEmpty) {
        messages.add(
          PluginMessageWithParts(
            info: PluginMessage.error(
              id: turnId,
              sessionID: sessionId,
              agent: "codex",
              modelID: currentModel ?? config.model,
              providerID: sessionProvider ?? config.modelProvider ?? "openai",
              variant: currentVariant,
              errorName: "CodexError",
              errorMessage: error.message,
              time: _messageTimeFrom(lineTimestamp),
            ),
            parts: const [],
          ),
        );
      }

      final CodexRolloutResponseItemDto payload;
      switch (line) {
        case CodexRolloutSessionMetadataLineDto(payload: final metadata):
          sessionProvider ??= metadata.modelProvider;
          continue;
        case CodexRolloutTurnContextLineDto(payload: final context):
          final model = context.model;
          if (model != null && model.isNotEmpty) currentModel = model;
          final effort = context.effort?.trim();
          currentVariant = effort == null || effort.isEmpty ? null : effort;
          continue;
        case CodexRolloutCompactedLineDto(:final timestamp):
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
          if (!toolTracker.shouldReplayLegacyImage(
            threadId: sessionId,
            image: payload,
          )) {
            continue;
          }
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
              status:
                  generation.status == PluginToolStatus.running &&
                      replayToolDisposition == CodexReplayToolDisposition.terminalize
                  ? PluginToolStatus.error
                  : generation.status,
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
                PluginMessagePart.reasoning(
                  id: "$messageId-reasoning",
                  sessionID: sessionId,
                  messageID: messageId,
                  text: reasoning,
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
          final attachments = role == CodexRolloutRole.user
              ? _rolloutToolMapper.mapContentAttachments(content: content)
              : const <PluginMessageAttachment>[];
          if (texts.isEmpty && attachments.isEmpty) continue;
          if (role == CodexRolloutRole.user) {
            final fallbackText = _userVisibleText(content: content);
            final legacyCounter = fallbackText == null && attachments.isEmpty ? null : (messageCounter += 1);
            pendingUserMessages.add(
              _PendingUserMessage(
                slot: messages.length,
                persistedId: id,
                fallbackText: fallbackText,
                attachments: attachments,
                legacyCounter: legacyCounter,
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
                  promptId: null,
                )
              : assistantInfo(id: messageId, time: messageTime);
          messages.add(
            _textMessage(
              info: info,
              messageId: messageId,
              sessionId: sessionId,
              text: texts.join(),
              attachments: const [],
            ),
          );
        case CodexRolloutUnknownResponseItemDto():
          continue;
      }
    }
    for (final tool in toolTracker.finishRolloutReplay(
      threadId: sessionId,
      disposition: replayToolDisposition,
    )) {
      upsertTool(tool: tool, timestamp: null);
    }
    for (final pending in pendingUserMessages) {
      final fallbackText = pending.fallbackText;
      final legacyCounter = pending.legacyCounter;
      if (pending.resolved || legacyCounter == null || (fallbackText == null && pending.attachments.isEmpty)) {
        continue;
      }
      final messageId = _persistedOrLegacyMessageId(
        persistedId: pending.persistedId,
        legacyCounter: legacyCounter,
      );
      messages[pending.slot] = _textMessage(
        info: PluginMessage.user(
          id: messageId,
          sessionID: sessionId,
          agent: null,
          time: pending.time,
          promptId: null,
        ),
        messageId: messageId,
        sessionId: sessionId,
        text: fallbackText,
        attachments: pending.attachments,
      );
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

  String? _userVisibleText({
    required List<CodexRolloutContentDto> content,
  }) {
    return _userContentMapper.mapContentText(
      textParts: [
        for (final item in content)
          if (item case CodexRolloutInputTextDto(:final text)) text,
      ],
    );
  }

  PluginMessageWithParts _textMessage({
    required PluginMessage info,
    required String messageId,
    required String sessionId,
    required String? text,
    required List<PluginMessageAttachment> attachments,
  }) {
    return PluginMessageWithParts(
      info: info,
      parts: [
        if (text != null)
          PluginMessagePart.text(
            id: "$messageId-text",
            sessionID: sessionId,
            messageID: messageId,
            text: text,
          ),
        for (var index = 0; index < attachments.length; index++)
          PluginMessagePart.file(
            id: "$messageId-file-${index + 1}",
            sessionID: sessionId,
            messageID: messageId,
            attachment: attachments[index],
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
        PluginMessagePart.tool(
          id: "$messageId-tool",
          sessionID: sessionId,
          messageID: messageId,
          tool: tool,
          state: PluginToolState(
            status: status,
            title: title,
            shellCommand: tool == "shell" ? title : null,
            output: output,
            error: status == PluginToolStatus.error ? output : null,
            attachments: attachments,
          ),
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

class _PendingUserMessage({
  required final int slot,
  required final String? persistedId,
  required final String? fallbackText,
  required final List<PluginMessageAttachment> attachments,
  required final int? legacyCounter,
  required final PluginMessageTime? time,
}) {
  bool resolved = false;
}
