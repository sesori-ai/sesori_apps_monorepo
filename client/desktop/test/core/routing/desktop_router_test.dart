import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/routing/desktop_router.dart";
import "package:sesori_desktop/features/home/desktop_home.dart";
import "package:sesori_desktop/features/home/desktop_home_pane.dart";
import "package:sesori_desktop/features/new_session/desktop_new_session_screen.dart";
import "package:sesori_desktop/features/session_diffs/desktop_session_diffs_screen.dart";
import "package:sesori_desktop/features/sessions/desktop_session_detail_screen.dart";
import "package:sesori_desktop/features/sessions/desktop_session_list_screen.dart";
import "package:sesori_shared/sesori_shared.dart";

void main() {
  test("settings destination matching includes its child routes", () {
    expect(isDesktopSettingsPath(path: AppRouteDef.settings.path), isTrue);
    expect(isDesktopSettingsPath(path: AppRouteDef.settingsDefaultInput.path), isTrue);
    expect(isDesktopSettingsPath(path: AppRouteDef.settingsProfile.path), isTrue);
    expect(isDesktopSettingsPath(path: AppRouteDef.settingsHarnesses.path), isTrue);
    expect(isDesktopSettingsPath(path: AppRouteDef.projects.path), isFalse);
    expect(isDesktopSettingsPath(path: "${AppRouteDef.settings.path}ful"), isFalse);
  });

  test("desktop registers typed new-session and diff routes", () {
    final paths = _routeRegistrations().map((registration) => registration.path);

    expect(paths, containsAll([AppRouteDef.newSession.path, AppRouteDef.sessionDiffs.path]));
  });

  test("new-session route preserves typed project identity", () {
    final route = _routeWithPath(AppRouteDef.newSession.path);
    final widget = route.builder!(
      _FakeBuildContext(),
      _FakeGoRouterState(
        pathParameters: {"projectId": "project-1"},
        queryParameters: {"name": "Sesori"},
      ),
    );

    expect(widget, isA<DesktopNewSessionScreen>());
    final screen = widget as DesktopNewSessionScreen;
    expect(screen.projectId, "project-1");
    expect(screen.projectName, "Sesori");
  });

  test("diff route preserves typed project and session identity", () {
    final route = _routeWithPath(AppRouteDef.sessionDiffs.path);
    final widget = route.builder!(
      _FakeBuildContext(),
      _FakeGoRouterState(
        pathParameters: {"projectId": "project-1", "sessionId": "session-1"},
        queryParameters: {"name": "Sesori"},
      ),
    );

    expect(widget, isA<DesktopSessionDiffsScreen>());
    final screen = widget as DesktopSessionDiffsScreen;
    expect(screen.projectId, "project-1");
    expect(screen.sessionId, "session-1");
    expect(
      screen.key,
      const ValueKey((projectId: "project-1", sessionId: "session-1")),
    );
  });

  test("main-pane routes are siblings and only all-sessions creates a list owner", () {
    final shell = buildDesktopRoutes().single as ShellRoute;
    final pages = shell.routes.whereType<GoRoute>().toList();
    for (final def in [
      AppRouteDef.sessions,
      AppRouteDef.newSession,
      AppRouteDef.sessionDetail,
      AppRouteDef.sessionDiffs,
    ]) {
      final page = pages.singleWhere((page) => page.path == def.path);
      expect(page.routes, isEmpty);
    }
    expect(
      pages.indexWhere((page) => page.path == AppRouteDef.newSession.path),
      lessThan(pages.indexWhere((page) => page.path == AppRouteDef.sessionDetail.path)),
    );
    final state = _FakeGoRouterState(pathParameters: {"projectId": "p"}, queryParameters: {"name": "Sesori"});
    final provider = _routeWithPath(AppRouteDef.sessions.path).builder!(
      _FakeBuildContext(),
      state,
    ) as DesktopSessionListCubitProvider;
    expect(provider.projectId, "p");
    final screen = provider.child as DesktopSessionListScreen;
    final scaffold = screen.build(_FakeBuildContext()) as SessionListScaffold;
    expect(scaffold.onBack, isNull);
    expect(scaffold.projectName, "Sesori");
    expect(scaffold.onNewSession, isNotNull);
    expect(scaffold.onOpenArchived, isNotNull);
    expect(scaffold.connectionBanner, isNull);
    expect(
      _routeWithPath(AppRouteDef.projects.path).builder!(_FakeBuildContext(), _FakeGoRouterState()),
      isA<DesktopHomePane>(),
    );
    expect(
      _routeWithPath(AppRouteDef.splash.path).builder!(_FakeBuildContext(), _FakeGoRouterState()),
      isA<DesktopHome>(),
    );
  });

  testWidgets("all-sessions opens archived sessions read-only and deletion returns to the list", (tester) async {
    final router = _callbackRouter(initialRoute: _sessions);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text("open archived"));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), _detail(readOnly: true).buildPath());
    expect(find.text("back"), findsNothing);
    await tester.tap(find.text("delete open session"));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), _sessions.buildPath());
  });

  testWidgets("new-session replaces its page and retains the opener", (tester) async {
    final router = _callbackRouter(initialRoute: _sessions);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text("new"));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, const AppRoute.newSession(projectId: "p", projectName: null).buildPath());
    await tester.tap(find.text("created"));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), _detail(readOnly: false).buildPath());
    await tester.tap(find.text("back"));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), _sessions.buildPath());
  });

  testWidgets("direct detail hides Back but a pushed child can return to its parent", (tester) async {
    final router = _callbackRouter(initialRoute: _detail(readOnly: true));
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text("back"), findsNothing);
    await tester.tap(find.text("open child"));
    await tester.pumpAndSettle();
    expect(router.state.pathParameters[sessionIdPathParam], "child");
    await tester.tap(find.text("back"));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), _detail(readOnly: true).buildPath());
    expect(find.text("back"), findsNothing);
  });

  testWidgets("diff back preserves the pushed detail including read-only state", (tester) async {
    final router = _callbackRouter(initialRoute: _detail(readOnly: true));
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text("diffs"));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), _diffs.buildPath());
    await tester.tap(find.text("back"));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), _detail(readOnly: true).buildPath());
  });

  for (final route in [const AppRoute.newSession(projectId: "p", projectName: "UI / Core"), _diffs]) {
    testWidgets("direct ${route.def.name} back falls back to all-sessions", (tester) async {
      final router = _callbackRouter(initialRoute: route);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text("back"));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), _sessions.buildPath());
    });
  }

  test("harness-settings route preserves modal presentation", () {
    final route = _routeWithPath(AppRouteDef.settingsHarnesses.path);
    final widget = route.builder!(
      _FakeBuildContext(),
      _FakeGoRouterState(
        queryParameters: {
          harnessSettingsPresentationQueryParam: HarnessSettingsPresentation.modal.name,
        },
      ),
    );

    expect(widget, isA<HarnessesSettingsView>());
    final screen = widget as HarnessesSettingsView;
    expect(screen.presentation, HarnessSettingsPresentation.modal);
  });
}

Iterable<_RouteRegistration> _routeRegistrations({
  List<RouteBase>? routes,
  String parentPath = "",
}) sync* {
  for (final route in routes ?? buildDesktopRoutes()) {
    switch (route) {
      case GoRoute(:final path, :final routes):
        final fullPath = path.startsWith("/") ? path : "${parentPath.endsWith("/") ? parentPath : "$parentPath/"}$path";
        yield _RouteRegistration(path: fullPath, route: route);
        yield* _routeRegistrations(routes: routes, parentPath: fullPath);
      case ShellRoute(:final routes):
        yield* _routeRegistrations(routes: routes, parentPath: parentPath);
      case StatefulShellRoute():
        throw UnsupportedError("Desktop routing does not use StatefulShellRoute");
    }
  }
}

GoRoute _routeWithPath(String path) {
  return _routeRegistrations().singleWhere((registration) => registration.path == path).route;
}

class const _RouteRegistration({required final String path, required final GoRoute route});

class _FakeBuildContext() extends Fake implements BuildContext;

class _FakeGoRouterState({
  @override final Map<String, String> pathParameters = const {},
  Map<String, String> queryParameters = const {},
}) extends Fake implements GoRouterState {
  @override
  final Uri uri = Uri(path: "/", queryParameters: queryParameters.isEmpty ? null : queryParameters);
}

const _sessions = AppRoute.sessions(projectId: "p", projectName: "UI / Core");
const _diffs = AppRoute.sessionDiffs(projectId: "p", projectName: "UI / Core", sessionId: "s");
AppRoute _detail({required bool readOnly}) => AppRoute.sessionDetail(
  projectId: "p",
  projectName: "UI / Core",
  sessionId: "s",
  sessionTitle: "A session",
  readOnly: readOnly,
);
const _session = Session(
  id: "s",
  title: "A session",
  projectID: "p",
  pluginId: "fixture",
  directory: "/fixture",
  parentID: null,
  branchName: null,
  pullRequest: null,
  promptDefaults: null,
  lastUserActivityAt: null,
  time: SessionTime(created: 1, updated: 2, archived: 3),
);

/// Exercise production route decoders/callbacks without constructing auth,
/// transport, or backend-owning screen providers. Content is tested separately.
GoRouter _callbackRouter({required AppRoute initialRoute}) {
  final shell = buildDesktopRoutes().single as ShellRoute;
  return GoRouter(
    initialLocation: initialRoute.buildPath(),
    routes: [
      for (final page in shell.routes.whereType<GoRoute>())
        GoRoute(
          path: page.path,
          builder: (context, state) {
            final screen = page.builder!(context, state);
            Widget button({required String label, required VoidCallback action}) =>
                TextButton(onPressed: action, child: Text(label));
            return Scaffold(
              body: Column(
                children: switch (screen) {
                  DesktopSessionListCubitProvider(child: final DesktopSessionListScreen list) => [
                    button(
                      label: "open archived",
                      action: () => list.onSessionTap(session: _session),
                    ),
                    button(label: "new", action: list.onNewSession),
                  ],
                  DesktopNewSessionScreen() => [
                    button(
                      label: "created",
                      action: () => screen.onSessionCreated(session: _session),
                    ),
                    button(label: "back", action: screen.onBack),
                  ],
                  DesktopSessionDetailScreen() => [
                    if (screen.onBack case final onBack?) button(label: "back", action: onBack),
                    button(
                      label: "open child",
                      action: () => screen.onOpenSession(
                        projectId: "p",
                        sessionId: "child",
                        sessionTitle: "Child",
                        readOnly: true,
                      ),
                    ),
                    button(label: "diffs", action: screen.onShowDiffs),
                    button(
                      label: "delete open session",
                      action: () {
                        final provider = _routeWithPath(AppRouteDef.sessions.path).builder!(
                          context,
                          state,
                        ) as DesktopSessionListCubitProvider;
                        final list = provider.child as DesktopSessionListScreen;
                        list.actionDispatcher.onSessionDeleted!(context: context, sessionId: screen.sessionId);
                      },
                    ),
                  ],
                  DesktopSessionDiffsScreen() => [button(label: "back", action: screen.onBack)],
                  _ => [const Text("home")],
                },
              ),
            );
          },
        ),
    ],
  );
}

// ignore_for_file: avoid_implementing_value_types, tests use lightweight framework fakes
