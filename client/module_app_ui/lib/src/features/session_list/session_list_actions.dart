part of "session_list_action_dispatcher.dart";

// ---------------------------------------------------------------------------
// Delete
// ---------------------------------------------------------------------------

/// Deleting destroys the session outright, so every session confirms it —
/// including one without a dedicated worktree, where the sheet simply has no
/// worktree to warn about. An archived row's full swipe commits delete,
/// so this path must never destroy anything unconfirmed.
void _showDeleteSheet({
  required BuildContext context,
  required SessionListCubit cubit,
  required Session session,
  required SessionDeletedRouteHandler? onSessionDeleted,
}) {
  final release = cubit.retainActionScope();
  final sheet = showPregoModal<void>(
    context: context,
    title: context.loc.sessionListDeleteConfirmTitle,
    builder: (_) => _DeleteSessionSheet(
      session: session,
      onConfirm: () {
        final release = cubit.retainActionScope();
        unawaited(
          _deleteSession(
            context: context,
            cubit: cubit,
            sessionId: session.id,
            deleteWorktree: session.hasWorktree,
            onSessionDeleted: onSessionDeleted,
          ).whenComplete(release),
        );
      },
    ),
  );
  unawaited(sheet.whenComplete(release));
}

Future<void> _deleteSession({
  required BuildContext context,
  required SessionListCubit cubit,
  required String sessionId,
  required bool deleteWorktree,
  bool force = false,

  /// Set by the shared-worktree retry below, so the success alert says the
  /// worktree survived rather than claiming a clean removal.
  bool worktreeKept = false,
  required SessionDeletedRouteHandler? onSessionDeleted,
}) async {
  final loc = context.loc;
  final success = await cubit.deleteSession(
    sessionId: sessionId,
    deleteWorktree: deleteWorktree,
    force: force,
  );
  if (!context.mounted) return;

  if (success) {
    PregoPopupAlertPresenter.of(context).show(
      title: loc.sessionListDeleted,
      variant: PregoPopupAlertsNotificationsVariant.success,
      content: worktreeKept
          ? PregoPopupAlertContent(message: loc.sessionListCleanupWorktreeKept)
          : const PregoPopupAlertContent(),
    );
    onSessionDeleted?.call(context: context, sessionId: sessionId);
    return;
  }

  // Check for cleanup rejection (409).
  final rejection = cubit.lastCleanupRejection;
  if (rejection != null) {
    // A worktree another live session still uses is not the user's problem to
    // solve: delete the session and leave that worktree to the other one. The
    // retry sends deleteWorktree: false, so it cannot be refused again.
    if (deleteWorktree && rejection.isOnlySharedWorktree) {
      await _deleteSession(
        context: context,
        cubit: cubit,
        sessionId: sessionId,
        deleteWorktree: false,
        worktreeKept: true,
        onSessionDeleted: onSessionDeleted,
      );
      return;
    }
    await _showForceDialog(
      context: context,
      cubit: cubit,
      sessionId: sessionId,
      rejection: rejection,
      onSessionDeleted: onSessionDeleted,
    );
  } else {
    PregoPopupAlertPresenter.of(context).show(
      title: loc.sessionListDeleteFailed,
      variant: PregoPopupAlertsNotificationsVariant.error,
    );
  }
}
