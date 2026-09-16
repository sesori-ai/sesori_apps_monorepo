import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/platform/desktop_route_dispatcher.dart";

void main() {
  test("dismisses popups then replaces a typed stack after the router is ready", () async {
    final ready = Completer<void>();
    final operations = <String>[];
    final dispatcher = DesktopRouteDispatcher.test(
      goRoute: (route) => operations.add("go:$route"),
      pushRoute: (route) async {
        operations.add("push:$route");
      },
      dismissPopups: () => operations.add("dismiss"),
      routerReady: ready.future,
    );

    dispatcher.dismissPopups();
    dispatcher.replaceStack(
      stack: RouteStack(paths: const <String>["/projects", "/projects/p1/sessions", "/sessions/s1"]),
    );
    await Future<void>.delayed(Duration.zero);
    expect(operations, isEmpty);

    ready.complete();
    await dispatcher.flushPendingForTesting();

    expect(
      operations,
      <String>["dismiss", "go:/projects", "push:/projects/p1/sessions", "push:/sessions/s1"],
    );
  });

  test("ignores an empty replacement stack", () async {
    final operations = <String>[];
    Future<void> recordRoute(String route) async {
      operations.add(route);
    }

    final dispatcher = DesktopRouteDispatcher.test(
      goRoute: operations.add,
      pushRoute: recordRoute,
      dismissPopups: () => operations.add("dismiss"),
      routerReady: Future<void>.value(),
    );

    dispatcher.replaceStack(stack: RouteStack(paths: const <String>[]));
    await dispatcher.flushPendingForTesting();

    expect(operations, isEmpty);
  });

  test("a failed popup dismissal is observable and does not strand later navigation", () async {
    final operations = <String>[];
    final dispatcher = DesktopRouteDispatcher.test(
      goRoute: operations.add,
      pushRoute: (_) async {},
      dismissPopups: () => throw StateError("popup failure"),
      routerReady: Future<void>.value(),
    );
    dispatcher.dismissPopups();
    dispatcher.replaceStack(stack: RouteStack(paths: const ["/projects"]));
    await dispatcher.flushPendingForTesting();
    expect(operations, ["/projects"]);
  });
}
