import "../platform/notification_open_request.dart";
import "../platform/route_dispatcher.dart";
import "../platform/route_source.dart";
import "app_routes.dart";

/// Opens the session [request] points at, on top of the home screen.
///
/// Replacing the stack tears down a live session detail screen and builds a new
/// one, whose cubit starts from `loading` and refetches the whole session before
/// any prompt can be shown. With [keepIfAlreadyShown], a request for the
/// editable session already on top changes nothing: the mounted screen surfaces
/// the prompt through its own event stream, so navigating again only costs a
/// reload. Pass false after a computer switch, since the screen on top then
/// belongs to the previous computer.
void openNotificationSession({
  required NotificationOpenRequest request,
  required RouteDispatcher routeDispatcher,
  required RouteSource routeSource,
  required bool keepIfAlreadyShown,
}) {
  final sessionDetail = AppRouteSessionDetail(
    projectId: request.projectId,
    projectName: null,
    sessionId: request.sessionId,
    sessionTitle: request.sessionTitle,
    readOnly: false,
    fromLaunch: false,
  );
  final location = routeSource.currentLocation;
  if (keepIfAlreadyShown && location != null && sessionDetail.showsEditableLocation(location: Uri.parse(location))) {
    return;
  }
  routeDispatcher.replaceStack(
    stack: RouteStack(
      paths: [
        const AppRoute.home(),
        sessionDetail,
      ].map((route) => route.buildPath()).toList(growable: false),
    ),
  );
}
