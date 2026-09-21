import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart" hide SessionCleanupRejection;

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

  /// Archives at once, for the choice made in the refusal alert.
  Future<void> commitNow({required Session session, required bool deleteWorktree, required bool force}) =>
      _commit(session: session, deleteWorktree: deleteWorktree, force: force);

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
    if (isClosed) return;
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
          return PendingSessionArchiveCommitted(session: session);
        case ErrorResponse(:final error):
          loge("Failed to archive session ${session.id}: ${error.toString()}");
          return PendingSessionArchiveFailed(session: session);
      }
    } on SessionCleanupRejectedException catch (error) {
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
