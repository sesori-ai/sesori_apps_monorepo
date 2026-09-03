part of "session_list_action_dispatcher.dart";

// ---------------------------------------------------------------------------
// Archive
// ---------------------------------------------------------------------------

/// Archiving is permanent, so every session confirms it — including one
/// without a dedicated worktree, where the sheet simply has no cleanup
/// checkboxes to offer.
void _showArchiveSheet({
  required BuildContext context,
  required SessionListCubit cubit,
  required Session session,
}) {
  showPregoBottomSheet<void>(
    context: context,
    title: context.loc.sessionListArchiveConfirmTitle,
    builder: (_) => _ArchiveSessionSheet(
      session: session,
      onConfirm: ({required bool deleteWorktree}) {
        _archiveSession(
          context: context,
          cubit: cubit,
          sessionId: session.id,
          deleteWorktree: deleteWorktree,
        );
      },
    ),
  );
}

Future<void> _archiveSession({
  required BuildContext context,
  required SessionListCubit cubit,
  required String sessionId,
  bool deleteWorktree = true,
  bool force = false,
}) async {
  final loc = context.loc;
  final success = await cubit.archiveSession(
    sessionId: sessionId,
    deleteWorktree: deleteWorktree,
    force: force,
  );
  if (!context.mounted) return;

  if (success) {
    PregoPopupAlertPresenter.of(context).show(
      title: loc.sessionListArchived,
      variant: PregoPopupAlertsNotificationsVariant.success,
    );
    return;
  }

  // Check for cleanup rejection (409).
  final rejection = cubit.lastCleanupRejection;
  if (rejection != null) {
    _showForceDialog(
      context: context,
      cubit: cubit,
      sessionId: sessionId,
      rejection: rejection,
      isDelete: false,
      deleteWorktree: deleteWorktree,
      onSessionDeleted: null,
    );
  } else {
    PregoPopupAlertPresenter.of(context).show(
      title: loc.sessionListArchiveFailed,
      variant: PregoPopupAlertsNotificationsVariant.error,
    );
  }
}

// ---------------------------------------------------------------------------
// Delete
// ---------------------------------------------------------------------------

/// Deleting destroys the session outright, so every session confirms it —
/// including one without a dedicated worktree, where the sheet simply has no
/// cleanup checkboxes to offer. An archived row's full swipe commits delete,
/// so this path must never destroy anything unconfirmed.
void _showDeleteSheet({
  required BuildContext context,
  required SessionListCubit cubit,
  required Session session,
  required SessionDeletedRouteHandler? onSessionDeleted,
}) {
  showPregoBottomSheet<void>(
    context: context,
    title: context.loc.sessionListDeleteConfirmTitle,
    builder: (_) => _DeleteSessionSheet(
      session: session,
      onConfirm: ({required bool deleteWorktree}) {
        _deleteSession(
          context: context,
          cubit: cubit,
          sessionId: session.id,
          deleteWorktree: deleteWorktree,
          onSessionDeleted: onSessionDeleted,
        );
      },
    ),
  );
}

Future<void> _deleteSession({
  required BuildContext context,
  required SessionListCubit cubit,
  required String sessionId,
  bool deleteWorktree = true,
  bool force = false,
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
    );
    onSessionDeleted?.call(context: context, sessionId: sessionId);
    return;
  }

  // Check for cleanup rejection (409).
  final rejection = cubit.lastCleanupRejection;
  if (rejection != null) {
    _showForceDialog(
      context: context,
      cubit: cubit,
      sessionId: sessionId,
      rejection: rejection,
      isDelete: true,
      deleteWorktree: deleteWorktree,
      onSessionDeleted: onSessionDeleted,
    );
  } else {
    PregoPopupAlertPresenter.of(context).show(
      title: loc.sessionListDeleteFailed,
      variant: PregoPopupAlertsNotificationsVariant.error,
    );
  }
}
