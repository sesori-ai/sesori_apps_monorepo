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
};

// -----------------------------------------------------------------------------
// Delete session bottom sheet
// -----------------------------------------------------------------------------

class _DeleteSessionSheet extends StatefulWidget {
  final Session session;
  final void Function({required bool deleteWorktree, required bool deleteBranch}) onConfirm;

  const _DeleteSessionSheet({required this.session, required this.onConfirm});

  @override
  State<_DeleteSessionSheet> createState() => _DeleteSessionSheetState();
}

class _DeleteSessionSheetState extends State<_DeleteSessionSheet> {
  bool _deleteWorktree = true;
  bool _deleteBranch = true;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.sessionListDeleteConfirmTitle,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            loc.sessionListDeleteConfirmMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _deleteWorktree,
            onChanged: (v) => setState(() => _deleteWorktree = v ?? false),
            title: Text(loc.sessionListDeleteWorktreeCheckbox),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: _deleteBranch,
            onChanged: (v) => setState(() => _deleteBranch = v ?? false),
            title: Text(loc.sessionListDeleteBranchCheckbox),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => context.pop(),
                child: Text(loc.sessionListDeleteConfirmCancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                onPressed: () {
                  context.pop();
                  widget.onConfirm(
                    deleteWorktree: _deleteWorktree,
                    deleteBranch: _deleteBranch,
                  );
                },
                child: Text(loc.sessionListDeleteConfirmAction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Archive session bottom sheet
// -----------------------------------------------------------------------------

class _ArchiveSessionSheet extends StatefulWidget {
  final Session session;
  final void Function({required bool deleteWorktree, required bool deleteBranch}) onConfirm;

  const _ArchiveSessionSheet({required this.session, required this.onConfirm});

  @override
  State<_ArchiveSessionSheet> createState() => _ArchiveSessionSheetState();
}

class _ArchiveSessionSheetState extends State<_ArchiveSessionSheet> {
  bool _deleteWorktree = true;
  bool _deleteBranch = true;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.sessionListArchiveConfirmTitle,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            loc.sessionListArchiveConfirmMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _deleteWorktree,
            onChanged: (v) => setState(() => _deleteWorktree = v ?? false),
            title: Text(loc.sessionListDeleteWorktreeCheckbox),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: _deleteBranch,
            onChanged: (v) => setState(() => _deleteBranch = v ?? false),
            title: Text(loc.sessionListDeleteBranchCheckbox),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => context.pop(),
                child: Text(loc.sessionListDeleteConfirmCancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  context.pop();
                  widget.onConfirm(
                    deleteWorktree: _deleteWorktree,
                    deleteBranch: _deleteBranch,
                  );
                },
                child: Text(loc.sessionListArchiveConfirmAction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
