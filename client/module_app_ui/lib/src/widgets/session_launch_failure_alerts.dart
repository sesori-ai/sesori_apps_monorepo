import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";

/// Tells the user, once, that new sessions they left could not be created,
/// as their launching rows leave the lists. A failure while its composer is
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
  final List<SessionLaunchFailedAfterLeaving> _batch = [];
  Timer? _flush;

  @override
  void initState() {
    super.initState();
    _failures = context.read<SessionLaunchCubit>().failuresAfterLeaving.listen((failure) {
      // Failures that land together, such as every create in flight when the
      // bridge goes away, share one alert instead of replacing each other.
      _batch.add(failure);
      _flush ??= Timer(_batchWindow, _show);
    });
  }

  @override
  void dispose() {
    _flush?.cancel();
    unawaited(_failures.cancel());
    super.dispose();
  }

  void _show() {
    final failures = [..._batch];
    _batch.clear();
    _flush = null;
    final navigatorKey = widget.navigatorKey;
    final overlay = navigatorKey?.currentState?.overlay;
    final presenter = navigatorKey == null
        ? PregoPopupAlertPresenter.of(context)
        : overlay == null
        ? null
        : PregoPopupAlertPresenter.fromOverlayState(overlay);
    final loc = context.loc;
    final names = {for (final failure in failures) failure.projectName};
    presenter?.show(
      title: names.contains(null)
          ? loc.newSessionFailedAfterLeavingUnnamed(failures.length)
          : loc.newSessionFailedAfterLeaving(failures.length, names.nonNulls.join(", ")),
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

const Duration _batchWindow = Duration(milliseconds: 300);
