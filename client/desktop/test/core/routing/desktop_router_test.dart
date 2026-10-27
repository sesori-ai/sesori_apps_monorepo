import "dart:async";

import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/platform/desktop_route_dispatcher.dart";
import "package:sesori_desktop/core/routing/desktop_router.dart";
import "package:sesori_desktop/core/widgets/desktop_cockpit_shell.dart";
import "package:sesori_desktop/core/widgets/desktop_command_palette.dart";
import "package:sesori_desktop/features/auth_gate/auth_gate.dart";
import "package:sesori_desktop/features/home/desktop_home_pane.dart";
import "package:sesori_desktop/features/new_session/desktop_new_session_screen.dart";
import "package:sesori_desktop/features/session_diffs/desktop_session_diffs_screen.dart";
import "package:sesori_desktop/features/sessions/desktop_session_detail_screen.dart";
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
        queryParameters: {"project": "project-1", "name": "Sesori"},
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
      ),
    );

    expect(widget, isA<DesktopSessionDiffsScreen>());
    final screen = widget as DesktopSessionDiffsScreen;
    expect(screen.sessionId, "session-1");
    expect(
      screen.key,
      const ValueKey((projectId: "project-1", sessionId: "session-1")),
    );
  });

  test("main-pane routes are siblings and the home is the composer pane", () {
    final shell = buildDesktopRoutes().single as ShellRoute;
    final pages = shell.routes.whereType<GoRoute>().toList();
    for (final def in [
      AppRouteDef.archivedSessions,
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
    expect(
      _routeWithPath(AppRouteDef.home.path).builder!(_FakeBuildContext(), _FakeGoRouterState()),
      isA<DesktopHomePane>(),
    );
  });

  testWidgets("the actual cockpit boundary tracks root popups above retained nested pages", (tester) async {
    final router = GoRouter(
      initialLocation: AppRouteDef.home.path,
      routes: [
        ShellRoute(
          builder: (context, state, child) => _paneBoundary(context: context, state: state, child: child),
          routes: [
            GoRoute(
              path: AppRouteDef.home.path,
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
    expect(router.state.uri.path, AppRouteDef.home.path);
    final dispatcher = DesktopRouteDispatcher(router: router, routerReady: Future<void>.value());
    dispatcher.replaceStack(
      stack: RouteStack(
        paths: [
          const AppRoute.home(),
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
      fromLaunch: false,
    );
    showDialog<void>(
      context: opener,
      builder: (_) => const Dialog(child: Text("popup")),
    );
    await tester.pumpAndSettle();
    dispatcher.dismissPopups();
    dispatcher.replaceStack(
      stack: RouteStack(
        paths: [const AppRoute.home(), other].map((route) => route.buildPath()).toList(),
      ),
    );
    await dispatcher.flushPendingForTesting();
    await tester.pumpAndSettle();
    expect(find.text("popup"), findsNothing);
    expect(router.state.uri.toString(), other.buildPath());
    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRouteDef.home.path);
    expect(find.text("home"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final exit in ["delete open session", "archive open session", "mark unread"]) {
    testWidgets("$exit leaves the session page for the home", (tester) async {
      final router = _callbackRouter(initialRoute: _detail(readOnly: false));
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text(exit));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRouteDef.home.path);
    });
  }

  testWidgets("the sidebar's Archived opens over its opener, opens rows read-only and closes back", (tester) async {
    final router = _callbackRouter(initialRoute: _detail(readOnly: false));
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router: router));
    await tester.tap(find.text("sidebar archived"));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRouteDef.archivedSessions.path);
    // Archived again from the sidebar keeps the one page.
    await tester.tap(find.text("sidebar archived"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("open archived row"));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), _detail(readOnly: true).buildPath());
    await _commandBracket(tester);
    expect(router.state.uri.path, AppRouteDef.archivedSessions.path);
    await tester.tap(find.text("close archived"));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), _detail(readOnly: false).buildPath());
  });

  testWidgets("Archived reached directly closes to the home", (tester) async {
    final router = _callbackRouter(initialRoute: const AppRoute.archivedSessions());
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router: router));
    await tester.tap(find.text("close archived"));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRouteDef.home.path);
  });

  testWidgets("new-session replaces its page and retains the opener", (tester) async {
    final router = _callbackRouter(initialRoute: _detail(readOnly: true));
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    // The sidebar's New session row pushes the page over the one it was opened from.
    unawaited(
      router.push(
        const AppRoute.newSession(
          projectId: "p",
          projectName: "UI / Core",
          entry: NewSessionEntry.platform(),
        ).buildPath(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      router.state.uri.toString(),
      const AppRoute.newSession(
        projectId: "p",
        projectName: "UI / Core",
        entry: NewSessionEntry.platform(),
      ).buildPath(),
    );
    await tester.tap(find.text("created"));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), _detail(readOnly: false).buildPath());
    await _commandBracket(tester);
    expect(router.state.uri.toString(), _detail(readOnly: true).buildPath());
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

  testWidgets("Cmd/Ctrl+[ closes what a page has open before it leaves the page", (tester) async {
    final router = _callbackRouter(initialRoute: _detail(readOnly: true));
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text("open overlay"));
    await tester.pumpAndSettle();
    await _commandBracket(tester);
    expect(find.text("overlay open"), findsNothing, reason: "a direct page closes its screen");

    await tester.tap(find.text("open child"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("open overlay").last);
    await tester.pumpAndSettle();
    await _commandBracket(tester);
    expect(router.state.pathParameters[sessionIdPathParam], "child");
    expect(find.text("overlay open"), findsNothing);
    await _commandBracket(tester);
    expect(router.state.uri.toString(), _detail(readOnly: true).buildPath());
  });

  testWidgets("Main session pops to the parent under it and otherwise opens the parent", (tester) async {
    final router = _callbackRouter(initialRoute: _detail(readOnly: false));
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text("open child"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("main session"));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), _detail(readOnly: false).buildPath());
    expect(router.canPop(), isFalse);

    // A child stacked over the home (a notification's stack) opens its parent instead.
    router.go(const AppRoute.home().buildPath());
    await tester.pumpAndSettle();
    unawaited(
      router.push<void>(
        const AppRoute.sessionDetail(
          projectId: "p",
          projectName: "UI / Core",
          sessionId: "child",
          sessionTitle: "Child",
          readOnly: true,
          fromLaunch: false,
        ).buildPath(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("main session"));
    await tester.pumpAndSettle();
    expect(router.state.pathParameters[sessionIdPathParam], "s");
  });

  testWidgets("direct newSession back falls back to the home", (tester) async {
    final router = _callbackRouter(
      initialRoute: const AppRoute.newSession(
        projectId: "p",
        projectName: "UI / Core",
        entry: NewSessionEntry.platform(),
      ),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text("back"));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRouteDef.home.path);
  });

  testWidgets("a new session without a project goes home", (tester) async {
    final router = _callbackRouter(
      initialRoute: const AppRoute.newSession(projectId: null, projectName: null, entry: NewSessionEntry.platform()),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), const AppRoute.home().buildPath());
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

/// The production main-pane boundary, without production DI.
Widget _paneBoundary({required BuildContext context, required GoRouterState state, required Widget child}) {
  final shell = buildDesktopRoutes().single as ShellRoute;
  final gate = shell.builder?.call(context, state, child);
  if (gate is! AuthGate) fail("The desktop shell must start with its AuthGate");
  final provider = gate.child as DesktopCockpitCubitProvider;
  return ((provider.child as Builder).builder(context) as DesktopCockpitShell).child;
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

AppRoute _detail({required bool readOnly}) => AppRoute.sessionDetail(
  projectId: "p",
  projectName: "UI / Core",
  sessionId: "s",
  sessionTitle: "A session",
  readOnly: readOnly,
  fromLaunch: false,
);
const _session = Session(
  approvalOverride: null,
  autoContinuation: null,
  id: "s",
  title: "A session",
  projectID: "p",
  pluginId: "fixture",
  directory: "/fixture",
  parentID: null,
  branchName: null,
  promptDefaults: null,
  lastUserActivityAt: null,
  time: SessionTime(created: 1, updated: 2, archived: 3),
);

Widget _app({required GoRouter router}) => MaterialApp.router(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routerConfig: router,
);

/// Exercise production route decoders/callbacks without constructing auth,
/// transport, or backend-owning screen providers. Content is tested separately.
GoRouter _callbackRouter({required AppRoute initialRoute}) {
  final shell = buildDesktopRoutes().single as ShellRoute;
  return GoRouter(
    initialLocation: initialRoute.buildPath(),
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          final cockpit = _cockpit(context: context, state: state);
          return CallbackShortcuts(
            bindings: {desktopShortcut(key: LogicalKeyboardKey.bracketLeft): cockpit.onGoBack},
            child: Focus(
              autofocus: true,
              child: Column(
                children: [
                  // As the sidebar's Archived row opens it.
                  TextButton(onPressed: cockpit.onOpenArchived, child: const Text("sidebar archived")),
                  Expanded(child: child),
                ],
              ),
            ),
          );
        },
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
                      DesktopNewSessionScreen() => [
                        button(
                          label: "created",
                          action: () => screen.onSessionCreated(session: _session),
                        ),
                        button(label: "back", action: screen.onBack),
                      ],
                      DesktopSessionDetailScreen() => [
                        const _OverlayOnPage(),
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
                          label: "main session",
                          action: () => screen.onOpenParentSession(parentSessionId: "s"),
                        ),
                        button(
                          label: "delete open session",
                          action: () =>
                              screen.sessionActions.onSessionDeleted!(context: context, sessionId: screen.sessionId),
                        ),
                        button(
                          label: "archive open session",
                          action: () =>
                              screen.sessionActions.onSessionArchived!(context: context, sessionId: screen.sessionId),
                        ),
                        button(label: "mark unread", action: screen.onMarkedUnread),
                      ],
                      BlocProvider(child: final ArchivedSessionsView archived) => [
                        button(
                          label: "open archived row",
                          action: () => archived.onSessionTap(
                            row: const AllSessionsRow(
                              session: _session,
                              project: ProjectSummary(id: "p", name: "UI / Core", path: "/fixture", time: null),
                              isRunning: false,
                              isUnseen: false,
                              isAwaitingInput: false,
                              isRetrying: false,
                              backgroundTaskCount: 0,
                            ),
                          ),
                        ),
                        button(label: "close archived", action: archived.onExit),
                      ],
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

/// The production cockpit's callbacks, bound to [context].
DesktopCockpitShell _cockpit({required BuildContext context, required GoRouterState state}) {
  final shell = buildDesktopRoutes().single as ShellRoute;
  final gate = shell.builder?.call(context, state, const SizedBox());
  if (gate is! AuthGate) fail("The desktop shell must start with its AuthGate");
  final provider = gate.child as DesktopCockpitCubitProvider;
  return (provider.child as Builder).builder(context) as DesktopCockpitShell;
}

/// A screen a page opens over itself, as the session page opens Prompts:
/// while it is open, the page closes it instead of being popped.
class const _OverlayOnPage() extends StatefulWidget {
  @override
  State<_OverlayOnPage> createState() => _OverlayOnPageState();
}

class _OverlayOnPageState() extends State<_OverlayOnPage> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_open,
    onPopInvokedWithResult: (didPop, _) => didPop ? null : setState(() => _open = false),
    child: _open
        ? const Text("overlay open")
        : TextButton(onPressed: () => setState(() => _open = true), child: const Text("open overlay")),
  );
}

Future<void> _commandBracket(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

// ignore_for_file: avoid_implementing_value_types, tests use lightweight framework fakes
