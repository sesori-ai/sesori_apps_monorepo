part of "session_list_action_dispatcher.dart";

// ---------------------------------------------------------------------------
// Force delete dialog (409 rejection)
// ---------------------------------------------------------------------------

Future<void> _showForceDialog({
  required BuildContext context,
  required SessionListCubit cubit,
  required String sessionId,
  required SessionCleanupRejection rejection,
  required bool deleteWorktree,
  required SessionDeletedRouteHandler? onSessionDeleted,
}) {
  final loc = context.loc;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(loc.sessionListForceDeleteTitle),
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
                      TablerRegular.alert_triangle,
                      size: PregoIconSize.md,
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
              unawaited(
                _deleteSession(
                  context: context,
                  cubit: cubit,
                  sessionId: sessionId,
                  deleteWorktree: deleteWorktree,
                  force: true,
                  onSessionDeleted: onSessionDeleted,
                ).whenComplete(release),
              );
            },
            child: Text(
              loc.sessionListForceDeleteAction,
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
