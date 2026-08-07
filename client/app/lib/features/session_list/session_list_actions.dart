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
      onConfirm: ({required bool deleteWorktree, required bool deleteBranch}) {
        _archiveSession(
          context: context,
          cubit: cubit,
          sessionId: session.id,
          deleteWorktree: deleteWorktree,
          deleteBranch: deleteBranch,
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
  bool deleteBranch = true,
  bool force = false,
}) async {
  final loc = context.loc;
  final success = await cubit.archiveSession(
    sessionId: sessionId,
    deleteWorktree: deleteWorktree,
    deleteBranch: deleteBranch,
    force: force,
  );
  if (!context.mounted) return;

  if (success) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(loc.sessionListArchived)));
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
      deleteBranch: deleteBranch,
    );
  } else {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(loc.sessionListArchiveFailed)));
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
}) {
  showPregoBottomSheet<void>(
    context: context,
    title: context.loc.sessionListDeleteConfirmTitle,
    builder: (_) => _DeleteSessionSheet(
      session: session,
      onConfirm: ({required bool deleteWorktree, required bool deleteBranch}) {
        _deleteSession(
          context: context,
          cubit: cubit,
          sessionId: session.id,
          deleteWorktree: deleteWorktree,
          deleteBranch: deleteBranch,
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
  bool deleteBranch = true,
  bool force = false,
}) async {
  final loc = context.loc;
  final success = await cubit.deleteSession(
    sessionId: sessionId,
    deleteWorktree: deleteWorktree,
    deleteBranch: deleteBranch,
    force: force,
  );
  if (!context.mounted) return;

  if (success) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(loc.sessionListDeleted)));
    _closeDeletedSessionRoute(context: context, sessionId: sessionId);
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
      deleteBranch: deleteBranch,
    );
  } else {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(loc.sessionListDeleteFailed)));
  }
}

/// Leaves the deleted session's detail (or diffs) route when it is still the
/// current location.
///
/// In the split layout the detail pane would otherwise keep rendering the
/// deleted session; returning to the sessions route swaps it for the empty
/// "select a session" panel. In the narrow layout the sessions route is
/// already current when deleting from the list, so this is a no-op there.
void _closeDeletedSessionRoute({required BuildContext context, required String sessionId}) {
  final routeState = GoRouterState.of(context);
  if (routeState.pathParameters[sessionIdPathParam] != sessionId) return;

  final projectId = routeState.pathParameters[projectIdPathParam];
  if (projectId == null) return;

  context.goRoute(
    AppRoute.sessions(
      projectId: projectId,
      projectName: routeState.uri.queryParameters[projectNameQueryParam],
      supportsDedicatedWorktrees: switch (routeState.uri.queryParameters[supportsDedicatedWorktreesQueryParam]) {
        "true" => true,
        "false" => false,
        _ => null,
      },
    ),
  );
}
