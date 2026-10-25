import "package:injectable/injectable.dart";

import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../platform/route_dispatcher.dart";
import "../services/selected_computer_service.dart";
import "app_routes.dart";

/// The single entry point for switching computers. A switch always lands on
/// the Projects root of the new computer: the stack is replaced before the
/// connection retargets, so no deeper screen ever has its computer change
/// underneath it.
@lazySingleton
class ComputerSwitchDispatcher({
  required final SelectedComputerService _selectedComputerService,
  required final RouteDispatcher _routeDispatcher,
}) {
  Future<void> switchTo({required String bridgeId, required ComputerSwitchSource source}) async {
    _routeDispatcher.replaceStack(stack: RouteStack(paths: [const AppRoute.home().buildPath()]));
    await _selectedComputerService.select(bridgeId: bridgeId, source: source);
  }
}
