part of "session_list_screen.dart";

// ---------------------------------------------------------------------------
// Force delete / archive dialog (409 rejection)
// ---------------------------------------------------------------------------

void _showForceDialog({
  required BuildContext context,
  required SessionListCubit cubit,
  required String sessionId,
  required SessionCleanupRejection rejection,
  required bool isDelete,
  required bool deleteWorktree,
  required bool deleteBranch,
}) {
  final loc = context.loc;

  showDialog<void>(
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
                      color: Theme.of(context).colorScheme.error,
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
              if (isDelete) {
                _deleteSession(
                  context: context,
                  cubit: cubit,
                  sessionId: sessionId,
                  deleteWorktree: deleteWorktree,
                  deleteBranch: deleteBranch,
                  force: true,
                );
              } else {
                _archiveSession(
                  context: context,
                  cubit: cubit,
                  sessionId: sessionId,
                  deleteWorktree: deleteWorktree,
                  deleteBranch: deleteBranch,
                  force: true,
                );
              }
            },
            child: Text(
              isDelete ? loc.sessionListForceDeleteAction : loc.sessionListForceArchiveAction,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
