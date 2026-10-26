import "dart:async";

import "package:cupertino_ui/cupertino_ui.dart" show CupertinoPage;
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/go_router_route_dispatcher.dart";
import "package:sesori_mobile/core/routing/app_router.dart";
import "package:sesori_mobile/core/routing/imperative_pane_route.dart";
import "package:sesori_mobile/features/home/home_screen.dart";
import "package:sesori_mobile/features/login/login_screen.dart";
import "package:sesori_mobile/features/new_session/new_session_screen.dart";
import "package:sesori_mobile/features/session_detail/session_detail_screen.dart";
import "package:sesori_mobile/features/session_diffs/session_diffs_screen.dart";
import "package:sesori_mobile/features/settings/harnesses_settings_screen.dart";
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

  group("deep-link routing diagnostics", () {
    for (final scheme in ["https", bundleId]) {
      test("retains origin without the incoming payload ($scheme)", () {
        TestWidgetsFlutterBinding.ensureInitialized();
        final previousLevel = logLevel;
        addTearDown(() => setLogLevel(previousLevel));
        setLogLevel(scheme == bundleId ? LogLevel.debug : LogLevel.info);
        final uri = Uri.parse("$scheme://sesori.com/link/private-path?token=private-token#private-fragment");
        final unmatched = appRouter.configuration.findMatch(uri);
        expect(unmatched.isError, isTrue);
        final previousRoutes = appRouter.routerDelegate.currentConfiguration;
        final logs = <String>[];
        final result = runZoned(
          () => appRouter.routeInformationParser.onParserException!(_FakeBuildContext(), unmatched),
          zoneSpecification: ZoneSpecification(print: (_, _, _, message) => logs.add(message)),
        );
        expect(result, same(previousRoutes));
        expect(unmatched.uri, uri);
        expect(logs, hasLength(1));
        expect(logs.single, contains("scheme=$scheme, host=sesori.com"));
        expect(logs.single, contains(scheme == bundleId ? "ignoring deep link" : "could not match route"));
        expect(logs.single, isNot(contains("private-")));
      });
    }
  });

  group("AppRoute.buildPath", () {
    test("returns raw path for parameterless routes", () {
      expect(const AppRoute.splash().buildPath(), "/splash");
      expect(const AppRoute.login().buildPath(), "/login");
      expect(const AppRoute.home().buildPath(), "/sessions");
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

    test("substitutes path params for sessionDetail", () {
      final result = const AppRoute.sessionDetail(
        projectId: "proj-123",
        projectName: null,
        sessionId: "ses-456",
        sessionTitle: null,
        readOnly: false,
        fromLaunch: false,
      ).buildPath();
      expect(result, "/sessions/proj-123/ses-456?readOnly=false");
    });

    test("includes title and readOnly as query params for sessionDetail", () {
      final result = const AppRoute.sessionDetail(
        projectId: "proj-1",
        projectName: "Project One",
        sessionId: "ses-1",
        sessionTitle: "hello world & more",
        readOnly: true,
        fromLaunch: false,
      ).buildPath();
      expect(result, contains("/sessions/proj-1/ses-1?"));
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
        fromLaunch: false,
      ).buildPath();
      expect(result, "/sessions/proj-1/ses-1?readOnly=false");
    });

    test("encodes path params with special characters", () {
      final result = const AppRoute.sessionDetail(
        projectId: "project/with?special&chars",
        projectName: null,
        sessionId: "id/with?special&chars",
        sessionTitle: null,
        readOnly: false,
        fromLaunch: false,
      ).buildPath();
      expect(
        result,
        "/sessions/project%2Fwith%3Fspecial%26chars/id%2Fwith%3Fspecial%26chars?readOnly=false",
      );
    });

    test("carries an optional project for newSession", () {
      expect(const AppRoute.newSession(projectId: null, projectName: null).buildPath(), "/sessions/new");
      final named = const AppRoute.newSession(projectId: "proj-42", projectName: "Project One").buildPath();
      expect(named, startsWith("/sessions/new?"));
      expect(Uri.parse(named).queryParameters, {"project": "proj-42", "name": "Project One"});
    });
  });

  group("flat routes", () {
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

    test("home route builds HomeScreen", () {
      final widget = AppRouteDef.home.toGoRoute().builder!(_FakeBuildContext(), _FakeGoRouterState());
      expect(widget, isA<HomeScreen>());
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

    test("harness-only shell is a sibling of Settings with overview ancestry", () {
      final settingsRoute = _signedInRoutes().whereType<GoRoute>().singleWhere(
        (route) => route.path == AppRouteDef.settings.path,
      );
      final children = settingsRoute.routes;
      expect((children[0] as GoRoute).path, "default-input");
      expect((children[1] as GoRoute).path, "notifications");
      expect((children[2] as GoRoute).path, "profile");
      expect((children[3] as GoRoute).path, "computers");
      expect((children[4] as GoRoute).path, "projects");
      expect(children, hasLength(5));
      final harnessShell = _signedInRoutes().whereType<ShellRoute>().singleWhere(
        (shell) => shell.routes.whereType<GoRoute>().any((route) => route.path == AppRouteDef.settingsHarnesses.path),
      );
      final overview = harnessShell.routes.single as GoRoute;
      expect(overview.path, AppRouteDef.settingsHarnesses.path);
      expect((overview.routes.single as GoRoute).path, ":$pluginIdPathParam");
      const child = SizedBox();
      final modal = harnessShell.pageBuilder!(
        _FakeBuildContext(),
        _FakeGoRouterState(queryParameters: {harnessSettingsPresentationQueryParam: "modal"}),
        child,
      ) as CupertinoPage<void>;
      expect(modal.fullscreenDialog, isTrue);
      expect((modal.child as NavigatorPopHandler<void>).child, isA<HarnessesSettingsScreen>());
      final pushed = harnessShell.pageBuilder!(
        _FakeBuildContext(),
        _FakeGoRouterState(queryParameters: {harnessSettingsPresentationQueryParam: "pushed"}),
        child,
      ) as MaterialPage<void>;
      final pushedScreen = (pushed.child as NavigatorPopHandler<void>).child as HarnessesSettingsScreen;
      expect(pushedScreen.child, same(child));
    });

    // Archived is a Settings page, so it pushes with the platform transition
    // instead of rising as a modal.
    test("archive shell pushes as a standard page", () {
      final page = buildArchivedSessionsRoute().pageBuilder!(
        _FakeBuildContext(),
        _FakeGoRouterState(),
        const SizedBox(),
      );
      expect(page, isA<MaterialPage<void>>());
      expect((page as MaterialPage<void>).fullscreenDialog, isFalse);
    });

    test("newSession route builds NewSessionScreen", () {
      final widget = AppRouteDef.newSession.toGoRoute().builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(queryParameters: {"project": "proj-42", "name": "Project One"}),
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
      expect(registeredPaths.toSet(), equals(AppRouteDef.values.map((def) => def.path).toSet()));
    });

    test("nested session route segments compose to AppRouteDef templates", () {
      expect("${AppRouteDef.home.path}/new", AppRouteDef.newSession.path);
      expect("${AppRouteDef.home.path}/:projectId/:sessionId", AppRouteDef.sessionDetail.path);
      expect("${AppRouteDef.sessionDetail.path}/diffs", AppRouteDef.sessionDiffs.path);
    });

    test("keeps live sessions nested and modal flows in signed-in shells", () {
      final routes = buildAppRoutes();
      final flatPaths = routes.whereType<GoRoute>().map((route) => route.path).toList();
      final signedInPaths = _signedInRoutes().whereType<GoRoute>().map((route) => route.path).toList();
      final shell = _sessionShellRoute();
      final allPaths = _collectAbsoluteRoutePaths(routes: routes);

      expect(flatPaths, equals([AppRouteDef.splash.path, AppRouteDef.login.path]));
      expect(signedInPaths, equals([AppRouteDef.settings.path]));
      expect(shell.routes, hasLength(1));
      expect(
        allPaths,
        equals([
          AppRouteDef.splash.path,
          AppRouteDef.login.path,
          AppRouteDef.home.path,
          AppRouteDef.newSession.path,
          AppRouteDef.sessionDetail.path,
          AppRouteDef.sessionDiffs.path,
          AppRouteDef.archivedSessions.path,
          AppRouteDef.archivedSessionDetail.path,
          AppRouteDef.settingsHarnesses.path,
          AppRouteDef.settingsHarnessDetail.path,
          AppRouteDef.settings.path,
          AppRouteDef.settingsDefaultInput.path,
          AppRouteDef.settingsNotifications.path,
          AppRouteDef.settingsProfile.path,
          AppRouteDef.settingsComputers.path,
          AppRouteDef.settingsProjects.path,
        ]),
      );
    });

    test("registers newSession before dynamic session route inside the shell", () {
      final shell = _sessionShellRoute();
      final sessionsRoute = shell.routes.whereType<GoRoute>().single;
      final childPaths = sessionsRoute.routes.whereType<GoRoute>().map((route) => route.path).toList();

      expect(childPaths, equals(["new", ":projectId/:sessionId"]));
    });

    test("session shell lists the home beside the open session", () {
      final shell = _sessionShellRoute();
      final widget = shell.builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(pathParameters: {"projectId": "proj-42", "sessionId": "ses-99"}),
        const SizedBox(),
      );

      // System back reaches the shell's own navigator before the shell page.
      expect(widget, isA<NavigatorPopHandler<void>>());
      final sidebarShell = (widget as NavigatorPopHandler<void>).child as SessionSidebarShell;
      final sidebar = sidebarShell.sidebar as HomeSidebar;
      expect(sidebar.selectedSessionId, "ses-99");
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
      test("registers separate signed-in, live session, archive and harness shell routes", () {
        expect(_collectShellRoutes(routes: buildAppRoutes()), hasLength(4));
      });

      test("shell owns exactly one first-level session route", () {
        final shell = _sessionShellRoute();
        expect(shell.routes.whereType<GoRoute>(), hasLength(1));
      });

      test("first-level shell route is the home", () {
        final shell = _sessionShellRoute();
        expect(shell.routes.whereType<GoRoute>().single.path, AppRouteDef.home.path);
      });

      test("new-session child uses a relative segment", () {
        final sessionsRoute = _sessionShellRoute().routes.whereType<GoRoute>().single;
        expect(sessionsRoute.routes.whereType<GoRoute>().first.path, "new");
      });

      test("detail child uses a relative dynamic segment", () {
        final sessionsRoute = _sessionShellRoute().routes.whereType<GoRoute>().single;
        expect(sessionsRoute.routes.whereType<GoRoute>().last.path, ":projectId/:sessionId");
      });

      test("diffs child uses a relative segment under detail", () {
        expect(_sessionDiffsRoute().path, "diffs");
      });

      test("new-session child is declared before dynamic detail", () {
        final sessionsRoute = _sessionShellRoute().routes.whereType<GoRoute>().single;
        expect(
          sessionsRoute.routes.whereType<GoRoute>().map((route) => route.path),
          equals(["new", ":projectId/:sessionId"]),
        );
      });

      test("only splash and login sit outside the signed-in shell", () {
        expect(buildAppRoutes().whereType<GoRoute>().map((route) => route.path), [
          AppRouteDef.splash.path,
          AppRouteDef.login.path,
        ]);
        expect(_signedInRoutes().whereType<GoRoute>().map((route) => route.path), [AppRouteDef.settings.path]);
      });

      test("detail route has exactly one nested child", () {
        expect(_sessionDetailRoute().routes.whereType<GoRoute>(), hasLength(1));
      });

      test("composed new-session path remains absolute", () {
        final sessionsRoute = _sessionShellRoute().routes.whereType<GoRoute>().single;
        final newRoute = sessionsRoute.routes.whereType<GoRoute>().first;
        expect(
          _composeRoutePath(parentPath: AppRouteDef.home.path, path: newRoute.path),
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
    test("dismissPopups runs before rebuilding the stack and pushing remaining routes", () async {
      final goCalls = <String>[];
      final pushCalls = <String>[];
      final dispatcher = GoRouterRouteDispatcher.test(
        goRoute: goCalls.add,
        pushRoute: (route) async {
          pushCalls.add(route);
        },
        dismissPopups: () => goCalls.add("dismiss"),
        routerReady: Future<void>.value(),
      );

      dispatcher.dismissPopups();
      dispatcher.replaceStack(
        stack: RouteStack(
          paths: [
            const AppRoute.home().buildPath(),
            const AppRoute.sessionDetail(
              projectId: "proj_1",
              projectName: null,
              sessionId: "ses_1",
              sessionTitle: "Session Title",
              readOnly: false,
              fromLaunch: false,
            ).buildPath(),
          ],
        ),
      );
      await dispatcher.flushPendingForTesting();

      expect(goCalls, equals(["dismiss", const AppRoute.home().buildPath()]));
      expect(
        pushCalls,
        equals([
          const AppRoute.sessionDetail(
            projectId: "proj_1",
            projectName: null,
            sessionId: "ses_1",
            sessionTitle: "Session Title",
            readOnly: false,
            fromLaunch: false,
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
        dismissPopups: () => goCalls.add("dismiss"),
        routerReady: Future<void>.value(),
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

/// The routes inside the signed-in shell, whose builder mounts `SessionScope`.
List<RouteBase> _signedInRoutes() => buildAppRoutes().whereType<ShellRoute>().single.routes;

ShellRoute _sessionShellRoute() =>
    _collectShellRoutes(routes: buildAppRoutes())
        .singleWhere((shell) => shell.routes.whereType<GoRoute>().firstOrNull?.path == AppRouteDef.home.path);

String _composeRoutePath({required String parentPath, required String path}) {
  if (path.startsWith("/")) return path;
  if (parentPath.endsWith("/")) return "$parentPath$path";
  return "$parentPath/$path";
}

GoRoute _sessionDetailRoute() {
  final shell = _sessionShellRoute();
  final sessionsRoute = shell.routes.whereType<GoRoute>().single;
  return sessionsRoute.routes.whereType<GoRoute>().singleWhere(
    (route) => route.path == ":$projectIdPathParam/:$sessionIdPathParam",
  );
}

GoRoute _sessionDiffsRoute() {
  final detailRoute = _sessionDetailRoute();
  return detailRoute.routes.whereType<GoRoute>().singleWhere((route) => route.path == "diffs");
}

class _FakeBuildContext() extends Fake implements BuildContext {
  // No inherited widgets in this synthetic context: the MediaQuery and View
  // lookups in page builders (reduced-motion checks) resolve to null →
  // defaults. MediaQuery is an InheritedModel, so InheritedModel.inheritFrom
  // resolves it via getElementForInheritedWidgetOfExactType; View.maybeOf
  // crosses a LookupBoundary through dependOnInheritedWidgetOfExactType.
  @override
  InheritedElement? getElementForInheritedWidgetOfExactType<T extends InheritedWidget>() => null;

  @override
  T? dependOnInheritedWidgetOfExactType<T extends InheritedWidget>({Object? aspect}) => null;
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
