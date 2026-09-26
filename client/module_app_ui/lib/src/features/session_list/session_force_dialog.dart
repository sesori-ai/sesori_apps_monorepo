part of "session_list_action_dispatcher.dart";

// ---------------------------------------------------------------------------
// Force delete dialog (409 rejection)
// ---------------------------------------------------------------------------

/// Names what the refusal would cost and offers to force the cleanup anyway.
///
/// This dialog is itself the confirmation, so it asks once: Cancel, the safe
/// default that dismissing or Escape also gives, or a destructive Delete
/// anyway. Keeping the worktree is not on offer — the refusals that reach here
/// are the user's own uncommitted work.
Future<void> _showForceDialog({
  required BuildContext context,
  required SessionListCubit cubit,
  required String sessionId,
  required SessionCleanupRejection rejection,
  required SessionDeletedRouteHandler? onSessionDeleted,
}) {
  final loc = context.loc;

  return showPregoModal<void>(
    context: context,
    title: loc.sessionListForceDeleteTitle,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.sessionListForceMessage,
            style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
          ),
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
              onPressed: () {
                sheetContext.pop();
                final release = cubit.retainActionScope();
                unawaited(
                  _deleteSession(
                    context: context,
                    cubit: cubit,
                    sessionId: sessionId,
                    deleteWorktree: true,
                    force: true,
                    onSessionDeleted: onSessionDeleted,
                  ).whenComplete(release),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

String _describeCleanupIssue({required AppLocalizations loc, required CleanupIssue issue}) => switch (issue) {
  CleanupIssueUnstagedChanges() => loc.sessionListCleanupIssueUnstagedChanges,
  CleanupIssueSharedWorktree() => loc.sessionListCleanupIssueSharedWorktree,
};
