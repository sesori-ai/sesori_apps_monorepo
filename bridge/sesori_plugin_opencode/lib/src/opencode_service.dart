import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show ProjectActivitySummary;

import "../opencode_plugin.dart";

class OpenCodeService {
  final OpenCodeRepository repository;
  final ActiveSessionTracker tracker;

  OpenCodeService(this.repository, this.tracker);

  Future<List<Project>> getProjects() {
    return repository.getProjects();
  }

  Future<ProviderListResponse> getProviders() {
    return repository.api.listProviders();
  }

  Future<List<Session>> getSessions({
    required String worktree,
    int? start,
    int? limit,
  }) async {
    final sessions = await repository.getSessions(worktree: worktree);

    final afterStart = _applyStart(sessions, start);
    return _applyLimit(afterStart, limit);
  }

  Future<List<MessageWithParts>> getMessages({
    required String sessionId,
    required String? directory,
  }) async {
    try {
      return await repository.api.getMessages(sessionId: sessionId, directory: directory);
    } catch (e) {
      Log.w("Failed to get messages for session $sessionId: $e");
      return [];
    }
  }

  bool handleSseEvent(SseEventData event, String? directory) {
    return tracker.handleEvent(event, directory);
  }

  Future<void> coldStart() {
    return tracker.coldStart();
  }

  void reset() {
    tracker.reset();
  }

  List<ProjectActivitySummary> buildSummary() {
    return tracker.buildSummary();
  }

  List<Session> _applyStart(List<Session> sessions, int? start) {
    if (start == null || start <= 0) return sessions;
    if (sessions.length > start) return sessions.sublist(start);
    return [];
  }

  List<Session> _applyLimit(List<Session> sessions, int? limit) {
    if (limit == null || limit <= 0) return sessions;
    if (sessions.length > limit) return sessions.sublist(0, limit);
    return sessions;
  }
}
