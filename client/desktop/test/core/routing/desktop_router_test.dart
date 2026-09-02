import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/routing/desktop_router.dart";
import "package:sesori_desktop/features/new_session/desktop_new_session_screen.dart";
import "package:sesori_desktop/features/session_diffs/desktop_session_diffs_screen.dart";
import "package:sesori_desktop/features/settings/desktop_harnesses_settings_screen.dart";

void main() {
  test("desktop registers typed new-session and diff routes", () {
    final paths = _shellRoutes().map((route) => route.path);

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

Iterable<GoRoute> _shellRoutes() {
  final shell = buildDesktopRoutes().single as ShellRoute;
  return shell.routes.whereType<GoRoute>();
}

GoRoute _routeWithPath(String path) => _shellRoutes().singleWhere((route) => route.path == path);

class _FakeBuildContext() extends Fake implements BuildContext;

class _FakeGoRouterState({
  @override final Map<String, String> pathParameters = const {},
  Map<String, String> queryParameters = const {},
}) extends Fake implements GoRouterState {
  @override
  final Uri uri = Uri(path: "/", queryParameters: queryParameters.isEmpty ? null : queryParameters);
}

// ignore_for_file: avoid_implementing_value_types, tests use lightweight framework fakes
