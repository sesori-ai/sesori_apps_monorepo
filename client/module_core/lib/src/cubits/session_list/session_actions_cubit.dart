import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../logging/logging.dart";
import "../../repositories/models/send_to_session_result.dart";
import "../../repositories/models/session_pin_result.dart";
import "../../services/models/session_delete_result.dart";
import "../../services/session_abort_service.dart";
import "../../services/session_action_service.dart";
import "../../services/session_window_service.dart";

/// The actions a session row or page offers: pin, rename, delete, mark read
/// or unread, send into another session, and stop. The rows they change live
/// in [SessionWindowService] and the trackers.
///
/// It holds no state. Each action returns its own outcome, so actions on
/// different sessions cannot overwrite each other's result.
class SessionActionsCubit({
  required final SessionWindowService _window,
  required final SessionActionService _actionService,
  required final SessionAbortService _abortService,
}) extends Cubit<void> {
  this : super(null);

  /// The row shows [title] at once. False when the bridge refused it, after
  /// the row got its previous title back.
  Future<bool> renameSession({required String sessionId, required String title}) =>
      _window.renameSession(sessionId: sessionId, title: title);

  /// The row moves into or out of Pinned once the bridge answers.
  Future<SessionPinResult> setPinned({required String sessionId, required bool pinned}) =>
      _window.setPinned(sessionId: sessionId, pinned: pinned);

  /// [deleteSessionFolder] also removes a "No project" session's own folder.
  Future<SessionDeleteResult> deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteSessionFolder,
    required bool force,
  }) => _actionService.deleteSession(
    sessionId: sessionId,
    deleteWorktree: deleteWorktree,
    deleteSessionFolder: deleteSessionFolder,
    force: force,
  );

  Future<void> markSessionSeen({required String projectId, required String sessionId, required bool read}) =>
      _actionService.markSessionSeen(projectId: projectId, sessionId: sessionId, read: read);

  /// Completes once the bridge answers, which waits for the source's summary.
  Future<SendToSessionResult> sendToSession({required String sourceSessionId, required String targetSessionId}) =>
      _actionService.sendToSession(sourceSessionId: sourceSessionId, targetSessionId: targetSessionId);

  /// Stops [sessionId] and its sub-agents, so a busy source can be sent.
  /// False when the bridge did not stop it.
  Future<bool> stopSession({required String sessionId}) async {
    try {
      await _abortService.abortSession(sessionId: sessionId, subAgents: SessionAbortSubAgentPolicy.stop);
      return true;
    } on Object catch (error, stackTrace) {
      loge("Failed to stop session $sessionId", error, stackTrace);
      return false;
    }
  }
}
