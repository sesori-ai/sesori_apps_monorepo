import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/go_router_route_dispatcher.dart";

void main() {
  test("replaceStack recovers after a failed replace and still serializes later requests", () async {
    final goCalls = <String>[];
    final pushCalls = <String>[];
    final firstPushCompleter = Completer<void>();
    var pushInvocation = 0;

    final dispatcher = GoRouterRouteDispatcher.test(
      goRoute: goCalls.add,
      pushRoute: (route) {
        pushCalls.add(route);
        pushInvocation += 1;
        if (pushInvocation == 1) {
          return firstPushCompleter.future;
        }
        return Future<void>.value();
      },
    );

    dispatcher.replaceStack(
      stack: RouteStack(
        paths: [
          const AppRoute.projects().buildPath(),
          const AppRoute.sessions(projectId: "p1", projectName: "Project 1").buildPath(),
        ],
      ),
    );
    firstPushCompleter.completeError(Exception("boom"));
    await expectLater(dispatcher.flushPendingForTesting(), throwsException);

    dispatcher.replaceStack(
      stack: RouteStack(
        paths: [
          const AppRoute.projects().buildPath(),
          const AppRoute.sessions(projectId: "p2", projectName: "Project 2").buildPath(),
        ],
      ),
    );
    await dispatcher.flushPendingForTesting();

    expect(goCalls, ["/projects", "/projects"]);
    expect(pushCalls, [
      "/projects/p1/sessions?name=Project+1",
      "/projects/p2/sessions?name=Project+2",
    ]);
  });
}
