part of "session_list_action_dispatcher.dart";

// -----------------------------------------------------------------------------
// Delete session bottom sheet
// -----------------------------------------------------------------------------

class const _DeleteSessionSheet({
  required final Session session,
  required final void Function({required bool deleteWorktree, required bool deleteBranch}) onConfirm,
}) extends StatefulWidget {
  @override
  State<_DeleteSessionSheet> createState() => _DeleteSessionSheetState();
}

class _DeleteSessionSheetState() extends State<_DeleteSessionSheet> {
  bool _deleteWorktree = true;
  bool _deleteBranch = true;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    // Without a dedicated worktree there is nothing to clean up, so the sheet
    // confirms the deletion and offers no cleanup choices.
    final hasWorktree = widget.session.hasWorktree;

    // Transparent Material so the checkbox tiles' ink paints on top of the
    // sheet surface instead of behind it on the modal's transparent Material.
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc.sessionListDeleteConfirmMessage,
              style: context.prego.textTheme.textSm.regular.copyWith(
                color: context.prego.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (hasWorktree) ...[
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
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text(loc.sessionListDeleteConfirmCancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: context.prego.colors.fgErrorPrimary),
                  onPressed: () {
                    context.pop();
                    widget.onConfirm(
                      deleteWorktree: hasWorktree && _deleteWorktree,
                      deleteBranch: hasWorktree && _deleteBranch,
                    );
                  },
                  child: Text(loc.sessionListDeleteConfirmAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Archive session bottom sheet
// -----------------------------------------------------------------------------

class const _ArchiveSessionSheet({
  required final Session session,
  required final void Function({required bool deleteWorktree, required bool deleteBranch}) onConfirm,
}) extends StatefulWidget {
  @override
  State<_ArchiveSessionSheet> createState() => _ArchiveSessionSheetState();
}

class _ArchiveSessionSheetState() extends State<_ArchiveSessionSheet> {
  bool _deleteWorktree = true;
  bool _deleteBranch = true;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    // Without a dedicated worktree there is nothing to clean up, so the sheet
    // confirms the permanent archive and offers no cleanup choices.
    final hasWorktree = widget.session.hasWorktree;

    // Transparent Material so the checkbox tiles' ink paints on top of the
    // sheet surface instead of behind it on the modal's transparent Material.
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc.sessionListArchiveConfirmMessage,
              style: context.prego.textTheme.textSm.regular.copyWith(
                color: context.prego.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (hasWorktree) ...[
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
            ],
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
                      deleteWorktree: hasWorktree && _deleteWorktree,
                      deleteBranch: hasWorktree && _deleteBranch,
                    );
                  },
                  child: Text(loc.sessionListArchiveConfirmAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
