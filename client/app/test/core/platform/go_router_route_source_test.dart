import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/go_router_route_source.dart";

/// Mirrors the production route tree's shape — the session routes nested under
/// a [ShellRoute] — with placeholder screens, so navigation needs no DI.
GoRouter _router() {
  return GoRouter(
    initialLocation: AppRouteDef.splash.path,
    routes: [
      GoRoute(path: AppRouteDef.splash.path, builder: (_, _) => const Text("splash")),
      GoRoute(
        path: AppRouteDef.projects.path,
        builder: (_, _) => const Text("projects"),
        routes: [
          ShellRoute(
            builder: (_, _, child) => child,
            routes: [
              GoRoute(
                path: ":$projectIdPathParam/sessions",
                builder: (_, _) => const Text("sessions"),
                routes: [
                  GoRoute(path: "new", builder: (_, _) => const Text("new session")),
                  GoRoute(path: ":$sessionIdPathParam", builder: (_, _) => const Text("session detail")),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRouteDef.settings.path,
        builder: (_, _) => const Text("settings"),
        routes: [
          GoRoute(path: "profile", builder: (_, _) => const Text("profile")),
        ],
      ),
    ],
  );
}

void main() {
  late GoRouter router;
  late GoRouterRouteSource routeSource;

  setUp(() {
    router = _router();
    routeSource = GoRouterRouteSource.test(router: router);
  });

  tearDown(() async {
    await routeSource.onDispose();
    router.dispose();
  });

  Future<void> pumpRouter(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets("reports declaratively navigated screens", (tester) async {
    await pumpRouter(tester);

    router.go(const AppRoute.projects().buildPath());
    await tester.pumpAndSettle();

    expect(routeSource.currentRouteStream.value, AppRouteDef.projects);
  });

  testWidgets("reports imperatively pushed screens", (tester) async {
    await pumpRouter(tester);
    router.go(const AppRoute.projects().buildPath());
    await tester.pumpAndSettle();

    // A push leaves RouteMatchList.uri on /projects, so only walking the match
    // tree reveals settings as the screen the user is actually on.
    unawaited(router.push<void>(const AppRoute.settings().buildPath()));
    await tester.pumpAndSettle();

    expect(routeSource.currentRouteStream.value, AppRouteDef.settings);
  });

  testWidgets("currentLocation keeps the query of a pushed route", (tester) async {
    await pumpRouter(tester);
    router.go(const AppRoute.projects().buildPath());
    await tester.pumpAndSettle();

    unawaited(
      router.push<void>(
        const AppRoute.sessionDetail(
          projectId: "p1",
          projectName: null,
          sessionId: "s1",
          sessionTitle: null,
          readOnly: true,
          bridgeId: null,
        ).buildPath(),
      ),
    );
    await tester.pumpAndSettle();

    // `readOnly` lives in the query and is the only thing separating the
    // read-only session screen from the editable one, so a location that drops
    // the query cannot tell them apart.
    final location = Uri.parse(routeSource.currentLocation!);
    expect(location.path, "/projects/p1/sessions/s1");
    expect(location.queryParameters["readOnly"], "true");
  });

  testWidgets("reports pushed screens nested in the session shell", (tester) async {
    await pumpRouter(tester);
    router.go(const AppRoute.projects().buildPath());
    await tester.pumpAndSettle();

    unawaited(
      router.push<void>(
        const AppRoute.sessions(projectId: "p1", projectName: null).buildPath(),
      ),
    );
    await tester.pumpAndSettle();
    expect(routeSource.currentRouteStream.value, AppRouteDef.sessions);

    unawaited(router.push<void>(const AppRoute.newSession(projectId: "p1", projectName: null).buildPath()));
    await tester.pumpAndSettle();

    expect(routeSource.currentRouteStream.value, AppRouteDef.newSession);
  });

  testWidgets("reports the revealed screen after popping a pushed screen", (tester) async {
    await pumpRouter(tester);
    router.go(const AppRoute.projects().buildPath());
    await tester.pumpAndSettle();
    unawaited(router.push<void>(const AppRoute.settings().buildPath()));
    await tester.pumpAndSettle();
    unawaited(router.push<void>(const AppRoute.settingsProfile().buildPath()));
    await tester.pumpAndSettle();
    expect(routeSource.currentRouteStream.value, AppRouteDef.settingsProfile);

    router.pop<void>();
    await tester.pumpAndSettle();

    expect(routeSource.currentRouteStream.value, AppRouteDef.settings);
  });

  testWidgets("matches every route in the table to its own definition", (tester) async {
    // Concrete locations for the whole table, so a new route cannot silently
    // be swallowed by a sibling's parameter segment.
    const locations = {
      AppRouteDef.splash: "/splash",
      AppRouteDef.login: "/login",
      AppRouteDef.projects: "/projects",
      AppRouteDef.deviceCanvasSession: "/sessions/s1",
      AppRouteDef.settings: "/settings",
      AppRouteDef.settingsNotifications: "/settings/notifications",
      AppRouteDef.settingsHarnesses: "/settings/harnesses",
      AppRouteDef.settingsProfile: "/settings/profile",
      AppRouteDef.sessions: "/projects/p1/sessions",
      AppRouteDef.newSession: "/projects/p1/sessions/new",
      AppRouteDef.sessionDetail: "/projects/p1/sessions/s1",
      AppRouteDef.sessionDiffs: "/projects/p1/sessions/s1/diffs",
    };
    expect(locations.keys, unorderedEquals(AppRouteDef.values));

    for (final MapEntry(key: route, value: location) in locations.entries) {
      expect(
        GoRouterRouteSource.matchRouteForTesting(location),
        route,
        reason: "$location should match ${route.name}",
      );
    }
  });
}
