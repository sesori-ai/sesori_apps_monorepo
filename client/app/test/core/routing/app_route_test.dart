import "package:cupertino_ui/cupertino_ui.dart" show CupertinoPage;
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
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
import "package:sesori_mobile/features/settings/harnesses_settings_screen.dart";
import "package:sesori_mobile/features/settings/notification_settings_screen.dart";
import "package:sesori_mobile/features/settings/profile_screen.dart";
import "package:sesori_mobile/features/settings/settings_screen.dart";
import "package:sesori_mobile/features/splash/splash_screen.dart";

import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

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

    test("carries the presentation for settingsHarnesses", () {
      expect(
        const AppRoute.settingsHarnesses(presentation: HarnessSettingsPresentation.modal).buildPath(),
        "/settings/harnesses?presentation=modal",
      );
      expect(
        const AppRoute.settingsHarnesses(presentation: HarnessSettingsPresentation.pushed).buildPath(),
        "/settings/harnesses?presentation=pushed",
      );
    });

    test("substitutes projectId for sessions", () {
      final result = const AppRoute.sessions(
        projectId: "proj-123",
        projectName: null,
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
        bridgeId: null,
      ).buildPath();
      expect(result, "/projects/proj-123/sessions/ses-456?readOnly=false");
    });

    test("builds Device Canvas session routes without project identity", () {
      final result = const AppRoute.deviceCanvasSession(
        sessionId: "ses/456",
        bridgeId: "bridge-1",
        readOnly: false,
      ).buildPath();

      expect(result, "/sessions/ses%2F456?bridgeId=bridge-1&readOnly=false");
      expect(result, isNot(contains("project")));
    });

    test("includes projectName as query param for sessions", () {
      final result = const AppRoute.sessions(
        projectId: "proj-123",
        projectName: "My Project",
      ).buildPath();
      expect(result, contains("/projects/proj-123/sessions?"));
      expect(result, contains("name=My+Project"));
    });

    test("omits query string when no query params set", () {
      final result = const AppRoute.sessions(
        projectId: "proj-123",
        projectName: null,
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
        bridgeId: "bridge-1",
      ).buildPath();
      expect(result, contains("/projects/proj-1/sessions/ses-1?"));
      expect(result, isNot(contains("& more")));
      expect(result, contains("name=Project+One"));
      expect(result, contains("readOnly=true"));
      expect(result, contains("bridgeId=bridge-1"));
    });

    test("always includes readOnly in query when false", () {
      final result = const AppRoute.sessionDetail(
        projectId: "proj-1",
        projectName: null,
        sessionId: "ses-1",
        sessionTitle: null,
        readOnly: false,
        bridgeId: null,
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
        bridgeId: null,
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

  group("flat routes", () {
    test("splash route builds SplashScreen", () {
      final page = AppRouteDef.splash.toGoRoute().pageBuilder!(_FakeBuildContext(), _FakeGoRouterState());
      expect(page, isA<MaterialPage<void>>());
      expect((page as MaterialPage<void>).child, isA<SplashScreen>());
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
      final page = AppRouteDef.projects.toGoRoute().pageBuilder!(_FakeBuildContext(), _FakeGoRouterState());
      expect(page, isA<MaterialPage<void>>());
      expect((page as MaterialPage<void>).child, isA<ProjectListScreen>());
    });

    test("Device Canvas session route builds a projectless detail screen", () {
      final page = AppRouteDef.deviceCanvasSession.toGoRoute().pageBuilder!(
        _FakeBuildContext(),
        _FakeGoRouterState(
          pathParameters: {"sessionId": "ses-1"},
          queryParameters: {"bridgeId": "bridge-1", "readOnly": "false"},
        ),
      ) as MaterialPage<void>;

      expect(page.child, isA<DeviceCanvasSessionDetailScreen>());
      final screen = page.child as DeviceCanvasSessionDetailScreen;
      expect(screen.sessionId, "ses-1");
      expect(screen.bridgeId, "bridge-1");
      expect(screen.readOnly, isFalse);
    });

    // A CupertinoPage, so the bottom-up modal slide is the same on Android,
    // whose default page transition ignores fullscreenDialog.
    test("settings route builds SettingsScreen inside a fullscreen-dialog page", () {
      final page = AppRouteDef.settings.toGoRoute().pageBuilder!(_FakeBuildContext(), _FakeGoRouterState());
      expect(page, isA<CupertinoPage<void>>());
      final settingsPage = page as CupertinoPage<void>;
      expect(settingsPage.fullscreenDialog, isTrue);
      expect(settingsPage.child, isA<SettingsScreen>());
    });

    test("settings child routes build their screens without management nesting", () {
      final settingsRoute = buildAppRoutes().whereType<GoRoute>().singleWhere(
        (route) => route.path == AppRouteDef.settings.path,
      );
      final children = settingsRoute.routes.whereType<GoRoute>().toList();

      expect(
        children.map((route) => route.path),
        equals(["notifications", "harnesses", "profile"]),
      );
      final notificationsPage = children[0].pageBuilder!(
        _FakeBuildContext(),
        _FakeGoRouterState(),
      ) as MaterialPage<void>;
      expect(notificationsPage.child, isA<NotificationSettingsScreen>());
      // Harnesses rise as a modal from the new-session harness menu and push
      // in from the settings list, so the route builds its own page per
      // presentation instead of taking the default push for both.
      final harnessesModalPage = children[1].pageBuilder!(
        _FakeBuildContext(),
        _FakeGoRouterState(queryParameters: {harnessSettingsPresentationQueryParam: "modal"}),
      ) as CupertinoPage<void>;
      expect(harnessesModalPage.fullscreenDialog, isTrue);
      expect(harnessesModalPage.child, isA<HarnessesSettingsScreen>());
      final harnessesPushedPage = children[1].pageBuilder!(
        _FakeBuildContext(),
        _FakeGoRouterState(queryParameters: {harnessSettingsPresentationQueryParam: "pushed"}),
      ) as MaterialPage<void>;
      expect(harnessesPushedPage.child, isA<HarnessesSettingsScreen>());
      expect(
        (harnessesPushedPage.child as HarnessesSettingsScreen).presentation,
        HarnessSettingsPresentation.pushed,
      );
      expect(children[1].routes, isEmpty);
      final profilePage = children[2].pageBuilder!(
        _FakeBuildContext(),
        _FakeGoRouterState(),
      ) as MaterialPage<void>;
      expect(profilePage.child, isA<ProfileScreen>());
      expect(
        _composeRoutePath(parentPath: AppRouteDef.settings.path, path: children[0].path),
        AppRouteDef.settingsNotifications.path,
      );
      expect(
        _composeRoutePath(parentPath: AppRouteDef.settings.path, path: children[1].path),
        AppRouteDef.settingsHarnesses.path,
      );
      expect(
        _composeRoutePath(parentPath: AppRouteDef.settings.path, path: children[2].path),
        AppRouteDef.settingsProfile.path,
      );
    });

    test("newSession route builds NewSessionScreen", () {
      final page = AppRouteDef.newSession.toGoRoute().pageBuilder!(
        _FakeBuildContext(),
        _FakeGoRouterState(pathParameters: {"projectId": "proj-42"}, queryParameters: {"name": "Project One"}),
      ) as MaterialPage<void>;
      final widget = page.child;
      expect(widget, isA<NewSessionScreen>());
      expect((widget as NewSessionScreen).projectId, "proj-42");
      expect(widget.projectName, "Project One");
    });
  });

  group("buildAppRoutes", () {
    test("every route provides an explicit standalone page", () {
      void expectExplicitPages(List<RouteBase> routes) {
        for (final route in routes) {
          switch (route) {
            case GoRoute(:final pageBuilder, :final routes):
              expect(
                pageBuilder,
                isNotNull,
                reason: "GoRoute ${route.path} must not rely on go_router's legacy MaterialApp detection",
              );
              expectExplicitPages(routes);
            case ShellRoute(:final pageBuilder, :final routes):
              expect(
                pageBuilder,
                isNotNull,
                reason: "ShellRoute must not rely on go_router's legacy MaterialApp detection",
              );
              expectExplicitPages(routes);
            default:
              throw StateError("Unsupported route type ${route.runtimeType}");
          }
        }
      }

      expectExplicitPages(buildAppRoutes());
    });

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
        equals([
          AppRouteDef.splash.path,
          AppRouteDef.login.path,
          AppRouteDef.projects.path,
          AppRouteDef.deviceCanvasSession.path,
          AppRouteDef.settings.path,
        ]),
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
          AppRouteDef.deviceCanvasSession.path,
          AppRouteDef.settings.path,
          AppRouteDef.settingsNotifications.path,
          AppRouteDef.settingsHarnesses.path,
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

    test("session shell page hoists cubit provider above split shell", () {
      final getIt = GetIt.instance;
      getIt.registerSingleton<ProjectViewingService>(stubbedProjectViewingService());
      addTearDown(() => getIt.unregister<ProjectViewingService>());

      final shell = _sessionShellRoute();
      final page = shell.pageBuilder!(
        _FakeBuildContext(),
        _FakeGoRouterState(
          pathParameters: {"projectId": "proj-42", "sessionId": "ses-99"},
          queryParameters: {"name": "My Project"},
        ),
        const SizedBox(),
      ) as MaterialPage<void>;
      final widget = page.child;

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

    test("detail route changes page identity when only the Device Canvas bridge changes", () {
      final detailRoute = _sessionDetailRoute();
      final bridgeOne = detailRoute.pageBuilder!(
        _FakeBuildContext(),
        _FakeGoRouterState(
          pathParameters: {"projectId": "proj-42", "sessionId": "ses-99"},
          queryParameters: {"bridgeId": "bridge-1", "readOnly": "false"},
        ),
      );
      final bridgeTwo = detailRoute.pageBuilder!(
        _FakeBuildContext(),
        _FakeGoRouterState(
          pathParameters: {"projectId": "proj-42", "sessionId": "ses-99"},
          queryParameters: {"bridgeId": "bridge-2", "readOnly": "false"},
        ),
      );

      expect(bridgeOne.key, isNot(bridgeTwo.key));
      final bridgeTwoScope = (bridgeTwo as CustomTransitionPage<void>).child as ImperativePaneRouteScope;
      expect((bridgeTwoScope.child as SessionDetailScreen).bridgeId, "bridge-2");
    });

    test("diffs route preserves typed route decoding and stable key", () {
      final diffsRoute = _sessionDiffsRoute();

      final page = diffsRoute.pageBuilder!(
        _FakeBuildContext(),
        _FakeGoRouterState(
          pathParameters: {"projectId": "proj-42", "sessionId": "ses-99"},
          queryParameters: {"bridgeId": "bridge-1"},
        ),
      );
      final scope = (page as CustomTransitionPage<void>).child as ImperativePaneRouteScope;
      final widget = scope.child;

      expect(widget, isA<SessionDiffsScreen>());
      final screen = widget as SessionDiffsScreen;
      expect(screen.key, const ValueKey("session-diffs-ses-99"));
      expect(screen.projectId, "proj-42");
      expect(screen.sessionId, "ses-99");
      expect(screen.bridgeId, "bridge-1");
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

      test("only shell-independent routes remain top-level GoRoutes", () {
        expect(buildAppRoutes().whereType<GoRoute>().map((route) => route.path), [
          AppRouteDef.splash.path,
          AppRouteDef.login.path,
          AppRouteDef.projects.path,
          AppRouteDef.deviceCanvasSession.path,
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
            ).buildPath(),
            const AppRoute.sessionDetail(
              projectId: "proj_1",
              projectName: null,
              sessionId: "ses_1",
              sessionTitle: "Session Title",
              readOnly: false,
              bridgeId: null,
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
          ).buildPath(),
          const AppRoute.sessionDetail(
            projectId: "proj_1",
            projectName: null,
            sessionId: "ses_1",
            sessionTitle: "Session Title",
            readOnly: false,
            bridgeId: null,
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

class _FakeBuildContext() extends Fake implements BuildContext {
  // No inherited widgets in this synthetic context: MediaQuery lookups in
  // page builders (reduced-motion checks) resolve to null → defaults.
  // MediaQuery is an InheritedModel, so InheritedModel.inheritFrom resolves
  // it via getElementForInheritedWidgetOfExactType (not the plain
  // dependOnInheritedWidgetOfExactType), so that is the method to stub.
  @override
  InheritedElement? getElementForInheritedWidgetOfExactType<T extends InheritedWidget>() => null;
}

class _FakeGoRouterState({
  @override final Map<String, String> pathParameters = const {},
  Map<String, String> queryParameters = const {},
}) extends Fake implements GoRouterState {
  @override
  final String? name = null;

  @override
  final String? path = "/";

  @override
  final Uri uri = Uri(path: "/", queryParameters: queryParameters.isEmpty ? null : queryParameters);

  @override
  ValueKey<String> get pageKey => const ValueKey<String>("/login");
}
// ignore_for_file: avoid_implementing_value_types, tests use a lightweight GoRouterState fake
