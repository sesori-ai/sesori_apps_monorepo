import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/codex_rollout_api.dart";
import "../api/models/codex_rollout_dto.dart";
import "../api/models/codex_sub_agent_item_dto.dart";
import "../codex_config_reader.dart";
import "../models/codex_replay_tool_disposition.dart";
import "codex_sub_agent_tracker.dart";
import "codex_tool_lifecycle_tracker.dart";
import "mappers/codex_rollout_tool_mapper.dart";
import "mappers/codex_session_mapper.dart";
import "mappers/codex_tool_part_mapper.dart";
import "mappers/codex_user_content_mapper.dart";
import "models/codex_projected_tool.dart";
import "models/codex_sub_agent_rollout_fact.dart";
import "models/codex_thread_record.dart";

final class const CodexSubAgentReplayData({
  required final String? initialTurnId,
  required final CodexSubAgentInitialInputFact? initialInput,
  required final PluginToolStatus? terminalStatus,
});

final class CodexPreparedMessageRead({required Iterable<CodexRolloutLineDto> lines}) {
  final List<CodexRolloutLineDto> _lines = List.unmodifiable(lines);

  bool get hasSubtasks => _lines.any(
    (line) => switch (line) {
      CodexRolloutResponseItemLineDto(payload: CodexRolloutFunctionCallDto(name: "spawn_agent")) => true,
      _ => false,
    },
  );
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
    required List<CodexThreadRecord> children,
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
      children: children,
      replayToolDisposition: replayToolDisposition,
      structuredToolStatusByCallId: structuredToolStatusByCallId,
      childReplayDataById: const {},
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
    final ownHistory = trimForkedParentHistory(lines: lines);
    return CodexPreparedMessageRead(lines: _replayThreadRollbacks(lines: ownHistory));
  }

  /// Replays persisted rollback markers over user-turn boundaries.
  ///
  /// An explicit `task_started` begins the turn span removed by rollback, which
  /// also removes that turn's assistant, tool, and completion records. Legacy
  /// rollouts without explicit starts begin the span at the response-item user
  /// message paired with `user_message`. Later records build on the retained
  /// prefix, so repeated markers apply to the already-rolled-back history.
  static List<CodexRolloutLineDto> _replayThreadRollbacks({
    required List<CodexRolloutLineDto> lines,
  }) {
    final replayed = <CodexRolloutLineDto>[];
    final userTurnStarts = <int>[];
    int? activeTurnStart;
    String? activeTurnId;
    var activeTurnHasUser = false;
    int? pendingUserResponseStart;

    for (final line in lines) {
      if (line case CodexRolloutEventMessageLineDto(
        payload: CodexRolloutThreadRolledBackEventDto(:final numTurns),
      )) {
        if (numTurns > 0 && userTurnStarts.isNotEmpty) {
          final firstRemovedTurn = numTurns >= userTurnStarts.length ? 0 : userTurnStarts.length - numTurns;
          final cutIndex = userTurnStarts[firstRemovedTurn];
          replayed.removeRange(cutIndex, replayed.length);
          userTurnStarts.removeRange(firstRemovedTurn, userTurnStarts.length);
        }
        activeTurnStart = null;
        activeTurnId = null;
        activeTurnHasUser = false;
        pendingUserResponseStart = null;
        continue;
      }

      final lineIndex = replayed.length;
      replayed.add(line);
      switch (line) {
        case CodexRolloutEventMessageLineDto(
          payload: CodexRolloutTaskStartedEventDto(:final turnId),
        ):
          activeTurnStart = lineIndex;
          activeTurnId = turnId;
          activeTurnHasUser = false;
          pendingUserResponseStart = null;
        case CodexRolloutResponseItemLineDto(
          payload: CodexRolloutMessageDto(role: CodexRolloutRole.user),
        ):
          pendingUserResponseStart = lineIndex;
        case CodexRolloutEventMessageLineDto(payload: CodexRolloutUserMessageEventDto()):
          if (activeTurnStart case final turnStart?) {
            if (!activeTurnHasUser) {
              userTurnStarts.add(turnStart);
              activeTurnHasUser = true;
            }
          } else {
            userTurnStarts.add(pendingUserResponseStart ?? lineIndex);
          }
          pendingUserResponseStart = null;
        case CodexRolloutEventMessageLineDto(
          payload: CodexRolloutTaskCompleteEventDto(:final turnId),
        ):
          if (activeTurnId == turnId) {
            activeTurnStart = null;
            activeTurnId = null;
            activeTurnHasUser = false;
            pendingUserResponseStart = null;
          }
        case CodexRolloutEventMessageLineDto(payload: CodexRolloutTurnAbortedEventDto(:final turnId)):
          if (turnId == null || activeTurnId == turnId) {
            activeTurnStart = null;
            activeTurnId = null;
            activeTurnHasUser = false;
            pendingUserResponseStart = null;
          }
        case CodexRolloutSessionMetadataLineDto() ||
            CodexRolloutTurnContextLineDto() ||
            CodexRolloutResponseItemLineDto() ||
            CodexRolloutEventMessageLineDto() ||
            CodexRolloutInterAgentCommunicationMetadataLineDto() ||
            CodexRolloutCompactedLineDto() ||
            CodexRolloutUnknownLineDto():
          break;
      }
    }
    return replayed;
  }

  /// Drops the parent history a `fork_turns` sub-agent rollout copies ahead of
  /// its own turns, so a child transcript starts with the child's work.
  ///
  /// codex-cli 0.148.0 writes the copy after the child's leading sub-agent
  /// `session_meta`, beginning with a second `session_meta` for the parent and
  /// continuing through the spawn point. The parent's in-flight turn therefore
  /// appears as a `task_started` with no terminal event before the child's own
  /// first `task_started`; that nested start is where child history begins.
  /// Root forks and malformed rollouts without that leading child metadata are
  /// returned unchanged, as is a copy whose boundary cannot be located.
  static List<CodexRolloutLineDto> trimForkedParentHistory({
    required List<CodexRolloutLineDto> lines,
  }) {
    if (lines.isEmpty ||
        lines.first is! CodexRolloutSessionMetadataLineDto ||
        (lines.first as CodexRolloutSessionMetadataLineDto).payload.threadSource != CodexRolloutThreadSource.subagent) {
      return lines;
    }
    var copyStart = -1;
    for (var index = 1; index < lines.length; index++) {
      if (lines[index] is CodexRolloutSessionMetadataLineDto) {
        copyStart = index;
        break;
      }
    }
    if (copyStart < 0) return lines;
    var openTurn = false;
    for (var index = copyStart + 1; index < lines.length; index++) {
      if (lines[index] case CodexRolloutEventMessageLineDto(:final payload)) {
        switch (payload) {
          case CodexRolloutTaskStartedEventDto():
            if (openTurn) {
              return [...lines.sublist(0, copyStart), ...lines.sublist(index)];
            }
            openTurn = true;
          case CodexRolloutTaskCompleteEventDto() ||
              CodexRolloutTurnAbortedEventDto() ||
              CodexRolloutThreadRolledBackEventDto():
            openTurn = false;
          case CodexRolloutUserMessageEventDto() ||
              CodexRolloutItemCompletedEventDto() ||
              CodexRolloutImageGenerationEndEventDto() ||
              CodexRolloutUnknownEventDto():
            break;
        }
      }
    }
    return lines;
  }

  /// Projects only provenance-safe sub-agent facts from current Codex rollout
  /// records. [previousLine] is supplied by the existing rollout cursor (live)
  /// or the replay scan and proves the native communication marker adjacency.
  CodexSubAgentRolloutFact? subAgentRolloutFact({
    required CodexRolloutLineDto line,
    required CodexRolloutLineDto? previousLine,
  }) {
    if (line case CodexRolloutResponseItemLineDto(:final payload)) {
      final spawn = _rolloutToolMapper.mapSubAgentSpawn(payload: payload);
      if (spawn != null) return spawn;
      if (payload case CodexRolloutAgentMessageDto()) {
        return _initialChildInputFact(message: payload, previousLine: previousLine);
      }
    }
    if (line case CodexRolloutEventMessageLineDto(
      payload: CodexRolloutItemCompletedEventDto(
        item: CodexRolloutCompletedSubAgentActivityDto(
          kind: CodexSubAgentActivityKind.started,
          :final id,
          :final agentThreadId,
          :final agentPath,
        ),
      ),
    )) {
      return CodexSubAgentStartedActivityFact(
        callId: id,
        childThreadId: agentThreadId,
        agentPath: agentPath,
      );
    }
    return null;
  }

  CodexSubAgentReplayData subAgentReplayData({required CodexPreparedMessageRead read}) {
    String? initialTurnId;
    var initialTurnOpen = false;
    CodexSubAgentInitialInputFact? initialInput;
    PluginToolStatus? terminalStatus;
    CodexRolloutLineDto? previousLine;
    for (final line in read._lines) {
      if (line case CodexRolloutEventMessageLineDto(:final payload)) {
        switch (payload) {
          case CodexRolloutTaskStartedEventDto(:final turnId):
            if (initialTurnId == null) {
              initialTurnId = turnId;
              initialTurnOpen = true;
            }
          case CodexRolloutTaskCompleteEventDto(:final turnId, :final error):
            if (terminalStatus == null && turnId == initialTurnId) {
              terminalStatus = error == null ? PluginToolStatus.completed : PluginToolStatus.error;
              initialTurnOpen = false;
            }
          case CodexRolloutTurnAbortedEventDto(:final turnId):
            if (terminalStatus == null && initialTurnOpen && (turnId == null || turnId == initialTurnId)) {
              terminalStatus = PluginToolStatus.cancelled;
              initialTurnOpen = false;
            }
          case CodexRolloutUserMessageEventDto() ||
              CodexRolloutItemCompletedEventDto() ||
              CodexRolloutImageGenerationEndEventDto() ||
              CodexRolloutThreadRolledBackEventDto() ||
              CodexRolloutUnknownEventDto():
            break;
        }
      }
      final fact = subAgentRolloutFact(line: line, previousLine: previousLine);
      if (fact case CodexSubAgentInitialInputFact(:final turnId, :final input) when turnId == initialTurnId) {
        if (initialInput == null ||
            initialInput.input is CodexSubAgentEncryptedInput && input is CodexSubAgentPlaintextInput) {
          initialInput = fact;
        }
      }
      previousLine = line;
    }
    return CodexSubAgentReplayData(
      initialTurnId: initialTurnId,
      initialInput: initialInput,
      terminalStatus: terminalStatus,
    );
  }

  CodexSubAgentInitialInputFact? _initialChildInputFact({
    required CodexRolloutAgentMessageDto message,
    required CodexRolloutLineDto? previousLine,
  }) {
    if (previousLine case CodexRolloutInterAgentCommunicationMetadataLineDto(
      payload: CodexRolloutInterAgentCommunicationMetadataDto(triggerTurn: true),
    )) {
      final turnId = _exactNonBlank(message.metadata?.turnId);
      if (turnId == null) return null;
      if (message.content.any((content) => content is CodexRolloutAgentMessageEncryptedContentDto)) {
        return CodexSubAgentInitialInputFact(
          turnId: turnId,
          input: const CodexSubAgentEncryptedInput(),
        );
      }
      if (message.content.any((content) => content is! CodexRolloutAgentMessageInputTextDto)) return null;
      final plaintext = message.content
          .whereType<CodexRolloutAgentMessageInputTextDto>()
          .map((content) => content.text)
          .join("\n");
      final payload = _parsePlaintextNewTask(
        text: plaintext,
        author: message.author,
        recipient: message.recipient,
      );
      if (payload == null) return null;
      return CodexSubAgentInitialInputFact(
        turnId: turnId,
        input: CodexSubAgentPlaintextInput(message: payload),
      );
    }
    return null;
  }

  String? _parsePlaintextNewTask({
    required String text,
    required String author,
    required String recipient,
  }) {
    final match = RegExp(
      r"^Message Type: NEW_TASK\nTask name: ([^\n]+)\nSender: ([^\n]+)\nPayload:\n([\s\S]*)$",
    ).firstMatch(text);
    if (match == null || match.group(1) != recipient || match.group(2) != author) return null;
    return _exactNonBlank(match.group(3));
  }

  String? _exactNonBlank(String? value) => value == null || value.trim().isEmpty ? null : value;

  List<PluginMessageWithParts> projectMessages({
    required CodexPreparedMessageRead read,
    required String sessionId,
    required List<CodexThreadRecord> children,
    required CodexReplayToolDisposition replayToolDisposition,
    required Map<String, PluginToolStatus> structuredToolStatusByCallId,
    required Map<String, CodexSubAgentReplayData> childReplayDataById,
    CodexConfigDefaults config = const CodexConfigDefaults.empty(),
  }) {
    final lines = read._lines;

    final toolTracker = CodexToolLifecycleTracker(
      rolloutToolMapper: _rolloutToolMapper,
    );
    final subAgentTracker = CodexSubAgentTracker();
    for (final child in children) {
      subAgentTracker.record(child: child);
    }
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
      if (subAgentTracker.hasRenderedTile(parentId: sessionId, callId: tool.canonicalId)) return;
      final existingIndex = toolMessageIndexById[tool.canonicalId];
      final info = existingIndex == null
          ? assistantInfo(
              id: tool.canonicalId,
              time: _messageTimeFrom(timestamp),
            )
          : messages[existingIndex]!.info;
      final message = PluginMessageWithParts(
        info: info,
        parts: [
          const CodexToolPartMapper().map(
            sessionId: sessionId,
            tool: CodexProjectedTool(
              canonicalId: tool.canonicalId,
              tool: tool.tool,
              presentation: tool.presentation,
              title: tool.title,
              status: structuredToolStatusByCallId[tool.canonicalId] ?? tool.status,
              output: tool.output,
              time: tool.time,
              attachments: tool.attachments,
            ),
          ),
        ],
      );
      if (existingIndex == null) {
        toolMessageIndexById[tool.canonicalId] = messages.length;
        messages.add(message);
      } else {
        messages[existingIndex] = message;
      }
    }

    void upsertSubAgent({
      required CodexTrackedSubAgent task,
      required String? timestamp,
    }) {
      final existingIndex = toolMessageIndexById[task.callId];
      final info = existingIndex == null
          ? assistantInfo(id: task.callId, time: _messageTimeFrom(timestamp))
          : messages[existingIndex]!.info;
      final message = PluginMessageWithParts(
        info: info,
        parts: [const CodexSessionMapper().mapSubAgentTile(task: task).part],
      );
      if (existingIndex == null) {
        toolMessageIndexById[task.callId] = messages.length;
        messages.add(message);
      } else {
        messages[existingIndex] = message;
      }
    }

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final lineTimestamp = _lineTimestamp(line);
      final subAgentFact = subAgentRolloutFact(
        line: line,
        previousLine: lineIndex == 0 ? null : lines[lineIndex - 1],
      );
      for (final tool in toolTracker.observeRolloutLine(threadId: sessionId, line: line)) {
        upsertTool(tool: tool, timestamp: lineTimestamp);
      }
      switch (subAgentFact) {
        case CodexSubAgentSpawnFact():
          final task = subAgentTracker.observeSpawn(parentId: sessionId, fact: subAgentFact);
          if (task != null) upsertSubAgent(task: task, timestamp: lineTimestamp);
        case CodexSubAgentStartedActivityFact(:final callId, :final childThreadId):
          CodexThreadRecord? child;
          for (final candidate in children) {
            if (candidate.id == childThreadId) {
              child = candidate;
              break;
            }
          }
          if (child != null) {
            final replay = childReplayDataById[child.id];
            final task = subAgentTracker.observeStarted(
              child: child,
              callId: callId,
              status: replay?.terminalStatus ?? PluginToolStatus.running,
            );
            if (task != null) upsertSubAgent(task: task, timestamp: lineTimestamp);
            final initialTurnId = replay?.initialTurnId;
            if (initialTurnId != null) {
              subAgentTracker.observeTurnStarted(childId: child.id, turnId: initialTurnId);
            }
            final input = replay?.initialInput;
            if (input != null) {
              final updated = subAgentTracker.observeInitialInput(childId: child.id, fact: input);
              if (updated != null) upsertSubAgent(task: updated, timestamp: lineTimestamp);
            }
          }
        case CodexSubAgentInitialInputFact() || null:
          break;
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
        case CodexRolloutInterAgentCommunicationMetadataLineDto():
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
        case CodexRolloutAgentMessageDto():
          continue;
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
      CodexRolloutInterAgentCommunicationMetadataLineDto(:final timestamp) ||
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
