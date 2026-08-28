part of "session_list_action_dispatcher.dart";

class const _DeleteSessionSheet({
  required final Session session,
  required final void Function({required bool deleteWorktree}) onConfirm,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return _CleanupConfirmSheet(
      session: session,
      message: loc.sessionListDeleteConfirmMessage,
      confirmLabel: loc.sessionListDeleteConfirmAction,
      destructive: true,
      onConfirm: onConfirm,
    );
  }
}

class const _ArchiveSessionSheet({
  required final Session session,
  required final void Function({required bool deleteWorktree}) onConfirm,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return _CleanupConfirmSheet(
      session: session,
      message: loc.sessionListArchiveConfirmMessage,
      confirmLabel: loc.sessionListArchiveConfirmAction,
      destructive: false,
      onConfirm: onConfirm,
    );
  }
}

class const _CleanupConfirmSheet({
  required final Session session,
  required final String message,
  required final String confirmLabel,
  required final bool destructive,
  required final void Function({required bool deleteWorktree}) onConfirm,
}) extends StatefulWidget {
  @override
  State<_CleanupConfirmSheet> createState() => _CleanupConfirmSheetState();
}

class _CleanupConfirmSheetState() extends State<_CleanupConfirmSheet> {
  bool _deleteWorktree = true;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final hasWorktree = widget.session.hasWorktree;
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.message,
              style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (hasWorktree) ...[
              CheckboxListTile(
                value: _deleteWorktree,
                onChanged: (value) => setState(() => _deleteWorktree = value ?? false),
                title: Text(loc.sessionListDeleteWorktreeCheckbox),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => context.pop(), child: Text(loc.sessionListDeleteConfirmCancel)),
                const SizedBox(width: 8),
                FilledButton(
                  style: widget.destructive
                      ? FilledButton.styleFrom(backgroundColor: context.prego.colors.fgErrorPrimary)
                      : null,
                  onPressed: () {
                    context.pop();
                    widget.onConfirm(deleteWorktree: hasWorktree && _deleteWorktree);
                  },
                  child: Text(widget.confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
