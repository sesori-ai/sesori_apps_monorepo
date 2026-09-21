part of "session_list_action_dispatcher.dart";

// Compact centred alerts for a pointer surface, where a bottom sheet is out of
// place. Escape and Return both cancel; the destructive button is never the
// default.

const double _compactAlertWidth = 372;

String _sessionName({required AppLocalizations loc, required Session session}) =>
    session.title ?? loc.sessionDetailTitle;

Future<bool> _confirmArchiveRunning({required BuildContext context, required Session session}) async {
  final loc = context.loc;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(loc.sessionListArchiveRunningTitle),
      content: SizedBox(
        width: _compactAlertWidth,
        child: Text(loc.sessionListArchiveRunningMessage(_sessionName(loc: loc, session: session))),
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(loc.sessionListDeleteConfirmCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(loc.sessionListArchiveConfirmAction),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Whether to delete the worktree too, or null when the user cancelled.
Future<bool?> _confirmDelete({required BuildContext context, required Session session}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _CompactDeleteAlert(session: session),
  );
}

class const _CompactDeleteAlert({required final Session session}) extends StatefulWidget {
  @override
  State<_CompactDeleteAlert> createState() => _CompactDeleteAlertState();
}

class _CompactDeleteAlertState() extends State<_CompactDeleteAlert> {
  bool _deleteWorktree = true;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final hasWorktree = widget.session.hasWorktree;
    return AlertDialog(
      title: Text(loc.sessionListDeleteNamedTitle(_sessionName(loc: loc, session: widget.session))),
      content: SizedBox(
        width: _compactAlertWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.sessionListDeleteConfirmMessage),
            if (hasWorktree)
              CheckboxListTile(
                value: _deleteWorktree,
                onChanged: (value) => setState(() => _deleteWorktree = value ?? false),
                title: Text(loc.sessionListDeleteWorktreeKeepsBranch),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.sessionListDeleteConfirmCancel),
        ),
        FilledButton(
          key: const Key("session-delete-alert-confirm"),
          style: FilledButton.styleFrom(backgroundColor: context.prego.colors.fgErrorPrimary),
          onPressed: () => Navigator.of(context).pop(hasWorktree && _deleteWorktree),
          child: Text(loc.sessionListDeleteConfirmAction),
        ),
      ],
    );
  }
}

/// What the user chose after the bridge refused to clean up a worktree.
enum SessionArchiveRefusedChoice() {
  keepWorktree,
  deleteAnyway,
}

/// Names the refusal's issues and offers keeping the worktree as the default.
/// Null when the user cancelled.
Future<SessionArchiveRefusedChoice?> showSessionArchiveRefusedAlert({
  required BuildContext context,
  required SessionCleanupRejection rejection,
}) {
  final loc = context.loc;
  return showDialog<SessionArchiveRefusedChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(loc.sessionListArchiveRefusedTitle),
      content: SizedBox(
        width: _compactAlertWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final issue in rejection.issues) Text(_describeCleanupIssue(loc: loc, issue: issue)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(loc.sessionListDeleteConfirmCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(SessionArchiveRefusedChoice.deleteAnyway),
          child: Text(
            loc.sessionListArchiveDeleteAnyway,
            style: TextStyle(color: dialogContext.prego.colors.fgErrorPrimary),
          ),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(dialogContext).pop(SessionArchiveRefusedChoice.keepWorktree),
          child: Text(loc.sessionListArchiveKeepWorktree),
        ),
      ],
    ),
  );
}
