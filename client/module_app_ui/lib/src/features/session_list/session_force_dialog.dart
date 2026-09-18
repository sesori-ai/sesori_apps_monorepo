part of "session_list_action_dispatcher.dart";

// ---------------------------------------------------------------------------
// Force delete / archive dialog (409 rejection)
// ---------------------------------------------------------------------------

Future<void> _showForceDialog({
  required BuildContext context,
  required SessionListCubit cubit,
  required String sessionId,
  required SessionCleanupRejection rejection,
  required bool isDelete,
  required bool deleteWorktree,
  required SessionDeletedRouteHandler? onSessionDeleted,
}) {
  final loc = context.loc;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(isDelete ? loc.sessionListForceDeleteTitle : loc.sessionListForceArchiveTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.sessionListForceMessage),
            const SizedBox(height: 12),
            for (final issue in rejection.issues)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: context.prego.colors.fgErrorPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_describeCleanupIssue(loc: loc, issue: issue)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(),
            child: Text(loc.sessionListDeleteConfirmCancel),
          ),
          TextButton(
            onPressed: () {
              dialogContext.pop();
              final release = cubit.retainActionScope();
              final Future<void> operation;
              if (isDelete) {
                operation = _deleteSession(
                  context: context,
                  cubit: cubit,
                  sessionId: sessionId,
                  deleteWorktree: deleteWorktree,
                  force: true,
                  onSessionDeleted: onSessionDeleted,
                );
              } else {
                operation = _archiveSession(
                  context: context,
                  cubit: cubit,
                  sessionId: sessionId,
                  deleteWorktree: deleteWorktree,
                  force: true,
                );
              }
              unawaited(operation.whenComplete(release));
            },
            child: Text(
              isDelete ? loc.sessionListForceDeleteAction : loc.sessionListForceArchiveAction,
              style: TextStyle(color: context.prego.colors.fgErrorPrimary),
            ),
          ),
        ],
      );
    },
  );
}

String _describeCleanupIssue({required AppLocalizations loc, required CleanupIssue issue}) => switch (issue) {
  CleanupIssueUnstagedChanges() => loc.sessionListCleanupIssueUnstagedChanges,
  CleanupIssueBranchMismatch(:final expected, :final actual) => loc.sessionListCleanupIssueBranchMismatch(
    actual,
    expected,
  ),
  CleanupIssueSharedWorktree() => loc.sessionListCleanupIssueSharedWorktree,
};
