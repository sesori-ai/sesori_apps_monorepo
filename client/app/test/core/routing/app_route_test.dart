import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "package:sesori_mobile/core/platform/go_router_route_dispatcher.dart";
import "package:sesori_mobile/core/routing/app_router.dart";
import "package:sesori_mobile/core/routing/imperative_pane_route.dart";
import "package:sesori_mobile/core/widgets/session_split/session_split_shell.dart";
import "package:sesori_mobile/features/login/login_screen.dart";
import "package:sesori_mobile/features/new_session/new_session_screen.dart";
import "package:sesori_mobile/features/project_list/project_list_screen.dart";
import "package:sesori_mobile/features/session_detail/session_detail_screen.dart";
import "package:sesori_mobile/features/session_diffs/session_diffs_screen.dart";
import "package:sesori_mobile/features/session_list/session_list_cubit_provider.dart";
import "package:sesori_mobile/features/settings/notification_settings_screen.dart";
import "package:sesori_mobile/features/settings/plugin_settings_screen.dart";
import "package:sesori_mobile/features/settings/profile_screen.dart";
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
      expect(const AppRoute.settingsPlugins().buildPath(), "/settings/plugins");
    });

    test("substitutes projectId for sessions", () {
      final result = const AppRoute.sessions(
        projectId: "proj-123",
        projectName: null,
        supportsDedicatedWorktrees: null,
      ).buildPath();
      expect(result, "/projects/proj-123/sessions");
    });

    test("substitutes path params for sessionDetail", () {
      final result = const AppRoute.sessionDetail(
        projectId: "proj-123",
        projectName: null,
        sessionId: "ses-456",
        sessionTitle: null,
        readOnly: false,
      ).buildPath();
      expect(result, "/projects/proj-123/sessions/ses-456?readOnly=false");
    });

    test("includes projectName as query param for sessions", () {
      final result = const AppRoute.sessions(
        projectId: "proj-123",
        projectName: "My Project",
        supportsDedicatedWorktrees: null,
      ).buildPath();
      expect(result, contains("/projects/proj-123/sessions?"));
      expect(result, contains("name=My+Project"));
    });

    test("omits query string when no query params set", () {
      final result = const AppRoute.sessions(
        projectId: "proj-123",
        projectName: null,
        supportsDedicatedWorktrees: null,
      ).buildPath();
      expect(result, "/projects/proj-123/sessions");
      expect(result, isNot(contains("?")));
    });

    test("includes title and readOnly as query params for sessionDetail", () {
      final result = const AppRoute.sessionDetail(
        projectId: "proj-1",
        projectName: "Project One",
        sessionId: "ses-1",
        sessionTitle: "hello world & more",
        readOnly: true,
      ).buildPath();
      expect(result, contains("/projects/proj-1/sessions/ses-1?"));
      expect(result, isNot(contains("& more")));
      expect(result, contains("name=Project+One"));
      expect(result, contains("readOnly=true"));
    });

    test("always includes readOnly in query when false", () {
      final result = const AppRoute.sessionDetail(
        projectId: "proj-1",
        projectName: null,
        sessionId: "ses-1",
        sessionTitle: null,
        readOnly: false,
      ).buildPath();
      expect(result, "/projects/proj-1/sessions/ses-1?readOnly=false");
    });

    test("encodes path params with special characters", () {
      final result = const AppRoute.sessionDetail(
        projectId: "project/with?special&chars",
        projectName: null,
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
      final result = const AppRoute.newSession(projectId: "proj-42", projectName: null).buildPath();
      expect(result, "/projects/proj-42/sessions/new");
    });

    test("includes projectName as query param for newSession", () {
      final result = const AppRoute.newSession(projectId: "proj-42", projectName: "Project One").buildPath();
      expect(result, "/projects/proj-42/sessions/new?name=Project+One");
    });
  });

  group("flat route builders", () {
    test("splash route builds SplashScreen", () {
      final widget = AppRouteDef.splash.toGoRoute().builder!(_FakeBuildContext(), _FakeGoRouterState());
      expect(widget, isA<SplashScreen>());
    });

    test("login route builds LoginScreen behind a fade transition page", () {
      final goRoute = AppRouteDef.login.toGoRoute();
      final page = goRoute.pageBuilder!(
        _FakeBuildContext(),
        _FakeGoRouterState(),
      );
      expect(page, isA<CustomTransitionPage<void>>());
      expect((page as CustomTransitionPage<void>).child, isA<LoginScreen>());
    });

    test("projects route builds ProjectListScreen", () {
      final widget = AppRouteDef.projects.toGoRoute().builder!(_FakeBuildContext(), _FakeGoRouterState());
      expect(widget, isA<ProjectListScreen>());
    });

    test("settings route builds SettingsScreen inside a fullscreen-dialog page", () {
      final page = AppRouteDef.settings.toGoRoute().pageBuilder!(_FakeBuildContext(), _FakeGoRouterState());
      expect(page, isA<MaterialPage<void>>());
      final materialPage = page as MaterialPage<void>;
      expect(materialPage.fullscreenDialog, isTrue);
      expect(materialPage.child, isA<SettingsScreen>());
    });

    test("settings child routes build the notifications, plugins, and profile screens", () {
      final settingsRoute = buildAppRoutes().whereType<GoRoute>().singleWhere(
        (route) => route.path == AppRouteDef.settings.path,
      );
      final children = settingsRoute.routes.whereType<GoRoute>().toList();

      expect(children.map((route) => route.path), equals(["notifications", "plugins", "profile"]));
      expect(children[0].builder!(_FakeBuildContext(), _FakeGoRouterState()), isA<NotificationSettingsScreen>());
      expect(children[1].builder!(_FakeBuildContext(), _FakeGoRouterState()), isA<PluginSettingsScreen>());
      expect(children[2].builder!(_FakeBuildContext(), _FakeGoRouterState()), isA<ProfileScreen>());
      expect(
        _composeRoutePath(parentPath: AppRouteDef.settings.path, path: children[0].path),
        AppRouteDef.settingsNotifications.path,
      );
      expect(
        _composeRoutePath(parentPath: AppRouteDef.settings.path, path: children[1].path),
        AppRouteDef.settingsPlugins.path,
      );
      expect(
        _composeRoutePath(parentPath: AppRouteDef.settings.path, path: children[2].path),
        AppRouteDef.settingsProfile.path,
      );
    });

    test("newSession route builds NewSessionScreen", () {
      final widget = AppRouteDef.newSession.toGoRoute().builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(pathParameters: {"projectId": "proj-42"}, queryParameters: {"name": "Project One"}),
      );
      expect(widget, isA<NewSessionScreen>());
      expect((widget as NewSessionScreen).projectId, "proj-42");
      expect(widget.projectName, "Project One");
    });
  });

  group("buildAppRoutes", () {
    test("explicit route table covers every AppRouteDef exactly once", () {
      final routes = buildAppRoutes();
      final registeredPaths = _collectAbsoluteRoutePaths(routes: routes);

      expect(registeredPaths, hasLength(AppRouteDef.values.length));
      expect(
        registeredPaths.toSet(),
        equals(AppRouteDef.values.map((def) => def.path).toSet()),
      );
    });

    test("nested session route segments compose to AppRouteDef templates", () {
      expect("${AppRouteDef.projects.path}/:projectId/sessions", AppRouteDef.sessions.path);
      expect("${AppRouteDef.sessions.path}/new", AppRouteDef.newSession.path);
      expect("${AppRouteDef.sessions.path}/:sessionId", AppRouteDef.sessionDetail.path);
      expect("${AppRouteDef.sessionDetail.path}/diffs", AppRouteDef.sessionDiffs.path);
    });

    test("keeps non-session routes flat and session routes nested under a ShellRoute", () {
      final routes = buildAppRoutes();
      final flatPaths = routes.whereType<GoRoute>().map((route) => route.path).toList();
      final shell = _sessionShellRoute();
      final allPaths = _collectAbsoluteRoutePaths(routes: routes);

      expect(
        flatPaths,
        equals([AppRouteDef.splash.path, AppRouteDef.login.path, AppRouteDef.projects.path, AppRouteDef.settings.path]),
      );
      expect(shell.routes, hasLength(1));
      expect(
        allPaths,
        equals([
          AppRouteDef.splash.path,
          AppRouteDef.login.path,
          AppRouteDef.projects.path,
          AppRouteDef.sessions.path,
          AppRouteDef.newSession.path,
          AppRouteDef.sessionDetail.path,
          AppRouteDef.sessionDiffs.path,
          AppRouteDef.settings.path,
          AppRouteDef.settingsNotifications.path,
          AppRouteDef.settingsPlugins.path,
          AppRouteDef.settingsProfile.path,
        ]),
      );
    });

    test("registers newSession before dynamic session route inside the shell", () {
      final shell = _sessionShellRoute();
      final sessionsRoute = shell.routes.whereType<GoRoute>().single;
      final childPaths = sessionsRoute.routes.whereType<GoRoute>().map((route) => route.path).toList();

      expect(childPaths, equals(["new", ":sessionId"]));
    });

    test("session shell builder hoists cubit provider above split shell", () {
      final shell = _sessionShellRoute();
      final widget = shell.builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(
          pathParameters: {"projectId": "proj-42", "sessionId": "ses-99"},
          queryParameters: {"name": "My Project"},
        ),
        const SizedBox(),
      );

      expect(widget, isA<SessionListCubitProvider>());
      final provider = widget as SessionListCubitProvider;
      expect(provider.key, const ValueKey("session-list-cubit-proj-42"));
      expect(provider.projectId, "proj-42");
      expect(provider.child, isA<SessionSplitShell>());
    });

    test("detail route preserves typed route decoding and stable key", () {
      final detailRoute = _sessionDetailRoute();

      final page = detailRoute.pageBuilder!(
        _FakeBuildContext(),
        _FakeGoRouterState(
          pathParameters: {"projectId": "proj-42", "sessionId": "ses-99"},
          queryParameters: {"name": "My Project", "title": "Debug session", "readOnly": "true"},
        ),
      );
      final otherSessionPage = detailRoute.pageBuilder!(
        _FakeBuildContext(),
        _FakeGoRouterState(
          pathParameters: {"projectId": "proj-42", "sessionId": "ses-100"},
          queryParameters: {"name": "My Project", "title": "Other session", "readOnly": "false"},
        ),
      );
      final scope = (page as CustomTransitionPage<void>).child as ImperativePaneRouteScope;
      final widget = scope.child;

      expect(page.key, isNot(otherSessionPage.key));
      expect(widget, isA<SessionDetailScreen>());
      final screen = widget as SessionDetailScreen;
      expect(screen.key, const ValueKey("session-detail-ses-99"));
      expect(screen.projectId, "proj-42");
      expect(screen.projectName, "My Project");
      expect(screen.sessionId, "ses-99");
      expect(screen.sessionTitle, "Debug session");
      expect(screen.readOnly, isTrue);
    });

    test("diffs route preserves typed route decoding and stable key", () {
      final diffsRoute = _sessionDiffsRoute();

      final page = diffsRoute.pageBuilder!(
        _FakeBuildContext(),
        _FakeGoRouterState(pathParameters: {"projectId": "proj-42", "sessionId": "ses-99"}),
      );
      final scope = (page as CustomTransitionPage<void>).child as ImperativePaneRouteScope;
      final widget = scope.child;

      expect(widget, isA<SessionDiffsScreen>());
      final screen = widget as SessionDiffsScreen;
      expect(screen.key, const ValueKey("session-diffs-ses-99"));
      expect(screen.projectId, "proj-42");
      expect(screen.sessionId, "ses-99");
    });

    group("nested route tree invariants", () {
      test("registers exactly one shell route", () {
        expect(_collectShellRoutes(routes: buildAppRoutes()), hasLength(1));
      });

      test("shell owns exactly one first-level session route", () {
        final shell = _sessionShellRoute();
        expect(shell.routes.whereType<GoRoute>(), hasLength(1));
      });

      test("first-level shell route is the relative sessions segment", () {
        final shell = _sessionShellRoute();
        final sessionsRoute = shell.routes.whereType<GoRoute>().single;
        expect(sessionsRoute.path, ":projectId/sessions");
        expect(
          _composeRoutePath(parentPath: AppRouteDef.projects.path, path: sessionsRoute.path),
          AppRouteDef.sessions.path,
        );
      });

      test("new-session child uses a relative segment", () {
        final sessionsRoute = _sessionShellRoute().routes.whereType<GoRoute>().single;
        expect(sessionsRoute.routes.whereType<GoRoute>().first.path, "new");
      });

      test("detail child uses a relative dynamic segment", () {
        final sessionsRoute = _sessionShellRoute().routes.whereType<GoRoute>().single;
        expect(sessionsRoute.routes.whereType<GoRoute>().last.path, ":sessionId");
      });

      test("diffs child uses a relative segment under detail", () {
        expect(_sessionDiffsRoute().path, "diffs");
      });

      test("new-session child is declared before dynamic detail", () {
        final sessionsRoute = _sessionShellRoute().routes.whereType<GoRoute>().single;
        expect(sessionsRoute.routes.whereType<GoRoute>().map((route) => route.path), equals(["new", ":sessionId"]));
      });

      test("only non-session routes remain top-level GoRoutes", () {
        expect(buildAppRoutes().whereType<GoRoute>().map((route) => route.path), [
          AppRouteDef.splash.path,
          AppRouteDef.login.path,
          AppRouteDef.projects.path,
          AppRouteDef.settings.path,
        ]);
      });

      test("detail route has exactly one nested child", () {
        expect(_sessionDetailRoute().routes.whereType<GoRoute>(), hasLength(1));
      });

      test("composed new-session path remains absolute", () {
        final sessionsRoute = _sessionShellRoute().routes.whereType<GoRoute>().single;
        final newRoute = sessionsRoute.routes.whereType<GoRoute>().first;
        expect(
          _composeRoutePath(parentPath: AppRouteDef.sessions.path, path: newRoute.path),
          AppRouteDef.newSession.path,
        );
      });

      test("composed diffs path remains absolute", () {
        expect(
          _composeRoutePath(parentPath: AppRouteDef.sessionDetail.path, path: _sessionDiffsRoute().path),
          AppRouteDef.sessionDiffs.path,
        );
      });
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
            const AppRoute.sessions(
              projectId: "proj_1",
              projectName: null,
              supportsDedicatedWorktrees: null,
            ).buildPath(),
            const AppRoute.sessionDetail(
              projectId: "proj_1",
              projectName: null,
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
          const AppRoute.sessions(
            projectId: "proj_1",
            projectName: null,
            supportsDedicatedWorktrees: null,
          ).buildPath(),
          const AppRoute.sessionDetail(
            projectId: "proj_1",
            projectName: null,
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

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

List<String> _collectAbsoluteRoutePaths({required List<RouteBase> routes, String parentPath = ""}) {
  final paths = <String>[];
  for (final route in routes) {
    switch (route) {
      case GoRoute(:final path, :final routes):
        final absolutePath = _composeRoutePath(parentPath: parentPath, path: path);
        paths.add(absolutePath);
        paths.addAll(_collectAbsoluteRoutePaths(routes: routes, parentPath: absolutePath));
      case ShellRoute(:final routes):
        paths.addAll(_collectAbsoluteRoutePaths(routes: routes, parentPath: parentPath));
      default:
        throw StateError("Unsupported route type ${route.runtimeType}");
    }
  }
  return paths;
}

List<ShellRoute> _collectShellRoutes({required List<RouteBase> routes}) {
  final shells = <ShellRoute>[];
  for (final route in routes) {
    switch (route) {
      case GoRoute(:final routes):
        shells.addAll(_collectShellRoutes(routes: routes));
      case ShellRoute(:final routes):
        shells.add(route);
        shells.addAll(_collectShellRoutes(routes: routes));
      default:
        throw StateError("Unsupported route type ${route.runtimeType}");
    }
  }
  return shells;
}

ShellRoute _sessionShellRoute() => _collectShellRoutes(routes: buildAppRoutes()).single;

String _composeRoutePath({required String parentPath, required String path}) {
  if (path.startsWith("/")) return path;
  if (parentPath.endsWith("/")) return "$parentPath$path";
  return "$parentPath/$path";
}

GoRoute _sessionDetailRoute() {
  final shell = _sessionShellRoute();
  final sessionsRoute = shell.routes.whereType<GoRoute>().single;
  return sessionsRoute.routes.whereType<GoRoute>().singleWhere((route) => route.path == ":sessionId");
}

GoRoute _sessionDiffsRoute() {
  final detailRoute = _sessionDetailRoute();
  return detailRoute.routes.whereType<GoRoute>().singleWhere((route) => route.path == "diffs");
}

class _FakeBuildContext extends Fake implements BuildContext {
  // No inherited widgets in this synthetic context: MediaQuery lookups in
  // page builders (reduced-motion checks) resolve to null → defaults.
  // MediaQuery is an InheritedModel, so InheritedModel.inheritFrom resolves
  // it via getElementForInheritedWidgetOfExactType (not the plain
  // dependOnInheritedWidgetOfExactType), so that is the method to stub.
  @override
  InheritedElement? getElementForInheritedWidgetOfExactType<T extends InheritedWidget>() => null;
}

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

  @override
  ValueKey<String> get pageKey => const ValueKey<String>("/login");
}
