import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart" hide SessionCleanupRejection;

import "../logging/logging.dart";
import "../repositories/models/send_to_session_result.dart";
import "../repositories/models/session_cleanup_rejection.dart";
import "../repositories/session_repository.dart";
import "models/session_cleanup_outcome.dart";
import "models/session_delete_result.dart";
import "selected_computer_service.dart";
import "session_cleanup_service.dart";
import "session_unseen_tracker.dart";

/// Deletes sessions, marks them read or unread, and sends one into another.
/// The rows they change live in the session windows and the trackers; this
/// holds nothing a list shows.
@lazySingleton
class SessionActionService({
  required final SessionRepository _sessionRepository,
  required final SessionCleanupService _sessionCleanupService,
  required final SessionUnseenTracker _sessionUnseenTracker,
  required final FailureReporter _failureReporter,
  required final SelectedComputerService _selectedComputerService,
}) {
  /// Marks a session read (clears its bold) or unread (forces bold). Applied
  /// optimistically to the tracker so the row updates immediately; the bridge
  /// echo delivers the authoritative state (including the project aggregate)
  /// within the round trip. On failure, the tracker gets back the value it
  /// held before the optimistic write, unless something newer replaced it.
  Future<void> markSessionSeen({required String projectId, required String sessionId, required bool read}) async {
    final write = _sessionUnseenTracker.applyLocalSessionUnseen(
      projectId: projectId,
      sessionId: sessionId,
      unseen: !read,
    );
    void restore() =>
        _sessionUnseenTracker.restoreLocalSessionUnseen(projectId: projectId, sessionId: sessionId, write: write);
    try {
      final response = await _sessionRepository.markSessionSeen(sessionId: sessionId, read: read);
      if (response case ErrorResponse(:final error)) {
        loge("Failed to mark session ${read ? "read" : "unread"}", error);
        restore();
      }
    } catch (e, st) {
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "session_list_mark_seen",
              fatal: false,
              reason: "Failed to mark session seen",
              information: [sessionId, "read=$read"],
            )
            .catchError((Object error, StackTrace stackTrace) {
              loge("Failed to report mark-seen error", error, stackTrace);
            }),
      );
      restore();
    }
  }

  /// Sends [sourceSessionId] into [targetSessionId]: the source writes a
  /// summary, then the target receives it with the source's transcript. This
  /// can take minutes, while the source writes.
  Future<SendToSessionResult> sendToSession({required String sourceSessionId, required String targetSessionId}) async {
    final computer = await _selectedComputerService.targetBridgeId();
    final result = await _sessionRepository.sendToSession(
      sourceSessionId: sourceSessionId,
      targetSessionId: targetSessionId,
    );
    final description = "session $sourceSessionId to $targetSessionId";
    if (await _selectedComputerService.targetBridgeId() != computer) {
      logw("[SessionActions] sending $description ended after a computer switch: ${result.runtimeType}");
      return const SendToSessionComputerSwitched();
    }
    switch (result) {
      case SendToSessionSent() || SendToSessionComputerSwitched():
        break;
      case SendToSessionUnsupported():
        logw("[SessionActions] could not send $description: the bridge predates sending sessions");
      case SendToSessionRefused(:final code):
        logd("[SessionActions] did not send $description: ${code.name}");
      case SendToSessionFailed(:final error):
        loge("Failed to send $description", error);
      case SendToSessionUnconfirmed(:final error):
        logw("Could not confirm sending $description", error);
    }
    return result;
  }

  /// Deletes a session permanently. [deleteSessionFolder] also removes a
  /// "No project" session's own folder.
  Future<SessionDeleteResult> deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteSessionFolder,
    required bool force,
  }) async {
    final ApiResponse<SessionCleanupOutcome> response;
    try {
      response = await _sessionCleanupService.deleteSession(
        sessionId: sessionId,
        deleteWorktree: deleteWorktree,
        deleteSessionFolder: deleteSessionFolder,
        force: force,
      );
    } on SessionCleanupRejectedException catch (error) {
      logd("[SessionActions] delete rejected: cleanup issues=${error.rejection.issues}");
      return SessionDeleteRejected(rejection: error.rejection);
    }
    switch (response) {
      case SuccessResponse(:final data):
        return SessionDeleted(outcome: data);
      case ErrorResponse(:final error):
        loge("Failed to delete session $sessionId", error);
        return const SessionDeleteFailed();
    }
  }
}
