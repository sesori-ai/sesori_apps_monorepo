import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";
import "computer_menu.dart";

/// Announces a computer newly linked to the account, such as "workstation is
/// now linked", with a Switch action, above whatever screen is showing.
class const LinkedComputerAlerts({
  super.key,

  /// The navigator whose overlay shows the alert, for a shell that mounts
  /// this above its router. Null where this already sits under a navigator.
  required final GlobalKey<NavigatorState>? navigatorKey,
  required final ComputerSwitchCallback onSwitchComputer,
  required final Widget child,
}) extends StatelessWidget {
  /// Long enough to read a name and decide, unlike the default for a status.
  static const Duration _duration = Duration(seconds: 8);

  PregoPopupAlertPresenter? _presenter({required BuildContext context}) {
    final key = navigatorKey;
    if (key == null) return PregoPopupAlertPresenter.of(context);
    final overlay = key.currentState?.overlay;
    return overlay == null ? null : PregoPopupAlertPresenter.fromOverlayState(overlay);
  }

  void _show({required BuildContext context, required LinkedComputerAlert alert}) {
    final presenter = _presenter(context: context);
    if (presenter == null) return;
    presenter.show(
      title: context.loc.linkedComputerAlertTitle(alert.name),
      variant: PregoPopupAlertsNotificationsVariant.success,
      duration: _duration,
      content: PregoPopupAlertContent(
        primaryAction: PregoPopupAlertsNotificationsAction(
          label: context.loc.linkedComputerAlertSwitch,
          onPressed: () {
            presenter.dismiss();
            onSwitchComputer(bridgeId: alert.bridgeId, source: ComputerSwitchSource.alert);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocListener<LinkedComputerAlertCubit, LinkedComputerAlert?>(
    listener: (context, alert) {
      if (alert != null) _show(context: context, alert: alert);
    },
    child: child,
  );
}
