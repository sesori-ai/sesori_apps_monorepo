import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";

/// Names the harnesses a refresh's import could not read from, once, when the
/// import settles. The scan row keeps its progress until then, so this never
/// replaces it mid-run.
class const CatalogScanFailureAlerts({
  super.key,

  /// The navigator whose overlay shows the alert, for a shell that mounts
  /// this above its router. Null where this already sits under a navigator.
  required final GlobalKey<NavigatorState>? navigatorKey,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionListRefreshCubit, SessionListRefreshState>(
      listenWhen: (previous, current) => previous.scan != current.scan,
      listener: (context, state) {
        final failedPluginIds = switch (state.scan) {
          CatalogRescanFailed(:final failedPluginIds) ||
          CatalogRescanPartlyFailed(:final failedPluginIds) => failedPluginIds,
          CatalogRescanIdle() ||
          CatalogRescanPreparingOne() ||
          CatalogRescanStarting() ||
          CatalogRescanReading() ||
          CatalogRescanSaving() ||
          CatalogRescanSucceeded() => null,
        };
        if (failedPluginIds == null) return;
        final names = [for (final pluginId in failedPluginIds) PregoBrandLogo.displayNameFor(pluginId)];
        final overlay = navigatorKey?.currentState?.overlay;
        final presenter = navigatorKey == null
            ? PregoPopupAlertPresenter.of(context)
            : overlay == null
            ? null
            : PregoPopupAlertPresenter.fromOverlayState(overlay);
        presenter?.show(
          title: context.loc.catalogScanImportFailedAlert(names.length, names.join(", ")),
          variant: PregoPopupAlertsNotificationsVariant.error,
        );
      },
      child: child,
    );
  }
}
