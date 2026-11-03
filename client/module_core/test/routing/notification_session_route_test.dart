import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/platform/notification_open_request.dart";
import "package:sesori_dart_core/src/platform/route_dispatcher.dart";
import "package:sesori_dart_core/src/platform/route_source.dart";
import "package:sesori_dart_core/src/routing/app_routes.dart";
import "package:sesori_dart_core/src/routing/notification_session_route.dart";
import "package:test/test.dart";

class _MockRouteSource() extends Mock implements RouteSource;

class _RecordingRouteDispatcher() implements RouteDispatcher {
  final List<RouteStack> replacedStacks = <RouteStack>[];

  @override
  void dismissPopups() {}

  @override
  void replaceStack({required RouteStack stack}) => replacedStacks.add(stack);
}

const NotificationOpenRequest _request = NotificationOpenRequest(
  projectId: "project-1",
  sessionId: "session-1",
  sessionTitle: "Weekly planning",
  accountId: null,
  bridgeId: null,
);

void main() {
  late _MockRouteSource routeSource;
  late _RecordingRouteDispatcher routeDispatcher;

  setUp(() {
    routeSource = _MockRouteSource();
    routeDispatcher = _RecordingRouteDispatcher();
  });

  void open({required String? location, required bool keepIfAlreadyShown}) {
    when(() => routeSource.currentLocation).thenReturn(location);
    openNotificationSession(
      request: _request,
      routeDispatcher: routeDispatcher,
      routeSource: routeSource,
      keepIfAlreadyShown: keepIfAlreadyShown,
    );
  }

  test("replaces the stack with the home and the editable session", () {
    open(location: null, keepIfAlreadyShown: true);

    expect(routeDispatcher.replacedStacks.single.paths, [
      const AppRoute.home().buildPath(),
      const AppRoute.sessionDetail(
        projectId: "project-1",
        projectName: null,
        sessionId: "session-1",
        sessionTitle: "Weekly planning",
        readOnly: false,
        fromLaunch: false,
      ).buildPath(),
    ]);
  });

  test("leaves the stack alone when that editable session is already on top", () {
    // Display-only query parameters must not defeat the match.
    open(location: "/sessions/project-1/session-1?readOnly=false&title=Renamed", keepIfAlreadyShown: true);

    expect(routeDispatcher.replacedStacks, isEmpty);
  });

  test("rebuilds after a computer switch even when that session is on top", () {
    open(location: "/sessions/project-1/session-1", keepIfAlreadyShown: false);

    expect(routeDispatcher.replacedStacks, hasLength(1));
  });

  test("rebuilds when that session is shown read-only", () {
    // Background tasks and subtasks open the same session on the read-only
    // route, which renders without the composer.
    open(location: "/sessions/project-1/session-1?readOnly=true", keepIfAlreadyShown: true);

    expect(routeDispatcher.replacedStacks, hasLength(1));
  });

  test("rebuilds when a different session is on top", () {
    open(location: "/sessions/project-1/session-2", keepIfAlreadyShown: true);

    expect(routeDispatcher.replacedStacks, hasLength(1));
  });

  test("rebuilds when a pushed screen sits above that session", () {
    open(location: "/sessions/project-1/session-1/diffs", keepIfAlreadyShown: true);

    expect(routeDispatcher.replacedStacks, hasLength(1));
  });
}
