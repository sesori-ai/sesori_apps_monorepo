part of "session_list_screen.dart";

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
