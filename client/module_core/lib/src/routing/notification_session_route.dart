import "../platform/notification_open_request.dart";
import "../platform/route_dispatcher.dart";
import "../platform/route_source.dart";
import "app_routes.dart";

/// Opens what [request] points at on top of the home screen: a session, or a
/// task's page over the Scheduled page, so going back passes through the list.
///
/// Replacing the stack tears down a live session detail screen and builds a new
/// one, whose cubit starts from `loading` and refetches the whole session before
/// any prompt can be shown. With [keepIfAlreadyShown], a request for the
/// editable session or the task already on top changes nothing: the mounted
/// screen keeps itself current, so navigating again only costs a reload. Pass
/// false after a computer switch, since the screen on top then belongs to the
/// previous computer.
void openNotificationTarget({
  required NotificationOpenRequest request,
  required RouteDispatcher routeDispatcher,
  required RouteSource routeSource,
  required bool keepIfAlreadyShown,
}) {
  final location = switch (routeSource.currentLocation) {
    final location? when keepIfAlreadyShown => Uri.parse(location),
    _ => null,
  };
  final List<AppRoute> stack;
  switch (request.target) {
    case NotificationOpenSession(:final projectId, :final sessionId, :final sessionTitle):
      final sessionDetail = AppRouteSessionDetail(
        projectId: projectId,
        projectName: null,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
        readOnly: false,
        fromLaunch: false,
      );
      if (location != null && sessionDetail.showsEditableLocation(location: location)) return;
      stack = [const AppRoute.home(), sessionDetail];
    case NotificationOpenTask(:final taskId):
      final taskDetail = AppRouteScheduledTaskDetail(taskId: taskId);
      if (location != null && location.path == taskDetail.buildPath()) return;
      stack = [const AppRoute.home(), const AppRoute.scheduledTasks(), taskDetail];
  }
  routeDispatcher.replaceStack(
    stack: RouteStack(paths: stack.map((route) => route.buildPath()).toList(growable: false)),
  );
}
