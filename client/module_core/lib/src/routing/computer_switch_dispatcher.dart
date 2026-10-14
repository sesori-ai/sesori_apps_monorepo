import "package:injectable/injectable.dart";

import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../platform/route_dispatcher.dart";
import "../services/selected_computer_service.dart";
import "app_routes.dart";

/// The single entry point for switching computers. A switch always lands on
/// the Projects root of the new computer, so no deeper screen ever has its
/// computer change underneath it.
@lazySingleton
class ComputerSwitchDispatcher({
  required final SelectedComputerService _selectedComputerService,
  required final RouteDispatcher _routeDispatcher,
}) {
  Future<void> switchTo({required String bridgeId, required ComputerSwitchSource source}) async {
    await _selectedComputerService.select(bridgeId: bridgeId, source: source);
    _routeDispatcher.replaceStack(stack: RouteStack(paths: [const AppRoute.projects().buildPath()]));
  }
}
