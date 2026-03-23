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

  Future<List<MessageWithParts>> getLastExchange(String sessionId, {String? directory}) async {
    try {
      final messages = await repository.api.getMessages(sessionId, directory: directory);
      Log.d("[dbg] got ${messages.length} messages for session $sessionId");
      if (messages.isNotEmpty) {
        Log.v("[dbg] first message: ${messages[0].toJson()}");
      }
      if (messages.isEmpty) return [];

      int lastUserIndex = -1;
      for (int i = messages.length - 1; i >= 0; i--) {
        if (messages[i].info.role == "user") {
          lastUserIndex = i;
          break;
        }
      }

      if (lastUserIndex == -1) return [];
      return messages.sublist(lastUserIndex);
    } catch (_) {
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
