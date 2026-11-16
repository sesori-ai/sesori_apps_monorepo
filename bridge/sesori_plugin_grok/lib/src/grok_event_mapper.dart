import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/models/grok_session_notification_dto.dart";
import "repositories/mappers/grok_subagent_status_mapping.dart";
import "trackers/grok_compaction_tracker.dart";

/// Grok Build's ACP mapper: the base session/update handling plus the Grok
/// extension sub-agent lifecycle, pushed into the shared child-session tracker,
/// and the live compaction row.
class GrokEventMapper({
  required super.launchDirectory,
  required super.pluginId,
  required super.configurationTracker,
  required super.childSessions,
  required final GrokCompactionTracker compactionTracker,
}) extends AcpEventMapper {
  /// The `spawn_subagent` call and the `subagent_spawned` notification share
  /// no id, so the call renders nothing and the notification owns the tile.
  @override
  bool isSubagentSpawnToolCall({required Map<String, dynamic> update}) =>
      GrokSessionProtocol.isSpawnSubagentUpdate(update: update);

  @override
  String? shellCommandForToolUpdate({required Map<String, dynamic> update}) {
    final meta = update["_meta"];
    final input = update["rawInput"];
    if (meta is! Map<String, dynamic> || input is! Map<String, dynamic>) return null;
    try {
      if (GrokToolCallMetaDto.fromJson(meta).tool?.name != "run_terminal_command") return null;
      final command = GrokTerminalInputDto.fromJson(input).command?.trim();
      return command == null || command.isEmpty ? null : command;
    } on Object catch (error, stackTrace) {
      Log.w("[grok] malformed terminal command; retaining ordinary tool handling", error, stackTrace);
      return null;
    }
  }

  /// Grok answers a turn's prompt only after its compaction ends, so a
  /// compaction still recorded here lost its end, and the bridge's idle sweep
  /// settles its row. A stopped compaction sends no end of its own.
  @override
  List<BridgeSseEvent> finalizeTurn({required String sessionId}) {
    compactionTracker.forgetSession(sessionId: sessionId);
    return super.finalizeTurn(sessionId: sessionId);
  }

  @override
  void forgetSession(String sessionId) {
    compactionTracker.forgetSession(sessionId: sessionId);
    super.forgetSession(sessionId);
  }

  @override
  bool shouldBufferDuringPromptWrite({required AcpNotification notification}) =>
      // A compaction at the start of a prompt must not reach the client before
      // the accepted user message.
      notification.method == GrokSessionProtocol.notificationMethod ||
      notification.method == GrokSessionProtocol.queueChangedMethod ||
      super.shouldBufferDuringPromptWrite(notification: notification);

  @override
  List<BridgeSseEvent> mapExtension(AcpNotification notification) {
    if (notification.method == GrokSessionProtocol.queueChangedMethod) {
      return _mapQueueChanged(notification: notification);
    }
    if (notification.method != GrokSessionProtocol.notificationMethod &&
        notification.method != GrokSessionProtocol.updateMethod) {
      return super.mapExtension(notification);
    }
    final GrokSessionNotificationDto dto;
    try {
      dto = GrokSessionNotificationDto.fromJson(notification.params);
    } on Object catch (error, stackTrace) {
      Log.w("[grok] ignored malformed session notification", error, stackTrace);
      return const [];
    }
    return switch (dto.update) {
      GrokSubagentSpawned(:final childSessionId, :final subagentType, :final description, :final model) => _spawned(
        sessionId: dto.sessionId,
        childSessionId: childSessionId,
        model: model,
        spawn: AcpChildSpawn(
          childSessionId: childSessionId,
          description: description,
          agent: subagentType ?? GrokSessionProtocol.defaultSubagentType,
          // The notification carries no prompt: the child's own first user
          // message supplies it. It carries no launch mode either, and a root
          // `session/cancel` stops background children too, so every child is
          // honestly a foreground one for the stop policy.
          prompt: null,
          isBackground: false,
        ),
      ),
      GrokSubagentFinished(
        :final childSessionId,
        :final status,
        :final output,
        :final error,
        willWake: true,
      ) =>
        mapChildFinishedAndHoldRoot(
          childSessionId: childSessionId,
          holdId: childSessionId,
          status: status.toPluginToolStatus(),
          output: output,
          error: error,
        ),
      GrokSubagentFinished(:final childSessionId, :final status, :final output, :final error) => mapChildFinished(
        childSessionId: childSessionId,
        status: status.toPluginToolStatus(),
        output: output,
        error: error,
      ),
      GrokTurnCompleted(:final promptId) => _releaseAutonomousRootTurn(
        rootSessionId: dto.sessionId,
        promptId: promptId,
      ),
      GrokAutoCompactStarted() => _compactionRow(
        sessionId: dto.sessionId,
        compaction: compactionTracker.start(
          sessionId: dto.sessionId,
          key: dto.meta?.eventId,
          startedAtMs: dto.meta?.agentTimestampMs,
          trigger: .auto,
        ),
        state: const .running(summary: null),
      ),
      GrokAutoCompactCompleted(:final tokensBefore, :final tokensAfter) => _mapCompactionCompleted(
        sessionId: dto.sessionId,
        tokensBefore: tokensBefore,
        tokensAfter: tokensAfter,
      ),
      GrokAutoCompactFailed(:final error) => _mapCompactionFailed(sessionId: dto.sessionId, error: error),
      // One child is one tile; progress never redraws it.
      GrokSubagentProgress() || GrokSubagentUpdateUnknown() => const [],
    };
  }

  /// A manual `/compact` starts when Grok runs it from its queue.
  List<BridgeSseEvent> _mapQueueChanged({required AcpNotification notification}) {
    final GrokQueueChangedDto queue;
    try {
      queue = GrokQueueChangedDto.fromJson(notification.params);
    } on Object catch (error, stackTrace) {
      Log.w("[grok] ignored malformed queue notification", error, stackTrace);
      return const [];
    }
    if (!GrokSessionProtocol.isCompactCommand(text: queue.runningText)) return const [];
    return _compactionRow(
      sessionId: queue.sessionId,
      // The queue entry carries no time.
      compaction: compactionTracker.start(
        sessionId: queue.sessionId,
        key: queue.runningPromptId,
        startedAtMs: null,
        trigger: .manual,
      ),
      state: const .running(summary: null),
    );
  }

  /// A completion with no recorded start keeps only the session event.
  List<BridgeSseEvent> _mapCompactionCompleted({
    required String sessionId,
    required int? tokensBefore,
    required int? tokensAfter,
  }) {
    final compaction = compactionTracker.finish(sessionId: sessionId);
    return [
      if (compaction != null)
        ..._compactionRow(
          sessionId: sessionId,
          compaction: compaction,
          // Grok reports no summary over ACP.
          state: .completed(
            summary: null,
            freedTokens: GrokSessionProtocol.freedTokens(tokensBefore: tokensBefore, tokensAfter: tokensAfter),
            trigger: compaction.trigger,
          ),
        ),
      BridgeSseSessionCompacted(sessionID: sessionId),
    ];
  }

  List<BridgeSseEvent> _mapCompactionFailed({required String sessionId, required String? error}) {
    Log.w("[grok] automatic compaction in $sessionId failed: $error");
    final compaction = compactionTracker.finish(sessionId: sessionId);
    if (compaction == null) return const [];
    // Grok's error is free-form API text, so the note names no reason.
    return _compactionRow(sessionId: sessionId, compaction: compaction, state: const .failed(reason: null));
  }

  /// The live compaction row: one agent message stamped at the start, with
  /// one part that settles in place.
  List<BridgeSseEvent> _compactionRow({
    required String sessionId,
    required GrokRunningCompaction compaction,
    required PluginCompactionState state,
  }) => [
    BridgeSseMessageUpdated(
      info: PluginMessage.assistant(
        id: compaction.messageId,
        sessionID: sessionId,
        agent: pluginId,
        modelID: null,
        providerID: null,
        variant: null,
        // The agent's own work, so the row shows as it does on every harness.
        sender: PluginMessageSender.agent,
        time: PluginMessageTime(created: compaction.startedAtMs, completed: null),
      ),
    ),
    BridgeSseMessagePartUpdated(
      part: PluginMessagePart.compaction(
        id: "${compaction.messageId}-part",
        sessionID: sessionId,
        messageID: compaction.messageId,
        compactionState: state,
      ),
    ),
  ];

  List<BridgeSseEvent> _releaseAutonomousRootTurn({
    required String rootSessionId,
    required String? promptId,
  }) {
    if (promptId == null || !promptId.startsWith(GrokSessionProtocol.autonomousTurnPromptPrefix)) return const [];
    final holdId = promptId.substring(GrokSessionProtocol.autonomousTurnPromptPrefix.length);
    if (holdId.isEmpty) return const [];
    if (!childSessions.releaseRootHold(rootSessionId: rootSessionId, holdId: holdId)) return const [];
    // No prompt settles this turn, so its streamed text is finalized here;
    // left streaming, it would hide the row of still-running sub-agents.
    return finalizeTurn(sessionId: rootSessionId);
  }

  List<BridgeSseEvent> _spawned({
    required String sessionId,
    required String childSessionId,
    required String? model,
    required AcpChildSpawn spawn,
  }) {
    final events = mapChildSpawned(sessionId: sessionId, spawn: spawn);
    // Only a child that was actually announced gets the reported model, so a
    // rejected spawn leaves no stray override behind.
    if (events.isNotEmpty) setChildModel(childSessionId: childSessionId, modelId: model);
    return events;
  }
}
