import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../logging/logging.dart";
import "../../repositories/archive_after_send_preference_storage.dart";
import "../../repositories/models/send_to_session_result.dart";
import "../../repositories/models/session_abort_not_accepted_exception.dart";
import "../../repositories/models/session_abort_rejected_exception.dart";
import "../../repositories/models/session_pin_result.dart";
import "../../services/feedback_prompt_service.dart";
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
  required final FeedbackPromptService _feedbackPromptService,
  required final ArchiveAfterSendPreferenceStorage _archiveAfterSendStorage,
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
  Future<SendToSessionResult> sendToSession({
    required String sourceSessionId,
    required String sourcePluginId,
    required String targetSessionId,
  }) => _actionService.sendToSession(
    sourceSessionId: sourceSessionId,
    sourcePluginId: sourcePluginId,
    targetSessionId: targetSessionId,
  );

  /// The send sheet's last "Archive this session after sending" choice; on
  /// until the user turns it off.
  Future<bool> archiveAfterSend() => _archiveAfterSendStorage.read();

  Future<void> setArchiveAfterSend({required bool value}) => _archiveAfterSendStorage.write(value: value);

  /// Stops [sessionId] and its sub-agents, so a busy source can be sent.
  /// False when the bridge did not stop it.
  // ponytail: no launch follow-up hold, unlike the session page's stop: only the page has a composer to return them to.
  Future<bool> stopSession({required String sessionId}) async {
    // As on the session page, the stopped turn earns no feedback point.
    _feedbackPromptService.recordUserStop(sessionId: sessionId);
    try {
      await _abortService.abortSession(sessionId: sessionId, subAgents: SessionAbortSubAgentPolicy.stop);
      return true;
    } on SessionAbortDescendantFailureException catch (error) {
      // The session itself stopped, which is all sending needs; only a sub-agent did not.
      loge("Failed to stop the sub-agents of session $sessionId", error.cause, error.causeStackTrace);
      return true;
    } on Object catch (error, stackTrace) {
      if (error is SessionAbortRejectedException || error is SessionAbortNotAcceptedException) {
        // Refused without changing anything, so the turn runs on.
        _feedbackPromptService.recordUserStopRefused(sessionId: sessionId);
      }
      loge("Failed to stop session $sessionId", error, stackTrace);
      return false;
    }
  }
}
