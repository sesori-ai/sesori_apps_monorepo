import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "package:sesori_mobile/core/platform/go_router_route_dispatcher.dart";
import "package:sesori_mobile/core/routing/app_router.dart";
import "package:sesori_mobile/core/widgets/session_split/session_split_route_child.dart";
import "package:sesori_mobile/core/widgets/session_split/session_split_scope.dart";
import "package:sesori_mobile/core/widgets/session_split/session_split_shell.dart";
import "package:sesori_mobile/features/login/login_screen.dart";
import "package:sesori_mobile/features/new_session/new_session_screen.dart";
import "package:sesori_mobile/features/project_list/project_list_screen.dart";
import "package:sesori_mobile/features/session_detail/session_detail_screen.dart";
import "package:sesori_mobile/features/session_diffs/session_diffs_screen.dart";
import "package:sesori_mobile/features/session_list/session_list_screen.dart";
import "package:sesori_mobile/features/settings/settings_screen.dart";
import "package:sesori_mobile/features/splash/splash_screen.dart";

void main() {
  group("AppRoute", () {
    test("each value has a non-empty path starting with /", () {
      for (final def in AppRouteDef.values) {
        expect(def.path, isNotEmpty, reason: "${def.name} should have a path");
        expect(def.path.startsWith("/"), isTrue, reason: "${def.name} path should start with /");
      }
    });
  });

  group("AppRoute.buildPath", () {
    test("returns raw path for parameterless routes", () {
      expect(const AppRoute.splash().buildPath(), "/splash");
      expect(const AppRoute.login().buildPath(), "/login");
      expect(const AppRoute.projects().buildPath(), "/projects");
      expect(const AppRoute.settings().buildPath(), "/settings");
    });

    test("substitutes projectId for sessions", () {
      final result = const AppRoute.sessions(projectId: "proj-123", projectName: null).buildPath();
      expect(result, "/projects/proj-123/sessions");
    });

    test("substitutes path params for sessionDetail", () {
      final result = const AppRoute.sessionDetail(
        projectId: "proj-123",
        sessionId: "ses-456",
        sessionTitle: null,
        readOnly: false,
      ).buildPath();
      expect(result, "/projects/proj-123/sessions/ses-456?readOnly=false");
    });

    test("includes projectName as query param for sessions", () {
      final result = const AppRoute.sessions(projectId: "proj-123", projectName: "My Project").buildPath();
      expect(result, contains("/projects/proj-123/sessions?"));
      expect(result, contains("name=My+Project"));
    });

    test("omits query string when no query params set", () {
      final result = const AppRoute.sessions(projectId: "proj-123", projectName: null).buildPath();
      expect(result, "/projects/proj-123/sessions");
      expect(result, isNot(contains("?")));
    });

    test("includes title and readOnly as query params for sessionDetail", () {
      final result = const AppRoute.sessionDetail(
        projectId: "proj-1",
        sessionId: "ses-1",
        sessionTitle: "hello world & more",
        readOnly: true,
      ).buildPath();
      expect(result, contains("/projects/proj-1/sessions/ses-1?"));
      expect(result, isNot(contains("& more")));
      expect(result, contains("readOnly=true"));
    });

    test("always includes readOnly in query when false", () {
      final result = const AppRoute.sessionDetail(
        projectId: "proj-1",
        sessionId: "ses-1",
        sessionTitle: null,
        readOnly: false,
      ).buildPath();
      expect(result, "/projects/proj-1/sessions/ses-1?readOnly=false");
    });

    test("encodes path params with special characters", () {
      final result = const AppRoute.sessionDetail(
        projectId: "project/with?special&chars",
        sessionId: "id/with?special&chars",
        sessionTitle: null,
        readOnly: false,
      ).buildPath();
      expect(
        result,
        "/projects/project%2Fwith%3Fspecial%26chars/sessions/id%2Fwith%3Fspecial%26chars?readOnly=false",
      );
    });

    test("substitutes projectId for newSession", () {
      final result = const AppRoute.newSession(projectId: "proj-42").buildPath();
      expect(result, "/projects/proj-42/sessions/new");
    });
  });

  group("flat route builders", () {
    test("splash route builds SplashScreen", () {
      final widget = AppRouteDef.splash.toGoRoute().builder!(_FakeBuildContext(), _FakeGoRouterState());
      expect(widget, isA<SplashScreen>());
    });

    test("login route builds LoginScreen", () {
      final widget = AppRouteDef.login.toGoRoute().builder!(_FakeBuildContext(), _FakeGoRouterState());
      expect(widget, isA<LoginScreen>());
    });

    test("projects route builds ProjectListScreen", () {
      final widget = AppRouteDef.projects.toGoRoute().builder!(_FakeBuildContext(), _FakeGoRouterState());
      expect(widget, isA<ProjectListScreen>());
    });

    test("settings route builds SettingsScreen", () {
      final widget = AppRouteDef.settings.toGoRoute().builder!(_FakeBuildContext(), _FakeGoRouterState());
      expect(widget, isA<SettingsScreen>());
    });

    test("newSession route builds NewSessionScreen", () {
      final widget = AppRouteDef.newSession.toGoRoute().builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(pathParameters: {"projectId": "proj-42"}),
      );
      expect(widget, isA<NewSessionScreen>());
      expect((widget as NewSessionScreen).projectId, "proj-42");
    });
  });

  group("buildAppRoutes", () {
    test("explicit route table covers every AppRouteDef exactly once", () {
      final routes = buildAppRoutes();
      final flatPaths = routes.whereType<GoRoute>().map((route) => route.path);
      final shellPaths = routes
          .whereType<ShellRoute>()
          .single
          .routes
          .whereType<GoRoute>()
          .map((route) => route.path);
      final registeredPaths = [...flatPaths, ...shellPaths].toList();

      expect(registeredPaths, hasLength(AppRouteDef.values.length));
      expect(
        registeredPaths.toSet(),
        equals(AppRouteDef.values.map((def) => def.path).toSet()),
      );
    });

    test("keeps non-session routes flat and session routes shell-wrapped", () {
      final flatPaths = buildAppRoutes().whereType<GoRoute>().map((route) => route.path).toList();

      expect(
        flatPaths,
        equals([
          AppRouteDef.splash.path,
          AppRouteDef.login.path,
          AppRouteDef.projects.path,
          AppRouteDef.settings.path,
          AppRouteDef.newSession.path,
        ]),
      );
      expect(flatPaths, isNot(contains(AppRouteDef.sessions.path)));
      expect(flatPaths, isNot(contains(AppRouteDef.sessionDetail.path)));
      expect(flatPaths, isNot(contains(AppRouteDef.sessionDiffs.path)));
    });

    test("registers newSession before the session-family shell", () {
      final routes = buildAppRoutes();
      final newSessionIndex = routes.indexWhere(
        (route) => route is GoRoute && route.path == AppRouteDef.newSession.path,
      );
      final shellIndex = routes.indexWhere((route) => route is ShellRoute);

      expect(newSessionIndex, isNonNegative);
      expect(shellIndex, isNonNegative);
      expect(newSessionIndex, lessThan(shellIndex));
    });

    test("wraps only sessions, detail, and diffs in a ShellRoute", () {
      final shell = buildAppRoutes().whereType<ShellRoute>().single;
      final shellPaths = shell.routes.whereType<GoRoute>().map((route) => route.path).toList();

      expect(
        shellPaths,
        equals([
          AppRouteDef.sessions.path,
          AppRouteDef.sessionDetail.path,
          AppRouteDef.sessionDiffs.path,
        ]),
      );
    });

    test("sessions child preserves typed route decoding", () {
      final widget = _sessionShellChildRoute(AppRouteDef.sessions).builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(
          pathParameters: {"projectId": "proj-42"},
          queryParameters: {"name": "My Project"},
        ),
      );

      expect(widget, isA<SessionSplitRouteChild>());
      final routeChild = widget as SessionSplitRouteChild;
      expect(routeChild.routeKind, SessionSplitRouteKind.list);
      expect(routeChild.route, isA<AppRouteSessions>());
      expect((routeChild.route as AppRouteSessions).projectName, "My Project");
      expect(routeChild.child, isA<SessionListScreen>());
      expect((routeChild.child as SessionListScreen).projectName, "My Project");
    });

    test("detail child preserves typed route decoding", () {
      final widget = _sessionShellChildRoute(AppRouteDef.sessionDetail).builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(
          pathParameters: {"projectId": "proj-42", "sessionId": "ses-99"},
          queryParameters: {"title": "Debug session", "readOnly": "true"},
        ),
      );

      expect(widget, isA<SessionSplitRouteChild>());
      final routeChild = widget as SessionSplitRouteChild;
      expect(routeChild.routeKind, SessionSplitRouteKind.detail);
      expect(routeChild.route, isA<AppRouteSessionDetail>());
      final route = routeChild.route as AppRouteSessionDetail;
      expect(route.projectId, "proj-42");
      expect(route.sessionId, "ses-99");
      expect(route.sessionTitle, "Debug session");
      expect(route.readOnly, isTrue);
      expect(routeChild.child, isA<Builder>());
    });

    testWidgets("detail child builder provides split-aware diffs callback and stable key", (tester) async {
      final widget = _sessionShellChildRoute(AppRouteDef.sessionDetail).builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(
          pathParameters: {"projectId": "proj-42", "sessionId": "ses-99"},
          queryParameters: {"title": "Debug session", "readOnly": "false"},
        ),
      );
      final routeChild = widget as SessionSplitRouteChild;

      SessionDetailScreen? capturedScreen;
      await tester.pumpWidget(
        SessionSplitScope(
          isSplit: true,
          projectId: "proj-42",
          selectedSessionId: "ses-99",
          child: Builder(
            builder: (context) {
              capturedScreen = (routeChild.child as Builder).builder(context) as SessionDetailScreen;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedScreen, isNotNull);
      expect(capturedScreen!.key, const ValueKey("session-detail-ses-99"));
      expect(capturedScreen!.onOpenDiffs, isNotNull);
    });

    testWidgets("detail child builder omits split callback outside split scope", (tester) async {
      final widget = _sessionShellChildRoute(AppRouteDef.sessionDetail).builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(
          pathParameters: {"projectId": "proj-42", "sessionId": "ses-99"},
          queryParameters: {"title": "Debug session", "readOnly": "false"},
        ),
      );
      final routeChild = widget as SessionSplitRouteChild;

      SessionDetailScreen? capturedScreen;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedScreen = (routeChild.child as Builder).builder(context) as SessionDetailScreen;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedScreen, isNotNull);
      expect(capturedScreen!.onOpenDiffs, isNull);
    });

    test("diffs child preserves typed route decoding and stable key", () {
      final widget = _sessionShellChildRoute(AppRouteDef.sessionDiffs).builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(pathParameters: {"projectId": "proj-42", "sessionId": "ses-99"}),
      );

      expect(widget, isA<SessionSplitRouteChild>());
      final routeChild = widget as SessionSplitRouteChild;
      expect(routeChild.routeKind, SessionSplitRouteKind.diffs);
      expect(routeChild.route, isA<AppRouteSessionDiffs>());
      final route = routeChild.route as AppRouteSessionDiffs;
      expect(route.projectId, "proj-42");
      expect(route.sessionId, "ses-99");
      expect(routeChild.child, isA<SessionDiffsScreen>());
      expect((routeChild.child as SessionDiffsScreen).key, const ValueKey("session-diffs-ses-99"));
    });

    testWidgets("shell builder accepts typed route child", (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final shell = buildAppRoutes().whereType<ShellRoute>().single;
      final widget = shell.builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(),
        const SessionSplitRouteChild(
          routeKind: SessionSplitRouteKind.detail,
          route: AppRoute.sessionDetail(
            projectId: "proj-42",
            sessionId: "ses-99",
            sessionTitle: null,
            readOnly: false,
          ),
          child: Text("Detail"),
        ),
      );

      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: widget));

      expect(find.byType(SessionSplitShell), findsOneWidget);
    });
  });

  group("GoRouterRouteDispatcher", () {
    test("replaceStack rebuilds the stack from root then pushes remaining routes", () async {
      final goCalls = <String>[];
      final pushCalls = <String>[];
      final dispatcher = GoRouterRouteDispatcher.test(
        goRoute: goCalls.add,
        pushRoute: (route) async {
          pushCalls.add(route);
        },
      );

      dispatcher.replaceStack(
        stack: RouteStack(
          paths: [
            const AppRoute.projects().buildPath(),
            const AppRoute.sessions(projectId: "proj_1", projectName: null).buildPath(),
            const AppRoute.sessionDetail(
              projectId: "proj_1",
              sessionId: "ses_1",
              sessionTitle: "Session Title",
              readOnly: false,
            ).buildPath(),
          ],
        ),
      );
      await dispatcher.flushPendingForTesting();

      expect(goCalls, equals([const AppRoute.projects().buildPath()]));
      expect(
        pushCalls,
        equals([
          const AppRoute.sessions(projectId: "proj_1", projectName: null).buildPath(),
          const AppRoute.sessionDetail(
            projectId: "proj_1",
            sessionId: "ses_1",
            sessionTitle: "Session Title",
            readOnly: false,
          ).buildPath(),
        ]),
      );
    });

    test("replaceStack ignores empty route stacks", () async {
      final goCalls = <String>[];
      final pushCalls = <String>[];
      final dispatcher = GoRouterRouteDispatcher.test(
        goRoute: goCalls.add,
        pushRoute: (route) async {
          pushCalls.add(route);
        },
      );

      dispatcher.replaceStack(stack: RouteStack(paths: const []));
      await dispatcher.flushPendingForTesting();

      expect(goCalls, isEmpty);
      expect(pushCalls, isEmpty);
    });
  });
}

class _FakeBuildContext extends Fake implements BuildContext {}

// ignore: avoid_implementing_value_types, GoRouterState is a value type but tests only need a lightweight fake
class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState({
    this.pathParameters = const {},
    Map<String, String> queryParameters = const {},
  }) : uri = Uri(path: "/", queryParameters: queryParameters.isEmpty ? null : queryParameters);

  @override
  final Map<String, String> pathParameters;

  @override
  final Uri uri;
}

GoRoute _sessionShellChildRoute(AppRouteDef def) {
  final shell = buildAppRoutes().whereType<ShellRoute>().single;
  return shell.routes.whereType<GoRoute>().singleWhere((route) => route.path == def.path);
}
