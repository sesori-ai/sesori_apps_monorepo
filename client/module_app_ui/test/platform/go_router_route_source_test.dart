import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Mirrors the production route tree's shape — the session routes nested under
/// a [ShellRoute] — with placeholder screens, so navigation needs no DI.
GoRouter _router() {
  return GoRouter(
    initialLocation: AppRouteDef.splash.path,
    routes: [
      GoRoute(path: AppRouteDef.splash.path, builder: (_, _) => const Text("splash")),
      ShellRoute(
        builder: (_, _, child) => child,
        routes: [
          GoRoute(
            path: AppRouteDef.home.path,
            builder: (_, _) => const Text("home"),
            routes: [
              GoRoute(path: "new", builder: (_, _) => const Text("new session")),
              GoRoute(
                path: ":$projectIdPathParam/:$sessionIdPathParam",
                builder: (_, _) => const Text("session detail"),
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
    routeSource = GoRouterRouteSource(router: router);
  });

  tearDown(() async {
    await routeSource.dispose();
    router.dispose();
  });

  Future<void> pumpRouter(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets("reports declaratively navigated screens", (tester) async {
    await pumpRouter(tester);

    router.go(const AppRoute.home().buildPath());
    await tester.pumpAndSettle();

    expect(routeSource.currentRouteStream.value, AppRouteDef.home);
  });

  testWidgets("replays home visibility and follows topmost navigation", (tester) async {
    await pumpRouter(tester);
    final initialVisibility = <bool>[];
    final initialSubscription = routeSource.homeVisibility.listen(initialVisibility.add);
    addTearDown(initialSubscription.cancel);
    await tester.pump();
    expect(initialVisibility, [false]);

    router.go(const AppRoute.home().buildPath());
    await tester.pumpAndSettle();
    final lateVisibility = <bool>[];
    final lateSubscription = routeSource.homeVisibility.listen(lateVisibility.add);
    addTearDown(lateSubscription.cancel);
    await tester.pump();
    expect(lateVisibility, [true]);

    unawaited(router.push<void>(const AppRoute.settings().buildPath()));
    await tester.pumpAndSettle();
    router.pop<void>();
    await tester.pumpAndSettle();

    unawaited(router.push<void>(const AppRoute.newSession(projectId: null, projectName: null).buildPath()));
    await tester.pumpAndSettle();
    router.pop<void>();
    await tester.pumpAndSettle();

    expect(lateVisibility, [true, false, true, false, true]);
    expect(initialVisibility, [false, true, false, true, false, true]);
  });

  testWidgets("reports imperatively pushed screens", (tester) async {
    await pumpRouter(tester);
    router.go(const AppRoute.home().buildPath());
    await tester.pumpAndSettle();

    // A push leaves RouteMatchList.uri on /sessions, so only walking the match
    // tree reveals settings as the screen the user is actually on.
    unawaited(router.push<void>(const AppRoute.settings().buildPath()));
    await tester.pumpAndSettle();

    expect(routeSource.currentRouteStream.value, AppRouteDef.settings);
  });

  testWidgets("currentLocation keeps the query of a pushed route", (tester) async {
    await pumpRouter(tester);
    router.go(const AppRoute.home().buildPath());
    await tester.pumpAndSettle();

    unawaited(
      router.push<void>(
        const AppRoute.sessionDetail(
          projectId: "p1",
          projectName: null,
          sessionId: "s1",
          sessionTitle: null,
          readOnly: true,
          fromLaunch: false,
        ).buildPath(),
      ),
    );
    await tester.pumpAndSettle();

    // `readOnly` lives in the query and is the only thing separating the
    // read-only session screen from the editable one, so a location that drops
    // the query cannot tell them apart.
    final location = Uri.parse(routeSource.currentLocation!);
    expect(location.path, "/sessions/p1/s1");
    expect(location.queryParameters["readOnly"], "true");
  });

  testWidgets("reports pushed screens nested in the session shell", (tester) async {
    await pumpRouter(tester);
    router.go(const AppRoute.home().buildPath());
    await tester.pumpAndSettle();

    unawaited(router.push<void>(const AppRoute.newSession(projectId: "p1", projectName: null).buildPath()));
    await tester.pumpAndSettle();
    expect(routeSource.currentRouteStream.value, AppRouteDef.newSession);

    unawaited(
      router.push<void>(
        const AppRoute.sessionDetail(
          projectId: "p1",
          projectName: null,
          sessionId: "s1",
          sessionTitle: null,
          readOnly: false,
          fromLaunch: false,
        ).buildPath(),
      ),
    );
    await tester.pumpAndSettle();

    expect(routeSource.currentRouteStream.value, AppRouteDef.sessionDetail);
  });

  testWidgets("reports the revealed screen after popping a pushed screen", (tester) async {
    await pumpRouter(tester);
    router.go(const AppRoute.home().buildPath());
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
      AppRouteDef.home: "/sessions",
      AppRouteDef.settings: "/settings",
      AppRouteDef.settingsDefaultInput: "/settings/default-input",
      AppRouteDef.settingsNotifications: "/settings/notifications",
      AppRouteDef.settingsHarnesses: "/settings/harnesses",
      AppRouteDef.settingsHarnessDetail: "/settings/harnesses/codex",
      AppRouteDef.settingsProfile: "/settings/profile",
      AppRouteDef.settingsComputers: "/settings/computers",
      AppRouteDef.settingsProjects: "/settings/projects",
      AppRouteDef.archivedSessions: "/archived-sessions",
      AppRouteDef.archivedSessionDetail: "/archived-sessions/p1/s1",
      AppRouteDef.newSession: "/sessions/new",
      AppRouteDef.sessionDetail: "/sessions/p1/s1",
      AppRouteDef.sessionDiffs: "/sessions/p1/s1/diffs",
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
