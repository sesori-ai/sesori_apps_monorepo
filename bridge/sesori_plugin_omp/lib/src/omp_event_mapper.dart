import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "omp_identity.dart";
import "trackers/omp_compaction_tracker.dart";

/// Stock ACP mapping plus OMP's automatic compaction notifications.
///
/// OMP sends `_omp/compaction/start` and `_omp/compaction/end` for automatic
/// compaction only; a manual `/compact` sends neither.
class OmpEventMapper({
  required super.launchDirectory,
  required super.pluginId,
  required super.configurationTracker,
  required super.childSessions,
  required final OmpCompactionTracker compactionTracker,
}) extends AcpEventMapper {
  static const String compactionStartMethod = "_omp/compaction/start";
  static const String compactionEndMethod = "_omp/compaction/end";

  @override
  void forgetSession(String sessionId) {
    compactionTracker.forgetSession(sessionId: sessionId);
    super.forgetSession(sessionId);
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
    final params = notification.params;
    final sessionId = params["sessionId"];
    switch (notification.method) {
      case compactionStartMethod when sessionId is String && sessionId.isNotEmpty:
        return _compactionRow(
          sessionId: sessionId,
          compaction: compactionTracker.start(sessionId: sessionId),
          state: const .running(summary: null),
        );
      case compactionEndMethod when sessionId is String && sessionId.isNotEmpty:
        return _mapCompactionEnd(sessionId: sessionId, params: params);
    }
    return super.mapExtension(notification);
  }

  /// `willRetry` is not read: OMP sets it on a successful compaction when it
  /// will re-send the overflowed turn, never on a failed one. A fallback to
  /// the next preferred method is a new start/end pair.
  List<BridgeSseEvent> _mapCompactionEnd({
    required String sessionId,
    required Map<String, dynamic> params,
  }) {
    final errorMessage = params["errorMessage"];
    if (errorMessage is String) {
      Log.w("[${OmpPluginIdentity.id}] automatic compaction in $sessionId ended with: $errorMessage");
    }
    final PluginCompactionState state = switch (params) {
      {"aborted": true} => const .failed(reason: .cancelled),
      // OMP's benign skip: nothing to compact yet, or no model to compact with.
      {"skipped": true} => const .failed(reason: .nothingToCompact),
      _ when errorMessage is String => const .failed(reason: null),
      // OMP reports no summary or freed-token count over ACP.
      _ => const .completed(summary: null, freedTokens: null, trigger: .auto),
    };
    return [
      if (compactionTracker.finish(sessionId: sessionId) case final compaction?)
        ..._compactionRow(sessionId: sessionId, compaction: compaction, state: state),
      if (state is PluginCompactionStateCompleted) BridgeSseSessionCompacted(sessionID: sessionId),
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
        agent: null,
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
