import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/routing/desktop_router.dart";
import "package:sesori_desktop/features/new_session/desktop_new_session_screen.dart";
import "package:sesori_desktop/features/session_diffs/desktop_session_diffs_screen.dart";
import "package:sesori_desktop/features/settings/desktop_harnesses_settings_screen.dart";

void main() {
  test("settings destination matching includes its child routes", () {
    expect(isDesktopSettingsPath(path: AppRouteDef.settings.path), isTrue);
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

    expect(widget, isA<DesktopHarnessesSettingsScreen>());
    final screen = widget as DesktopHarnessesSettingsScreen;
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

// ignore_for_file: avoid_implementing_value_types, tests use lightweight framework fakes
