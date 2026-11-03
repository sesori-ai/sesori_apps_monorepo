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
  required SessionActionService actions,
  required Session session,
  required bool deletesFolder,
  required SessionDeletedRouteHandler? onSessionDeleted,
}) {
  unawaited(
    showPregoModal<void>(
      context: context,
      title: context.loc.sessionListDeleteConfirmTitle,
      builder: (_) => _DeleteSessionSheet(
        session: session,
        deletesFolder: deletesFolder,
        onConfirm: () => unawaited(
          _deleteSession(
            context: context,
            actions: actions,
            sessionId: session.id,
            deleteWorktree: session.hasWorktree,
            deleteSessionFolder: deletesFolder,
            onSessionDeleted: onSessionDeleted,
          ),
        ),
      ),
    ),
  );
}

Future<void> _deleteSession({
  required BuildContext context,
  required SessionActionService actions,
  required String sessionId,
  required bool deleteWorktree,

  /// Only after the confirmation said the session's folder goes too.
  required bool deleteSessionFolder,
  bool force = false,
  required SessionDeletedRouteHandler? onSessionDeleted,
}) async {
  final loc = context.loc;
  final outcome = await actions.deleteSession(
    sessionId: sessionId,
    deleteWorktree: deleteWorktree,
    deleteSessionFolder: deleteSessionFolder,
    force: force,
  );
  if (!context.mounted) return;

  if (outcome != null) {
    PregoPopupAlertPresenter.of(context).show(
      title: loc.sessionListDeleted,
      variant: PregoPopupAlertsNotificationsVariant.success,
      content: switch (outcome) {
        SessionCleanupOutcome.completed => const PregoPopupAlertContent(),
        SessionCleanupOutcome.sharedWorktreeKept => PregoPopupAlertContent(
          message: loc.sessionListCleanupWorktreeKept,
        ),
      },
    );
    onSessionDeleted?.call(context: context, sessionId: sessionId);
    return;
  }

  // Check for cleanup rejection (409).
  final rejection = actions.lastCleanupRejection;
  if (rejection != null) {
    await _showForceDialog(
      context: context,
      actions: actions,
      sessionId: sessionId,
      deleteSessionFolder: deleteSessionFolder,
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
