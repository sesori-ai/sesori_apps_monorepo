import "package:bloc/bloc.dart";

import "../../services/models/session_delete_result.dart";
import "../../services/session_action_service.dart";
import "../../services/session_window_service.dart";

/// The actions a session row or page offers: rename, delete, and mark read
/// or unread. The rows they change live in [SessionWindowService] and the
/// trackers.
///
/// It holds no state. Each action returns its own outcome, so actions on
/// different sessions cannot overwrite each other's result.
class SessionActionsCubit({
  required final SessionWindowService _window,
  required final SessionActionService _actionService,
}) extends Cubit<void> {
  this : super(null);

  /// The row shows [title] at once. False when the bridge refused it, after
  /// the row got its previous title back.
  Future<bool> renameSession({required String sessionId, required String title}) =>
      _window.renameSession(sessionId: sessionId, title: title);

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
}
