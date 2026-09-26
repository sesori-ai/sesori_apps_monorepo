import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";
import "../features/session_list/session_list_action_dispatcher.dart";

/// The one place that tells the user what a pending archive is doing: the
/// "Archived" alert with Undo, then the refusal alert or the error toast.
class const PendingArchiveAlerts({
  super.key,

  /// The navigator whose overlay shows the alerts, for a shell that mounts
  /// this above its router. Null where this already sits under a navigator.
  required final GlobalKey<NavigatorState>? navigatorKey,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<PendingArchiveAlerts> createState() => _PendingArchiveAlertsState();
}

class _PendingArchiveAlertsState() extends State<PendingArchiveAlerts> {
  late final StreamSubscription<PendingSessionArchiveOutcome> _outcomes;

  /// A failure that arrived while an Undo alert was showing. The presenter
  /// holds one alert at a time, so it waits for the Undo window to close.
  bool _failureHeld = false;

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

  /// Null before the shell's navigator has mounted.
  PregoPopupAlertPresenter? get _presenter {
    final navigatorKey = widget.navigatorKey;
    if (navigatorKey == null) return PregoPopupAlertPresenter.of(context);
    final overlay = navigatorKey.currentState?.overlay;
    return overlay == null ? null : PregoPopupAlertPresenter.fromOverlayState(overlay);
  }

  void _offerUndo() {
    final presenter = _presenter;
    if (presenter == null) return;
    final cubit = context.read<PendingSessionArchiveCubit>();
    presenter.show(
      title: context.loc.sessionListArchived,
      variant: PregoPopupAlertsNotificationsVariant.success,
      // The presenter's default is shorter than the window the offer stands for.
      duration: PendingSessionArchiveCubit.undoWindow,
      content: PregoPopupAlertContent(
        primaryAction: PregoPopupAlertsNotificationsAction(
          label: context.loc.sessionListArchiveUndo,
          onPressed: () {
            presenter.dismiss();
            cubit.undo();
          },
        ),
      ),
    );
  }

  void _showFailure() {
    _presenter?.show(
      title: context.loc.sessionListArchiveFailed,
      variant: PregoPopupAlertsNotificationsVariant.error,
    );
  }

  /// Tells the user the archive kept a worktree another session still uses.
  /// Informational: there was nothing to decide, and the Undo window is over.
  void _showWorktreeKept() {
    _presenter?.show(
      title: context.loc.sessionListArchived,
      content: PregoPopupAlertContent(message: context.loc.sessionListCleanupWorktreeKept),
    );
  }

  void _onWindowChanged(PendingArchiveWindow window) {
    switch (window) {
      case PendingArchiveOpen():
        _offerUndo();
      case PendingArchiveIdle():
        // Archiving inside a window passes through idle on its way to the next
        // window; the failure stays held for that one.
        if (!_failureHeld || context.read<PendingSessionArchiveCubit>().state.window is PendingArchiveOpen) return;
        _failureHeld = false;
        _showFailure();
    }
  }

  Future<void> _onOutcome(PendingSessionArchiveOutcome outcome) async {
    if (!mounted) return;
    switch (outcome) {
      case PendingSessionArchiveCommitted():
        return;
      case PendingSessionArchiveWorktreeKept():
        _showWorktreeKept();
      case PendingSessionArchiveFailed():
        if (context.read<PendingSessionArchiveCubit>().state.window is PendingArchiveOpen) {
          _failureHeld = true;
        } else {
          _showFailure();
        }
      case PendingSessionArchiveRefused(:final session, :final rejection):
        final cubit = context.read<PendingSessionArchiveCubit>();
        final navigatorKey = widget.navigatorKey;
        final dialogContext = navigatorKey == null ? context : navigatorKey.currentContext;
        if (dialogContext == null) return;
        if (!await showSessionArchiveRefusedAlert(context: dialogContext, rejection: rejection)) return;
        // The alert was the confirmation; no second Undo window.
        unawaited(cubit.commitForced(session: session));
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<PendingSessionArchiveCubit, PendingSessionArchiveState>(
    listenWhen: (previous, current) => current.window != previous.window,
    listener: (_, state) => _onWindowChanged(state.window),
    child: widget.child,
  );
}
