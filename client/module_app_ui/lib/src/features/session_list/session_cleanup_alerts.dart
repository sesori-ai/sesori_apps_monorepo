part of "session_list_action_dispatcher.dart";

String _sessionName({required AppLocalizations loc, required Session session}) =>
    session.title ?? loc.sessionDetailTitle;

Future<bool> _confirmArchiveRunning({required BuildContext context, required Session session}) async {
  final loc = context.loc;
  final confirmed = await showPregoModal<bool>(
    context: context,
    title: loc.sessionListArchiveRunningTitle,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.sessionListArchiveRunningMessage(_sessionName(loc: loc, session: session)),
            style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
          ),
          const SizedBox(height: PregoSpacing.x2l),
          PregoSheetActions(
            secondary: PregoButtonsSolid(
              label: loc.sessionListDeleteConfirmCancel,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed: () => sheetContext.pop(false),
            ),
            primary: PregoButtonsSolid(
              label: loc.sessionListArchiveConfirmAction,
              hierarchy: PregoButtonsSolidHierarchy.primary,
              size: PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed: () => sheetContext.pop(true),
            ),
          ),
        ],
      ),
    ),
  );
  return confirmed ?? false;
}

/// Whether to delete the worktree too, or null when the user cancelled.
Future<bool?> _confirmDelete({required BuildContext context, required Session session}) {
  final loc = context.loc;
  return showPregoModal<bool>(
    context: context,
    title: loc.sessionListDeleteNamedTitle(_sessionName(loc: loc, session: session)),
    builder: (_) => _DeleteConfirmation(session: session),
  );
}

/// The delete question's body: what deleting means, a worktree checkbox when
/// the session has one, then Cancel and a destructive Delete.
class const _DeleteConfirmation({required final Session session}) extends StatefulWidget {
  @override
  State<_DeleteConfirmation> createState() => _DeleteConfirmationState();
}

class _DeleteConfirmationState() extends State<_DeleteConfirmation> {
  bool _deleteWorktree = true;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final hasWorktree = widget.session.hasWorktree;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.sessionListDeleteConfirmMessage,
            style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
          ),
          if (hasWorktree)
            CheckboxListTile(
              value: _deleteWorktree,
              onChanged: (value) => setState(() => _deleteWorktree = value ?? false),
              title: Text(loc.sessionListDeleteWorktreeKeepsBranch),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          const SizedBox(height: PregoSpacing.x2l),
          PregoSheetActions(
            secondary: PregoButtonsSolid(
              label: loc.sessionListDeleteConfirmCancel,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed: () => context.pop(),
            ),
            primary: PregoButtonsSolid(
              key: const Key("session-delete-alert-confirm"),
              label: loc.sessionListDeleteConfirmAction,
              hierarchy: PregoButtonsSolidHierarchy.primary,
              type: PregoButtonsSolidType.destructive,
              size: PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed: () => context.pop(hasWorktree && _deleteWorktree),
            ),
          ),
        ],
      ),
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
  return showPregoModal<SessionArchiveRefusedChoice>(
    context: context,
    title: loc.sessionListArchiveRefusedTitle,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final issue in rejection.issues)
            Text(
              _describeCleanupIssue(loc: loc, issue: issue),
              style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
            ),
          const SizedBox(height: PregoSpacing.x2l),
          PregoButtonsSolid(
            label: loc.sessionListArchiveKeepWorktree,
            hierarchy: PregoButtonsSolidHierarchy.primary,
            size: PregoButtonsSolidSize.lg,
            fullWidth: true,
            onPressed: () => sheetContext.pop(SessionArchiveRefusedChoice.keepWorktree),
          ),
          const SizedBox(height: PregoSpacing.md),
          PregoButtonsSolid(
            label: loc.sessionListArchiveDeleteAnyway,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            type: PregoButtonsSolidType.destructive,
            size: PregoButtonsSolidSize.lg,
            fullWidth: true,
            onPressed: () => sheetContext.pop(SessionArchiveRefusedChoice.deleteAnyway),
          ),
          const SizedBox(height: PregoSpacing.md),
          PregoButtonsSolid(
            label: loc.sessionListDeleteConfirmCancel,
            hierarchy: PregoButtonsSolidHierarchy.tertiary,
            size: PregoButtonsSolidSize.lg,
            fullWidth: true,
            onPressed: () => sheetContext.pop(),
          ),
        ],
      ),
    ),
  );
}
