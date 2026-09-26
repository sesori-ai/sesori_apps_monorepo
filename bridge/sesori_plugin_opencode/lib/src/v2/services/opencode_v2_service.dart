import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "../models/v2_agent_names.dart";
import "../models/v2_event.g.dart";
import "../models/v2_message_filter.dart";
import "../repositories/opencode_v2_activity_tracker.dart";
import "../repositories/opencode_v2_repository.dart";
import "../sse/v2_event_mapper.dart";

/// The transport consumer serializes refresh and event handling. This service
/// owns their orchestration, not a stream, queue, transcript cache or lifecycle.
class OpenCodeV2Service({
  required final OpenCodeV2Repository _repository,
  required final OpenCodeV2ActivityTracker _tracker,
  required final V2EventMapper _mapper,
}) {
  PluginWorkState get workState => _tracker.workState;

  Future<void> coldStart() async {
    _tracker.invalidateBaseline();
    final sessions = await _repository.getSessionMetadata();
    final directories = sessions.map((session) => session.directory).toSet();
    final (active, (permissionLists, formLists)) = await shared.wait2(
      _repository.getActiveSessionIds(),
      shared.wait2(
        Future.wait(directories.map((directory) => _repository.getPendingPermissions(directory: directory))),
        Future.wait(directories.map((directory) => _repository.getPendingForms(directory: directory))),
      ),
    );
    _tracker.seed(
      sessions: sessions,
      activeSessionIds: active,
      permissions: permissionLists.expand((requests) => requests).toList(),
      forms: formLists.expand((forms) => forms).toList(),
    );
  }

  void reset() => _tracker.reset();

  Future<List<BridgeSseEvent>> handleEvent({required V2EventEnvelope envelope}) async {
    final event = envelope.data;
    final sessionId = switch (event) {
      final V2SessionEventData scoped => _sessionId(event: scoped),
      _ => null,
    };
    final deleted = event is V2SessionDeleted ? _tracker.session(sessionId: event.sessionID) : null;
    var changed = _tracker.apply(event: event);
    final result = _mapper.map(envelope: envelope);

    if (sessionId != null &&
        event is! V2SessionDeleted &&
        (_tracker.session(sessionId: sessionId) == null || event is V2SessionCreated || event is V2SessionRenamed)) {
      try {
        changed =
            _tracker.rememberSession(session: await _repository.getSessionDetails(sessionId: sessionId)) || changed;
      } catch (error, stack) {
        // A metadata lookup must not suppress a native status or input request.
        Log.w("OpenCode v2 session metadata failed for $sessionId", error, stack);
      }
    }
    if (sessionId != null) {
      final session = deleted ?? _tracker.session(sessionId: sessionId);
      if (session != null) {
        if (_mapper.mapSession(event: event, session: session) case final projected?) result.add(projected);
      }
    }
    result.addAll(
      _mapper.mapInput(
        event: event,
        displaySessionId: sessionId == null ? null : _tracker.rootSessionId(sessionId: sessionId),
      ),
    );
    try {
      result.addAll(
        await _enrich(
          envelope: envelope,
          directory: sessionId == null
              ? null
              : _tracker.session(sessionId: sessionId)?.directory ?? envelope.location?.directory,
        ),
      );
    } catch (error, stack) {
      Log.w(
        "OpenCode v2 event enrichment failed (${event.runtimeType}, session=$sessionId, event=${envelope.id})",
        error,
        stack,
      );
    }
    if (changed) result.add(const BridgeSseProjectUpdated());
    return result;
  }

  Future<List<BridgeSseEvent>> _enrich({required V2EventEnvelope envelope, required String? directory}) async {
    final event = envelope.data;
    if (event is V2SessionSynthetic) {
      return _mapper.mapNotice(
        envelope: envelope,
        agentNames: const V2AgentNames(namesById: {}),
      );
    }
    if (directory == null) return const [];
    switch (event) {
      case V2SessionStepStarted():
        return _mapper.mapAssistantStarted(
          event: event,
          agentNames: await _repository.getAgentNames(directory: directory),
        );
      case V2SessionAgentSelected():
        return _mapper.mapNotice(
          envelope: envelope,
          agentNames: await _repository.getAgentNames(directory: directory),
        );
      case V2SessionToolCalled(:final sessionID, :final assistantMessageID, :final id) ||
          V2SessionToolProgress(:final sessionID, :final assistantMessageID, :final id) ||
          V2SessionToolSuccess(:final sessionID, :final assistantMessageID, :final id) ||
          V2SessionToolFailed(:final sessionID, :final assistantMessageID, :final id):
        final message = await _repository.getMessage(
          sessionId: sessionID,
          messageId: assistantMessageID,
          directory: directory,
        );
        return message == null ? const [] : _mapper.mapToolSnapshot(toolId: id, message: message);
      case V2SessionStepEnded(:final sessionID, :final assistantMessageID) ||
          V2SessionStepFailed(:final sessionID, :final assistantMessageID):
        final message = await _repository.getMessage(
          sessionId: sessionID,
          messageId: assistantMessageID,
          directory: directory,
        );
        return message == null ? const [] : _mapper.mapAssistantSnapshot(message: message);
      case V2SessionExecutionSucceeded(:final sessionID) ||
          V2SessionExecutionFailed(:final sessionID) ||
          V2SessionExecutionInterrupted(:final sessionID):
        final message = await _repository.getLatestMessage(
          sessionId: sessionID,
          filter: V2MessageFilter.assistant,
          directory: directory,
        );
        return message == null ? const [] : _mapper.mapAssistantSnapshot(message: message);
      case V2SessionCompactionStarted(:final sessionID) ||
          V2SessionCompactionEnded(:final sessionID) ||
          V2SessionCompactionFailed(:final sessionID):
        final message = await _repository.getLatestMessage(
          sessionId: sessionID,
          filter: V2MessageFilter.compaction,
          directory: directory,
        );
        return message == null ? const [] : _mapper.mapMessageSnapshot(message: message);
      case V2SessionInboxDelivered():
        final message = await _repository.getMessage(
          sessionId: event.sessionID,
          messageId: event.inboxID,
          directory: directory,
        );
        return message == null ? const [] : _mapper.mapMessageSnapshot(message: message);
      default:
        return const [];
    }
  }

  // The generated session marker has no common getter; forms nest their ID.
  String _sessionId({required V2SessionEventData event}) => switch (event) {
    V2FormCreated(:final form) => form.sessionID,
    V2SessionCreated(:final sessionID) ||
    V2SessionRenamed(:final sessionID) ||
    V2SessionDeleted(:final sessionID) ||
    V2SessionExecutionStarted(:final sessionID) ||
    V2SessionExecutionSucceeded(:final sessionID) ||
    V2SessionExecutionFailed(:final sessionID) ||
    V2SessionExecutionInterrupted(:final sessionID) ||
    V2SessionInboxEnqueued(:final sessionID) ||
    V2SessionInboxDelivered(:final sessionID) ||
    V2SessionInboxCancelled(:final sessionID) ||
    V2SessionInboxDeliveryChanged(:final sessionID) ||
    V2SessionAgentSelected(:final sessionID) ||
    V2SessionSynthetic(:final sessionID) ||
    V2SessionStepStarted(:final sessionID) ||
    V2SessionStepEnded(:final sessionID) ||
    V2SessionStepFailed(:final sessionID) ||
    V2SessionTextStarted(:final sessionID) ||
    V2SessionTextDelta(:final sessionID) ||
    V2SessionTextEnded(:final sessionID) ||
    V2SessionReasoningStarted(:final sessionID) ||
    V2SessionReasoningDelta(:final sessionID) ||
    V2SessionReasoningEnded(:final sessionID) ||
    V2SessionToolInputStarted(:final sessionID) ||
    V2SessionToolInputDelta(:final sessionID) ||
    V2SessionToolInputEnded(:final sessionID) ||
    V2SessionToolCalled(:final sessionID) ||
    V2SessionToolProgress(:final sessionID) ||
    V2SessionToolSuccess(:final sessionID) ||
    V2SessionToolFailed(:final sessionID) ||
    V2SessionRetryScheduled(:final sessionID) ||
    V2SessionCompactionStarted(:final sessionID) ||
    V2SessionCompactionDelta(:final sessionID) ||
    V2SessionCompactionEnded(:final sessionID) ||
    V2SessionCompactionFailed(:final sessionID) ||
    V2PermissionAsked(:final sessionID) ||
    V2PermissionReplied(:final sessionID) ||
    V2FormReplied(:final sessionID) ||
    V2FormCancelled(:final sessionID) => sessionID,
  };

  List<PluginProjectActivitySummary> buildSummary() {
    // Match the bridge's root + direct-child activity contract, including an
    // input-only child while the root itself is idle.
    final groups = <String, Set<String>>{};
    for (final id in _tracker.workingSessionIds) {
      final session = _tracker.session(sessionId: id);
      if (session == null) continue;
      groups.putIfAbsent(session.parentID ?? id, () => {}).add(id);
    }
    final projects = <String, List<PluginActiveSession>>{};
    for (final root in groups.keys.toList()..sort()) {
      final members = groups[root]!;
      final session = _tracker.session(sessionId: root) ?? _tracker.session(sessionId: members.first)!;
      final children = members.where((id) => id != root).toList()..sort();
      projects
          .putIfAbsent(session.projectID, () => [])
          .add(
            PluginActiveSession(
              id: root,
              mainAgentRunning: _tracker.status(sessionId: root) != null,
              awaitingInput:
                  _tracker.hasPendingInput(sessionId: root) ||
                  children.any((id) => _tracker.hasPendingInput(sessionId: id)),
              isRetrying:
                  _tracker.status(sessionId: root) is PluginSessionStatusRetry ||
                  children.any((id) => _tracker.status(sessionId: id) is PluginSessionStatusRetry),
              childSessionIds: children,
            ),
          );
    }
    return [
      for (final id in projects.keys.toList()..sort())
        PluginProjectActivitySummary(id: id, activeSessions: projects[id]!),
    ];
  }
}
