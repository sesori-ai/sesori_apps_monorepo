import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart" hide SessionCleanupRejection;

import "../../logging/logging.dart";
import "../../repositories/models/session_cleanup_rejection.dart";
import "../../repositories/session_repository.dart";
import "pending_session_archive_state.dart";

/// Archives a session after a short Undo window: a delayed commit, so Undo
/// and quitting inside the window send nothing.
///
/// It commits through the repository rather than a list cubit, which may be
/// unmounted by the time the window closes.
class PendingSessionArchiveCubit({required final SessionRepository repository})
    extends Cubit<PendingSessionArchiveState> {
  /// Also the Undo alert's duration, so the offer and the window end together.
  static const Duration undoWindow = Duration(seconds: 5);

  final SessionRepository _repository = repository;
  final StreamController<PendingSessionArchiveOutcome> _outcomes = StreamController.broadcast();
  Timer? _timer;

  this : super(const PendingSessionArchiveState(window: PendingArchiveIdle(), archivingIds: {}));

  Stream<PendingSessionArchiveOutcome> get outcomes => _outcomes.stream;

  /// Opens the Undo window for [session]. One window at a time: an archive
  /// still inside its window is committed first.
  void archive({required Session session, required bool deleteWorktree}) {
    _commitWindow();
    emit(
      PendingSessionArchiveState(
        window: PendingArchiveOpen(session: session, deleteWorktree: deleteWorktree),
        archivingIds: state.archivingIds,
      ),
    );
    _timer = Timer(undoWindow, _commitWindow);
  }

  void undo() {
    _timer?.cancel();
    _timer = null;
    emit(PendingSessionArchiveState(window: const PendingArchiveIdle(), archivingIds: state.archivingIds));
  }

  /// Archives at once, forcing the worktree removal the bridge refused. No
  /// second Undo window: the user has already answered the refusal alert.
  Future<void> commitForced({required Session session}) => _commit(session: session, deleteWorktree: true, force: true);

  void _commitWindow() {
    _timer?.cancel();
    _timer = null;
    final window = state.window;
    if (window is! PendingArchiveOpen) return;
    emit(PendingSessionArchiveState(window: const PendingArchiveIdle(), archivingIds: state.archivingIds));
    unawaited(_commit(session: window.session, deleteWorktree: window.deleteWorktree, force: false));
  }

  Future<void> _commit({required Session session, required bool deleteWorktree, required bool force}) async {
    emit(PendingSessionArchiveState(window: state.window, archivingIds: {...state.archivingIds, session.id}));
    final outcome = await _archive(session: session, deleteWorktree: deleteWorktree, force: force);
    // close() shuts the outcomes first, so either one means disposed.
    if (isClosed || _outcomes.isClosed) return;
    if (outcome is! PendingSessionArchiveCommitted) {
      emit(
        PendingSessionArchiveState(
          window: state.window,
          archivingIds: {...state.archivingIds}..remove(session.id),
        ),
      );
    }
    _outcomes.add(outcome);
  }

  Future<PendingSessionArchiveOutcome> _archive({
    required Session session,
    required bool deleteWorktree,
    required bool force,
  }) async {
    try {
      final response = await _repository.archiveSession(
        sessionId: session.id,
        deleteWorktree: deleteWorktree,
        force: force,
      );
      switch (response) {
        case SuccessResponse():
          return PendingSessionArchiveCommitted(session: session, worktreeKept: false);
        case ErrorResponse(:final error):
          loge("Failed to archive session ${session.id}", error);
          return PendingSessionArchiveFailed(session: session);
      }
    } on SessionCleanupRejectedException catch (error) {
      // A worktree another live session still uses is not the user's problem to
      // solve: archive the session and leave that worktree to the other one.
      // The retry sends deleteWorktree: false, so it cannot be refused again.
      if (deleteWorktree && error.rejection.isOnlySharedWorktree) {
        final retry = await _archive(session: session, deleteWorktree: false, force: false);
        return retry is PendingSessionArchiveCommitted
            ? PendingSessionArchiveCommitted(session: session, worktreeKept: true)
            : retry;
      }
      return PendingSessionArchiveRefused(session: session, rejection: error.rejection);
    } on Object catch (error, stackTrace) {
      loge("Failed to archive session ${session.id}", error, stackTrace);
      return PendingSessionArchiveFailed(session: session);
    }
  }

  /// Closing inside the Undo window sends nothing.
  @override
  Future<void> close() async {
    _timer?.cancel();
    await _outcomes.close();
    await super.close();
  }
}
