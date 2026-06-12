part of "session_list_screen.dart";

// ---------------------------------------------------------------------------
// Archive
// ---------------------------------------------------------------------------

void _showArchiveSheet({
  required BuildContext context,
  required SessionListCubit cubit,
  required Session session,
}) {
  // Sessions without a dedicated worktree have nothing to clean up — bypass
  // the "delete worktree and branch" sheet and archive directly.
  if (!session.hasWorktree) {
    _archiveSession(
      context: context,
      cubit: cubit,
      sessionId: session.id,
      deleteWorktree: false,
      deleteBranch: false,
    );
    return;
  }

  showAppModalBottomSheet<void>(
    context: context,
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
    _showUndoSnackBar(context: context, cubit: cubit, message: loc.sessionListArchived);
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

Future<void> _unarchiveSession({
  required BuildContext context,
  required SessionListCubit cubit,
  required String sessionId,
}) async {
  final loc = context.loc;
  final success = await cubit.unarchiveSession(sessionId);
  if (!success || !context.mounted) return;

  _showUndoSnackBar(context: context, cubit: cubit, message: loc.sessionListUnarchived);
}

void _showUndoSnackBar({
  required BuildContext context,
  required SessionListCubit cubit,
  required String message,
}) {
  final loc = context.loc;

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context)
      .showSnackBar(
        SnackBar(
          content: Text(message),
          duration: kSnackBarDuration,
          action: SnackBarAction(
            label: loc.sessionListUndo,
            onPressed: () => cubit.undoLastArchiveAction(),
          ),
        ),
      )
      .closed
      .then((reason) {
        // Clear undo state only when the snackbar genuinely expired or was
        // swiped away. Skip on:
        //  - action: user pressed undo — cubit already cleared the snapshot.
        //  - remove: clearSnackBars() was called because a new archive/unarchive
        //    action replaced this snackbar — clearing now would wipe the *new*
        //    action's undo state.
        if (reason == SnackBarClosedReason.timeout || reason == SnackBarClosedReason.swipe) {
          cubit.clearLastActionUndo();
        }
      });
}

// ---------------------------------------------------------------------------
// Delete
// ---------------------------------------------------------------------------

void _showDeleteSheet({
  required BuildContext context,
  required SessionListCubit cubit,
  required Session session,
}) {
  // Sessions without a dedicated worktree have nothing to clean up — bypass
  // the "delete worktree and branch" sheet and delete directly.
  if (!session.hasWorktree) {
    _deleteSession(
      context: context,
      cubit: cubit,
      sessionId: session.id,
      deleteWorktree: false,
      deleteBranch: false,
    );
    return;
  }

  showAppModalBottomSheet<void>(
    context: context,
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
  if (routeState.pathParameters["sessionId"] != sessionId) return;

  final projectId = routeState.pathParameters["projectId"];
  if (projectId == null) return;

  context.goRoute(
    AppRoute.sessions(
      projectId: projectId,
      projectName: routeState.uri.queryParameters[projectNameQueryParam],
    ),
  );
}
