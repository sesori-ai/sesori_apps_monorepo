import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "models/omp_compaction_models.dart";
import "omp_identity.dart";
import "trackers/omp_compaction_tracker.dart";

/// Oh My Pi's ACP mapping: OMP's own tool names and its automatic compaction
/// notifications on top of stock ACP.
///
/// A compaction outside an accepted prompt (OMP's opt-in idle compaction)
/// reads as busy only through the plugin's status query, so a history read
/// leaves its row running. It sends no live busy status: the bridge would
/// take the busy-to-idle pair for a finished turn and push a completion
/// notification for a turn the user never ran. `hasPendingTurn` is the
/// plugin's turn accounting, which counts a prompt from acceptance.
class OmpEventMapper({
  required super.launchDirectory,
  required super.pluginId,
  required super.configurationTracker,
  required super.childSessions,
  required final OmpCompactionTracker compactionTracker,
  required final bool Function({required String sessionId}) hasPendingTurn,
}) extends AcpEventMapper {
  /// Sent for automatic compaction only; a manual `/compact` sends neither.
  static const String compactionStartMethod = "_omp/compaction/start";
  static const String compactionEndMethod = "_omp/compaction/end";

  /// Sessions whose compaction is still running; the harness is working.
  List<String> get compactingSessionIds => compactionTracker.runningSessionIds;

  /// OMP sends its own tool name as a top-level `name` on `tool_call` (outside
  /// the ACP schema, from 18.18.8); its `kind` buckets task, wait and ask as
  /// `other`, so the name labels the card instead.
  @override
  String? toolNameForToolUpdate({required Map<String, dynamic> update}) {
    final name = update["name"];
    return name is String && name.isNotEmpty ? name : null;
  }

  /// OMP finishes a prompt's compactions, and waits for a running idle one,
  /// before it answers the prompt. A compaction still recorded here lost its
  /// end, so the bridge's idle sweep settles its row.
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

  /// Drops the compactions that died with the OMP process and returns the
  /// idle events for those that held their session busy outside a turn.
  List<BridgeSseEvent> endCompactionsAfterExit() {
    final idle = [
      for (final sessionId in compactionTracker.runningSessionIds)
        if (!hasPendingTurn(sessionId: sessionId)) BridgeSseSessionIdle(sessionID: sessionId),
    ];
    compactionTracker.clear();
    return idle;
  }

  @override
  bool shouldBufferDuringPromptWrite({required AcpNotification notification}) =>
      // A compaction at the start of a prompt must not reach the client before
      // the accepted user message.
      notification.method == compactionStartMethod ||
      notification.method == compactionEndMethod ||
      super.shouldBufferDuringPromptWrite(notification: notification);

  @override
  List<BridgeSseEvent> mapExtension(AcpNotification notification) {
    try {
      return switch (notification.method) {
        compactionStartMethod => _mapCompactionStart(OmpCompactionStartDto.fromJson(notification.params)),
        compactionEndMethod => _mapCompactionEnd(OmpCompactionEndDto.fromJson(notification.params)),
        _ => super.mapExtension(notification),
      };
    } on Object catch (error, stackTrace) {
      Log.w("[${OmpPluginIdentity.id}] ignored malformed ${notification.method} notification", error, stackTrace);
      return const [];
    }
  }

  List<BridgeSseEvent> _mapCompactionStart(OmpCompactionStartDto start) {
    final sessionId = start.sessionId;
    return _compactionRow(
      sessionId: sessionId,
      compaction: compactionTracker.start(sessionId: sessionId),
      state: const .running(summary: null),
    );
  }

  /// A failed method's fallback to the next preferred one arrives as a new
  /// start/end pair.
  List<BridgeSseEvent> _mapCompactionEnd(OmpCompactionEndDto end) {
    final sessionId = end.sessionId;
    if (end.errorMessage case final errorMessage?) {
      Log.w("[${OmpPluginIdentity.id}] automatic compaction in $sessionId ended with: $errorMessage");
    }
    final PluginCompactionState state = switch (end) {
      OmpCompactionEndDto(aborted: true) => const .failed(reason: .cancelled),
      OmpCompactionEndDto(skipped: true) => const .failed(reason: .nothingToCompact),
      OmpCompactionEndDto(errorMessage: String()) => const .failed(reason: null),
      // OMP reports no summary or freed-token count over ACP.
      _ => const .completed(summary: null, freedTokens: null, trigger: .auto),
    };
    final compaction = compactionTracker.finish(sessionId: sessionId);
    return [
      if (compaction != null) ..._compactionRow(sessionId: sessionId, compaction: compaction, state: state),
      if (state is PluginCompactionStateCompleted) BridgeSseSessionCompacted(sessionID: sessionId),
      // Clears a busy status read mid-compaction. After the settled row, so
      // the idle sweep finds nothing running. With no live busy before it,
      // this idle sends no completion notification.
      if (compaction != null && !hasPendingTurn(sessionId: sessionId)) BridgeSseSessionIdle(sessionID: sessionId),
    ];
  }

  /// The live compaction row: one agent message stamped at the start, with
  /// one part that settles in place. History replay shows OMP's own stored
  /// summary instead.
  List<BridgeSseEvent> _compactionRow({
    required String sessionId,
    required OmpRunningCompaction compaction,
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
}
