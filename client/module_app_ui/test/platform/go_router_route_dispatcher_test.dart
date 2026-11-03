import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

void main() {
  test("dismisses popups then replaces a typed stack after the router is ready", () async {
    final ready = Completer<void>();
    final operations = <String>[];
    final dispatcher = GoRouterRouteDispatcher.test(
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

    final dispatcher = GoRouterRouteDispatcher.test(
      goRoute: operations.add,
      pushRoute: recordRoute,
      dismissPopups: () => operations.add("dismiss"),
      routerReady: Future<void>.value(),
    );

    dispatcher.replaceStack(stack: RouteStack(paths: const <String>[]));
    await dispatcher.flushPendingForTesting();

    expect(operations, isEmpty);
  });

  test("a failed popup dismissal does not strand later navigation", () async {
    final operations = <String>[];
    final dispatcher = GoRouterRouteDispatcher.test(
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

  testWidgets("closes the popups on every given navigator and keeps their pages", (tester) async {
    final rootNavigatorKey = GlobalKey<NavigatorState>();
    final shellNavigatorKey = GlobalKey<NavigatorState>();
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: "/page",
      routes: [
        ShellRoute(
          navigatorKey: shellNavigatorKey,
          builder: (_, _, child) => child,
          routes: [GoRoute(path: "/page", builder: (_, _) => const Text("page"))],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    final page = tester.element(find.text("page"));
    showDialog<void>(
      context: page,
      useRootNavigator: false,
      builder: (_) => const Dialog(child: Text("shell popup")),
    );
    showDialog<void>(
      context: page,
      builder: (_) => const Dialog(child: Text("root popup")),
    );
    await tester.pumpAndSettle();
    expect(find.text("shell popup"), findsOneWidget);
    expect(find.text("root popup"), findsOneWidget);

    final dispatcher = GoRouterRouteDispatcher(
      router: router,
      routerReady: Future<void>.value(),
      popupNavigatorKeys: [shellNavigatorKey, rootNavigatorKey],
    );
    dispatcher.dismissPopups();
    await dispatcher.flushPendingForTesting();
    await tester.pumpAndSettle();

    expect(find.text("shell popup"), findsNothing);
    expect(find.text("root popup"), findsNothing);
    expect(tester.element(find.text("page")), same(page));
  });
}
