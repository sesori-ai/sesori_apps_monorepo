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

/// Whether the user confirmed deleting [session]. Deleting always removes a
/// dedicated worktree, so the dialog says so rather than asking.
Future<bool> _confirmDelete({required BuildContext context, required Session session}) async {
  final loc = context.loc;
  final confirmed = await showPregoModal<bool>(
    context: context,
    title: loc.sessionListDeleteNamedTitle(_sessionName(loc: loc, session: session)),
    builder: (_) => _DeleteConfirmation(session: session),
  );
  return confirmed ?? false;
}

/// The delete question's body: what deleting means, the worktree notice when
/// the session has one, then Cancel and a destructive Delete.
class const _DeleteConfirmation({required final Session session}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final bodyStyle = context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(loc.sessionListDeleteConfirmMessage, style: bodyStyle),
          if (session.hasWorktree) ...[
            const SizedBox(height: PregoSpacing.md),
            Text(loc.sessionListDeleteWorktreeNotice, style: bodyStyle),
          ],
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
              key: sessionDeleteConfirmKey,
              label: loc.sessionListDeleteConfirmAction,
              hierarchy: PregoButtonsSolidHierarchy.primary,
              type: PregoButtonsSolidType.destructive,
              size: PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed: () => context.pop(true),
            ),
          ),
        ],
      ),
    );
  }
}

/// Names what the refusal would cost and offers to force the cleanup anyway.
///
/// This alert is itself the confirmation, so it asks once: Cancel, the safe
/// default that dismissing or Escape also gives, or a destructive Delete
/// anyway. Keeping the worktree is not on offer — the refusals that reach here
/// are the user's own uncommitted work, or an unexpected branch, which only
/// older bridges report.
Future<bool> showSessionArchiveRefusedAlert({
  required BuildContext context,
  required SessionCleanupRejection rejection,
}) async {
  final loc = context.loc;
  final forced = await showPregoModal<bool>(
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
          PregoSheetActions(
            secondary: PregoButtonsSolid(
              label: loc.sessionListDeleteConfirmCancel,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed: () => sheetContext.pop(),
            ),
            primary: PregoButtonsSolid(
              label: loc.sessionListCleanupDeleteAnyway,
              hierarchy: PregoButtonsSolidHierarchy.primary,
              type: PregoButtonsSolidType.destructive,
              size: PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed: () => sheetContext.pop(true),
            ),
          ),
        ],
      ),
    ),
  );
  return forced ?? false;
}
