part of "session_list_action_dispatcher.dart";

/// The confirm button of both shells' delete confirmation, so a test can commit
/// a delete without depending on which shell rendered the question.
const Key sessionDeleteConfirmKey = Key("session-delete-confirm");

/// The phone's delete question: what deleting means, the worktree notice when
/// the session has one, then Cancel and a destructive Delete. Deleting always
/// removes a dedicated worktree, so the sheet states it rather than asking.
class const _DeleteSessionSheet({
  required final Session session,
  required final VoidCallback onConfirm,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final bodyStyle = context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary);
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(loc.sessionListDeleteConfirmMessage, style: bodyStyle),
            if (session.hasWorktree) ...[
              const SizedBox(height: 12),
              Text(loc.sessionListDeleteWorktreeNotice, style: bodyStyle),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => context.pop(), child: Text(loc.sessionListDeleteConfirmCancel)),
                const SizedBox(width: 8),
                FilledButton(
                  key: sessionDeleteConfirmKey,
                  style: FilledButton.styleFrom(backgroundColor: context.prego.colors.fgErrorPrimary),
                  onPressed: () {
                    context.pop();
                    onConfirm();
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
