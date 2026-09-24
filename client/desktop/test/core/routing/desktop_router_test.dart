import "dart:async";

import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/platform/desktop_route_dispatcher.dart";
import "package:sesori_desktop/core/routing/desktop_router.dart";
import "package:sesori_desktop/core/widgets/desktop_cockpit_shell.dart";
import "package:sesori_desktop/features/auth_gate/auth_gate.dart";
import "package:sesori_desktop/features/home/desktop_home_pane.dart";
import "package:sesori_desktop/features/new_session/desktop_new_session_screen.dart";
import "package:sesori_desktop/features/session_diffs/desktop_session_diffs_screen.dart";
import "package:sesori_desktop/features/sessions/desktop_session_detail_screen.dart";
import "package:sesori_desktop/features/sessions/desktop_session_list_screen.dart";
import "package:sesori_shared/sesori_shared.dart";

void main() {
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
    expect(screen.projectName, "Sesori");
    expect(
      _routeWithPath(AppRouteDef.projects.path).builder!(_FakeBuildContext(), _FakeGoRouterState()),
      isA<DesktopHomePane>(),
    );
  });

  testWidgets("the actual cockpit boundary tracks root popups above retained nested pages", (tester) async {
    final router = GoRouter(
      initialLocation: AppRouteDef.projects.path,
      routes: [
        ShellRoute(
          builder: (context, state, child) => _paneBoundary(context: context, state: state, child: child),
          routes: [
            GoRoute(
              path: AppRouteDef.projects.path,
              builder: (context, _) => Text("visible:${SessionDetailRouteVisibility.isVisibleOf(context: context)}"),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    final element = tester.element(find.text("visible:true"));
    showDialog<void>(
      context: element,
      builder: (_) => const Dialog(child: Text("popup")),
    );
    await tester.pumpAndSettle();
    expect(find.text("visible:false"), findsOneWidget);
    expect(ModalRoute.of(element)?.isCurrent, isTrue);
    final dispatcher = DesktopRouteDispatcher(router: router, routerReady: Future<void>.value());
    dispatcher.dismissPopups();
    await dispatcher.flushPendingForTesting();
    await tester.pumpAndSettle();
    expect(find.text("popup"), findsNothing);
    expect(tester.element(find.text("visible:true")), same(element));
  });

  for (final reducedMotion in [false, true]) {
    testWidgets(
      reducedMotion ? "main-pane pages switch at once under reduced motion" : "main-pane pages cross-fade in 150 ms",
      (tester) async {
        if (reducedMotion) {
          tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
            disableAnimations: true,
          );
          addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        }
        final router = GoRouter(
          initialLocation: "/a",
          routes: [
            ShellRoute(
              builder: (context, state, child) => _paneBoundary(context: context, state: state, child: child),
              routes: [
                GoRoute(path: "/a", builder: (_, _) => const Text("a")),
                GoRoute(path: "/b", builder: (_, _) => const Text("b")),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        unawaited(router.push<void>("/b"));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 75));

        final page = tester.element(find.text("b"));
        expect(ModalRoute.of(page)?.transitionDuration, Duration(milliseconds: reducedMotion ? 0 : 150));
        final fade = tester.widget<FadeTransition>(
          find.ancestor(of: find.text("b"), matching: find.byType(FadeTransition)).first,
        );
        expect(fade.opacity.value, reducedMotion ? 1 : closeTo(0.5, 0.01));
        // Mid-fade the page underneath still shows; reduced motion has already hidden it.
        expect(find.text("a"), reducedMotion ? findsNothing : findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text("a"), findsNothing);
      },
    );
  }

  testWidgets("notification opens dismiss popups while preserving or replacing the canonical stack", (tester) async {
    final router = _callbackRouter(initialRoute: const AppRoute.splash());
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRouteDef.projects.path);
    final dispatcher = DesktopRouteDispatcher(router: router, routerReady: Future<void>.value());
    dispatcher.replaceStack(
      stack: RouteStack(
        paths: [
          const AppRoute.projects(),
          _sessions,
          _detail(readOnly: false),
        ].map((route) => route.buildPath()).toList(),
      ),
    );
    await dispatcher.flushPendingForTesting();
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), _detail(readOnly: false).buildPath());
    final opener = tester.element(find.text("diffs"));
    showDialog<void>(
      context: opener,
      builder: (_) => const Dialog(child: Text("popup")),
    );
    await tester.pumpAndSettle();
    // Same-session reveal, then a no-popup reveal, retain the page and Back stack.
    for (var attempt = 0; attempt < 2; attempt++) {
      dispatcher.dismissPopups();
      await dispatcher.flushPendingForTesting();
      await tester.pumpAndSettle();
      expect(find.text("popup"), findsNothing);
      expect(tester.element(find.text("diffs")), same(opener));
      expect(router.canPop(), isTrue);
    }
    const other = AppRoute.sessionDetail(
      projectId: "p",
      projectName: null,
      sessionId: "other",
      sessionTitle: null,
      readOnly: false,
    );
    showDialog<void>(
      context: opener,
      builder: (_) => const Dialog(child: Text("popup")),
    );
    await tester.pumpAndSettle();
    dispatcher.dismissPopups();
    dispatcher.replaceStack(
      stack: RouteStack(
        paths: [const AppRoute.projects(), _sessions, other].map((route) => route.buildPath()).toList(),
      ),
    );
    await dispatcher.flushPendingForTesting();
    await tester.pumpAndSettle();
    expect(find.text("popup"), findsNothing);
    expect(router.state.uri.toString(), other.buildPath());
    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), _sessions.buildPath());
    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRouteDef.projects.path);
    expect(find.text("home"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("all-sessions opens archived sessions read-only and deletion returns to the list", (tester) async {
    final router = _callbackRouter(initialRoute: _sessions);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text("open archived"));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), _detail(readOnly: true).buildPath());
    await tester.tap(find.text("delete open session"));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), _sessions.buildPath());
  });

  testWidgets("new-session replaces its page and retains the opener", (tester) async {
    final router = _callbackRouter(initialRoute: _sessions);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    // The sidebar's New session row pushes the page over the one it was opened from.
    unawaited(router.push(const AppRoute.newSession(projectId: "p", projectName: "UI / Core").buildPath()));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, const AppRoute.newSession(projectId: "p", projectName: null).buildPath());
    await tester.tap(find.text("created"));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), _detail(readOnly: false).buildPath());
    await _commandBracket(tester);
    expect(router.state.uri.toString(), _sessions.buildPath());
  });

  testWidgets("Cmd/Ctrl+[ returns a pushed child to its parent and does nothing on a direct page", (tester) async {
    final router = _callbackRouter(initialRoute: _detail(readOnly: true));
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text("open child"));
    await tester.pumpAndSettle();
    expect(router.state.pathParameters[sessionIdPathParam], "child");
    await _commandBracket(tester);
    expect(router.state.uri.toString(), _detail(readOnly: true).buildPath());
    await _commandBracket(tester);
    expect(router.state.uri.toString(), _detail(readOnly: true).buildPath());
  });

  for (final route in [const AppRoute.newSession(projectId: "p", projectName: "UI / Core"), _detail(readOnly: false)]) {
    testWidgets("the ${route.def.name} breadcrumb opens its project's sessions", (tester) async {
      final router = _callbackRouter(initialRoute: route);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text("project"));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), _sessions.buildPath());
    });
  }

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

/// The production main-pane boundary, without production DI.
Widget _paneBoundary({required BuildContext context, required GoRouterState state, required Widget child}) {
  final shell = buildDesktopRoutes().single as ShellRoute;
  final gate = shell.builder?.call(context, state, child);
  if (gate is! AuthGate) fail("The desktop shell must start with its AuthGate");
  final shortcuts = (gate.child as Builder).builder(context) as CallbackShortcuts;
  final provider = shortcuts.child as DesktopCockpitCubitProvider;
  return (provider.child as DesktopCockpitShell).child;
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
      ShellRoute(
        builder: (context, state, child) => CallbackShortcuts(
          bindings: _shellShortcuts(context: context, state: state).bindings,
          child: Focus(autofocus: true, child: child),
        ),
        routes: [
          for (final page in shell.routes.whereType<GoRoute>())
            GoRoute(
              path: page.path,
              redirect: page.redirect,
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
                      ],
                      DesktopNewSessionScreen() => [
                        button(
                          label: "created",
                          action: () => screen.onSessionCreated(session: _session),
                        ),
                        button(label: "back", action: screen.onBack),
                        button(label: "project", action: screen.onOpenProject),
                      ],
                      DesktopSessionDetailScreen() => [
                        button(label: "project", action: screen.onOpenProject),
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
      ),
    ],
  );
}

/// The production shell's key bindings, bound to [context].
CallbackShortcuts _shellShortcuts({required BuildContext context, required GoRouterState state}) {
  final shell = buildDesktopRoutes().single as ShellRoute;
  final gate = shell.builder?.call(context, state, const SizedBox());
  if (gate is! AuthGate) fail("The desktop shell must start with its AuthGate");
  return (gate.child as Builder).builder(context) as CallbackShortcuts;
}

Future<void> _commandBracket(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

// ignore_for_file: avoid_implementing_value_types, tests use lightweight framework fakes
