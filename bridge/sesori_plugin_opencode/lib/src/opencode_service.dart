import "package:json_annotation/json_annotation.dart" show CheckedFromJsonException;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, PluginApiException, PluginPermissionReply, PluginProvidersResult;
import "package:sesori_shared/sesori_shared.dart" show ProjectActivitySummary;

import "../opencode_plugin.dart";

class OpenCodeService {
  final OpenCodeRepository repository;
  final ActiveSessionTracker tracker;

  OpenCodeService(this.repository, this.tracker);

  Future<List<Project>> getProjects() {
    return repository.getProjects();
  }

  Future<PluginProvidersResult> getProviders({required bool connectedOnly}) {
    return repository.getProviders(connectedOnly: connectedOnly);
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
    } on OpenCodeApiException {
      rethrow;
    } on PluginApiException {
      rethrow;
    } catch (error, stackTrace) {
      if (!_isLikelyDecodeOrSchemaDriftError(error)) {
        rethrow;
      }
      Log.w("Failed to decode messages for session $sessionId: $error\n$stackTrace");
      throw PluginApiException("GET /session/$sessionId/message", 502);
    }
  }

  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) {
    return repository.replyToPermission(
      requestId: requestId,
      sessionId: sessionId,
      reply: reply,
    );
  }

  bool handleSseEvent(SseEventData event, String? directory) {
    return tracker.handleEvent(event, directory);
  }

  Future<void> coldStart() async {
    await tracker.coldStart();
    try {
      await _hydratePendingInput();
    } catch (e, st) {
      Log.w("coldStart: failed to hydrate pending input: $e\n$st");
    }
  }

  /// Best-effort hydration of pending questions and permissions after the
  /// core active-session baseline is ready. Failures are logged but do NOT
  /// abort cold start — [ActiveSessionTracker.coldStart] succeeds
  /// independently.
  Future<void> _hydratePendingInput() async {
    await (
      repository
          .getPendingQuestions()
          .then((questions) => tracker.populatePendingQuestions(questions: questions))
          .catchError((Object e, StackTrace st) {
            Log.w("coldStart: failed to hydrate pending questions: $e\n$st");
          }),
      repository
          .getPendingPermissions()
          .then((permissions) => tracker.populatePendingPermissions(permissions: permissions))
          .catchError((Object e, StackTrace st) {
            Log.w("coldStart: failed to hydrate pending permissions: $e\n$st");
          }),
    ).wait;
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

  bool _isLikelyDecodeOrSchemaDriftError(Object error) {
    return error is FormatException || error is TypeError || error is CheckedFromJsonException;
  }
}
