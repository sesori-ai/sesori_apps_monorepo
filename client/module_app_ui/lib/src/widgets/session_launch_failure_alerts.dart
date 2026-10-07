import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";
import "../features/project_list/widgets/project_tile.dart";

/// Tells the user, once, that a new session they left could not be created,
/// as its launching row leaves the lists. A failure while its composer is
/// still open restores the draft there instead and never reaches this.
class const SessionLaunchFailureAlerts({
  super.key,

  /// The navigator whose overlay shows the alert, for a shell that mounts
  /// this above its router. Null where this already sits under a navigator.
  required final GlobalKey<NavigatorState>? navigatorKey,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<SessionLaunchFailureAlerts> createState() => _SessionLaunchFailureAlertsState();
}

class _SessionLaunchFailureAlertsState() extends State<SessionLaunchFailureAlerts> {
  late final StreamSubscription<SessionLaunchFailedAfterLeaving> _failures;

  @override
  void initState() {
    super.initState();
    _failures = context.read<SessionLaunchCubit>().failuresAfterLeaving.listen(_onFailure);
  }

  @override
  void dispose() {
    unawaited(_failures.cancel());
    super.dispose();
  }

  void _onFailure(SessionLaunchFailedAfterLeaving failure) {
    final navigatorKey = widget.navigatorKey;
    final overlay = navigatorKey?.currentState?.overlay;
    final presenter = navigatorKey == null
        ? PregoPopupAlertPresenter.of(context)
        : overlay == null
        ? null
        : PregoPopupAlertPresenter.fromOverlayState(overlay);
    final loc = context.loc;
    presenter?.show(
      title: loc.newSessionFailedAfterLeaving(failure.projectName ?? hostPathBasename(path: failure.projectId)),
      variant: PregoPopupAlertsNotificationsVariant.error,
      // Creation is not idempotent, so the session may exist after all.
      content: PregoPopupAlertContent(message: loc.newSessionCreationDuplicateWarning),
      // Two sentences, read away from the composer they concern.
      duration: const Duration(seconds: 8),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
