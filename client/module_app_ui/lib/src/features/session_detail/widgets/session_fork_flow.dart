import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// How long a fork runs before a Forking alert answers the tap.
const Duration _forkProgressDelay = Duration(milliseconds: 300);

/// A transcript message menu's "Fork from here".
PregoMenuItem forkFromHereMenuItem({required BuildContext context, required VoidCallback onTap}) => PregoMenuItem(
  leadingIcon: TablerRegular.git_fork,
  title: context.loc.sessionDetailForkFromHere,
  subtitle: null,
  isSelected: false,
  shortcutLabel: null,
  onTap: onTap,
);

/// Runs [fork] and answers the tap: a Forking alert once it takes longer
/// than a moment, then [open] with the fork, or an alert saying why there is
/// none. When an archived session's worktree is gone with nothing kept, it
/// asks before forking into a new worktree from where the session began.
/// [context] must outlive the menu that asked, as the session page or list
/// owner does.
Future<void> runSessionFork({
  required BuildContext context,
  required Future<SessionForkResult> Function({required bool recreateFromBase}) fork,
  required void Function({required Session fork}) open,
}) async {
  final loc = context.loc;
  final presenter = PregoPopupAlertPresenter.of(context);
  var recreateFromBase = false;
  while (true) {
    var progressShown = false;
    final progress = Timer(_forkProgressDelay, () {
      progressShown = true;
      presenter.show(
        title: loc.sessionForkForking,
        variant: PregoPopupAlertsNotificationsVariant.loading,
        duration: null,
      );
    });
    final result = await fork(recreateFromBase: recreateFromBase);
    progress.cancel();
    if (progressShown) presenter.dismiss();
    switch (result) {
      case SessionForked(:final session):
        // Left meanwhile: the fork waits in the session list.
        if (context.mounted) open(fork: session);
        return;
      case SessionForkWorktreeBranchMissing() when !recreateFromBase:
        if (!context.mounted || !await _confirmNewWorktree(context: context)) return;
        recreateFromBase = true;
      case SessionForkNothingToFork():
        presenter.show(
          title: loc.sessionForkNothingToFork,
          variant: PregoPopupAlertsNotificationsVariant.warning,
          content: PregoPopupAlertContent(message: loc.sessionForkNothingToForkBody),
        );
        return;
      case SessionForkUnavailable(:final reason) || SessionForkRejected(:final reason):
        _showRefused(
          presenter: presenter,
          title: loc.sessionForkRefused,
          message: reason ?? loc.sessionForkRefusedBody,
        );
        return;
      // The bridge answers a retry with a new worktree; this one is a refusal it never gives.
      case SessionForkWorktreeBranchMissing():
        _showRefused(presenter: presenter, title: loc.sessionForkRefused, message: loc.sessionForkRefusedBody);
        return;
      case SessionForkFailed():
        presenter.show(title: loc.sessionForkFailed, variant: PregoPopupAlertsNotificationsVariant.error);
        return;
    }
  }
}

void _showRefused({required PregoPopupAlertPresenter presenter, required String title, required String message}) =>
    presenter.show(
      title: title,
      variant: PregoPopupAlertsNotificationsVariant.error,
      content: PregoPopupAlertContent(message: message),
    );

/// Asks whether the fork of an archived session whose worktree is gone may
/// start in a new worktree from where the session began. True to create it.
Future<bool> _confirmNewWorktree({required BuildContext context}) async {
  final loc = context.loc;
  final create = await showPregoModal<bool>(
    context: context,
    title: loc.sessionForkWorktreeMissingTitle,
    builder: (sheetContext) {
      final prego = sheetContext.prego;
      return Padding(
        padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc.sessionForkWorktreeMissingBody,
              style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
            ),
            const SizedBox(height: PregoSpacing.x2l),
            PregoButtonsSolid(
              key: const Key("fork_worktree_missing_create"),
              label: loc.sessionForkWorktreeMissingCreate,
              hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
              size: PregoButtonsSolidSize.xl,
              fullWidth: true,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            const SizedBox(height: PregoSpacing.md),
            PregoButtonsSolid(
              key: const Key("fork_worktree_missing_cancel"),
              label: loc.sessionForkCancel,
              hierarchy: PregoButtonsSolidHierarchy.tertiary,
              size: PregoButtonsSolidSize.xl,
              fullWidth: true,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      );
    },
  );
  return create ?? false;
}
