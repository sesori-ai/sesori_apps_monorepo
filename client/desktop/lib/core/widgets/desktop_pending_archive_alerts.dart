import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

/// Archives [session] behind the Undo window. [context] must sit under
/// `DesktopCockpitCubitProvider`.
void archiveSessionWithUndo({
  required BuildContext context,
  required Session session,
  required bool deleteWorktree,
}) => context.read<PendingSessionArchiveCubit>().archive(session: session, deleteWorktree: deleteWorktree);

/// The one place that tells the user what a pending archive is doing: the
/// "Archived" alert with Undo, then the refusal alert or the error toast.
class const DesktopPendingArchiveAlerts({super.key, required final Widget child}) extends StatefulWidget {
  @override
  State<DesktopPendingArchiveAlerts> createState() => _DesktopPendingArchiveAlertsState();
}

class _DesktopPendingArchiveAlertsState() extends State<DesktopPendingArchiveAlerts> {
  late final StreamSubscription<PendingSessionArchiveOutcome> _outcomes;

  @override
  void initState() {
    super.initState();
    _outcomes = context.read<PendingSessionArchiveCubit>().outcomes.listen(_onOutcome);
  }

  @override
  void dispose() {
    unawaited(_outcomes.cancel());
    super.dispose();
  }

  void _offerUndo() {
    final cubit = context.read<PendingSessionArchiveCubit>();
    final presenter = PregoPopupAlertPresenter.of(context);
    presenter.show(
      title: context.loc.sessionListArchived,
      variant: PregoPopupAlertsNotificationsVariant.success,
      // The presenter's default is shorter than the window the offer stands for.
      duration: PendingSessionArchiveCubit.undoWindow,
      content: PregoPopupAlertContent(
        primaryAction: PregoPopupAlertsNotificationsAction(
          label: context.loc.sessionListArchiveUndo,
          onPressed: () {
            cubit.undo();
            presenter.dismiss();
          },
        ),
      ),
    );
  }

  Future<void> _onOutcome(PendingSessionArchiveOutcome outcome) async {
    if (!mounted) return;
    switch (outcome) {
      case PendingSessionArchiveCommitted():
        return;
      case PendingSessionArchiveFailed():
        PregoPopupAlertPresenter.of(context).show(
          title: context.loc.sessionListArchiveFailed,
          variant: PregoPopupAlertsNotificationsVariant.error,
        );
      case PendingSessionArchiveRefused(:final session, :final rejection):
        final cubit = context.read<PendingSessionArchiveCubit>();
        final choice = await showSessionArchiveRefusedAlert(context: context, rejection: rejection);
        if (choice == null) return;
        // The user has already decided twice; no second Undo window.
        final deleteAnyway = choice == SessionArchiveRefusedChoice.deleteAnyway;
        unawaited(cubit.commitNow(session: session, deleteWorktree: deleteAnyway, force: deleteAnyway));
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<PendingSessionArchiveCubit, PendingSessionArchiveState>(
    listenWhen: (previous, current) => current.window is PendingArchiveOpen && current.window != previous.window,
    listener: (_, _) => _offerUndo(),
    child: widget.child,
  );
}
