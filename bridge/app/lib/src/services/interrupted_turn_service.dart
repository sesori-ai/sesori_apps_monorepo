import "package:clock/clock.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_running_turn_record.dart";
import "../repositories/session_interruption_repository.dart";
import "../repositories/session_repository.dart";
import "chat_history_service.dart";
import "session_mutation_dispatcher.dart";

/// Decides, once a plugin is ready, what each turn an earlier bridge run left
/// running became: a turn still running is adopted by this run, and one its
/// plugin reports idle was cut off by the bridge stop and becomes the
/// session's interruption.
class InterruptedTurnService({
  required final SessionInterruptionRepository _interruptions,
  required final SessionRepository _sessions,
  required final ChatHistoryService _chatHistory,
  required final SessionMutationDispatcher _mutations,
  required final Clock _clock,
}) {
  /// The start of this bridge run. A running row written before it was left
  /// by an earlier run.
  final DateTime _runStartedAt = _clock.now();

  Future<void> resolve({required String pluginId}) async {
    final leftovers = await _interruptions.readLeftovers(pluginId: pluginId, startedBefore: _runStartedAt);
    if (leftovers.isEmpty) return;
    final Map<String, SessionStatus> statuses;
    try {
      statuses = await _sessions.getPluginSessionStatuses(pluginId: pluginId);
    } on Object catch (error, stackTrace) {
      // No evidence the turns ended: keep the rows for the next readiness or
      // bridge run.
      Log.w("Could not read session statuses of plugin $pluginId to resolve left running turns", error, stackTrace);
      return;
    }
    for (final leftover in leftovers) {
      try {
        await _resolveLeftover(leftover: leftover, status: statuses[leftover.sessionId]);
      } on Object catch (error, stackTrace) {
        Log.w("Could not resolve the left running turn of session ${leftover.sessionId}", error, stackTrace);
      }
    }
  }

  /// A session the plugin reports no status for is idle.
  Future<void> _resolveLeftover({required SessionRunningTurnRecord leftover, required SessionStatus? status}) async {
    switch (status) {
      case SessionStatusBusy() || SessionStatusRetry():
        await _interruptions.adoptLeftover(leftover: leftover, now: _clock.now());
      case SessionStatusIdle() || null:
        if (await _chatHistory.convertInterruptedTurn(leftover: leftover)) {
          await _mutations.interruptionUpdated(sessionId: leftover.sessionId);
        }
    }
  }
}
