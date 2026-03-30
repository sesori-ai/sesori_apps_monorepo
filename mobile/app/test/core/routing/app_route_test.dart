import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "package:sesori_mobile/core/routing/app_router.dart";
import "package:sesori_mobile/features/login/login_screen.dart";
import "package:sesori_mobile/features/project_list/project_list_screen.dart";
import "package:sesori_mobile/features/session_detail/session_detail_screen.dart";
import "package:sesori_mobile/features/session_list/session_list_screen.dart";

void main() {
  group("AppRoute", () {
    test("each value has a non-empty path starting with /", () {
      for (final route in AppRoute.values) {
        expect(route.path, isNotEmpty, reason: "${route.runtimeType} should have a path");
        expect(route.path.startsWith("/"), isTrue, reason: "${route.runtimeType} path should start with /");
      }
    });
  });

  group("AppRoute.buildPath", () {
    test("returns raw path for parameterless routes", () {
      expect(const AppRoute.login().buildPath(), "/login");
      expect(const AppRoute.projects().buildPath(), "/projects");
      expect(const AppRoute.notificationSettings().buildPath(), "/settings/notifications");
    });

    test("substitutes projectId for sessions", () {
      final result = const AppRoute.sessions(projectId: "proj-123").buildPath();
      expect(result, "/projects/proj-123/sessions");
    });

    test("substitutes path params for sessionDetail", () {
      final result = const AppRoute.sessionDetail(
        projectId: "proj-123",
        sessionId: "ses-456",
      ).buildPath();
      expect(result, "/projects/proj-123/sessions/ses-456");
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
      final result = const AppRoute.sessions(projectId: "proj-123").buildPath();
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
      // Verify values are encoded (& becomes %26)
      expect(result, isNot(contains("& more")));
      expect(result, contains("readOnly=true"));
    });

    test("omits readOnly from query when false", () {
      final result = const AppRoute.sessionDetail(
        projectId: "proj-1",
        sessionId: "ses-1",
      ).buildPath();
      expect(result, "/projects/proj-1/sessions/ses-1");
      expect(result, isNot(contains("readOnly")));
    });

    test("encodes path params with special characters", () {
      final result = const AppRoute.sessionDetail(
        projectId: "project/with?special&chars",
        sessionId: "id/with?special&chars",
      ).buildPath();
      // Special characters in the param value must be percent-encoded
      expect(
        result,
        "/projects/project%2Fwith%3Fspecial%26chars/sessions/id%2Fwith%3Fspecial%26chars",
      );
    });

    test("substitutes projectId for newSession", () {
      final result = const AppRoute.newSession(projectId: "proj-42").buildPath();
      expect(result, "/projects/proj-42/sessions/new");
    });
  });

  group("AppRoute.toGoRoute", () {
    test("returns GoRoute with matching path for every route", () {
      for (final route in AppRoute.values) {
        final goRoute = route.toGoRoute();
        expect(goRoute.path, route.path, reason: "${route.runtimeType} GoRoute path should match");
      }
    });

    test("login route builds LoginScreen", () {
      final goRoute = const AppRoute.login().toGoRoute();
      final widget = goRoute.builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(),
      );
      expect(widget, isA<LoginScreen>());
    });

    test("projects route builds ProjectListScreen", () {
      final goRoute = const AppRoute.projects().toGoRoute();
      final widget = goRoute.builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(),
      );
      expect(widget, isA<ProjectListScreen>());
    });

    test("sessions route builds SessionListScreen with path and query params", () {
      final goRoute = const AppRoute.sessions(projectId: "").toGoRoute();
      final widget = goRoute.builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(
          pathParameters: {"projectId": "proj-42"},
          queryParameters: {"name": "My App"},
        ),
      );
      expect(widget, isA<SessionListScreen>());
      final screen = widget as SessionListScreen;
      expect(screen.projectId, "proj-42");
      expect(screen.projectName, "My App");
    });

    test("sessions route defaults missing params to empty strings", () {
      final goRoute = const AppRoute.sessions(projectId: "").toGoRoute();
      final widget = goRoute.builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(),
      );
      final screen = widget as SessionListScreen;
      expect(screen.projectId, "");
      expect(screen.projectName, isNull);
    });

    test("sessionDetail route builds SessionDetailScreen with params", () {
      final goRoute = const AppRoute.sessionDetail(projectId: "", sessionId: "").toGoRoute();
      final widget = goRoute.builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(
          pathParameters: {"projectId": "proj-42", "sessionId": "ses-99"},
          queryParameters: {"title": "Debug session", "readOnly": "true"},
        ),
      );
      expect(widget, isA<SessionDetailScreen>());
      final screen = widget as SessionDetailScreen;
      expect(screen.projectId, "proj-42");
      expect(screen.sessionId, "ses-99");
      expect(screen.sessionTitle, "Debug session");
      expect(screen.readOnly, isTrue);
    });

    test("sessionDetail route defaults readOnly to false when absent", () {
      final goRoute = const AppRoute.sessionDetail(projectId: "", sessionId: "").toGoRoute();
      final widget = goRoute.builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(
          pathParameters: {"projectId": "proj-1", "sessionId": "ses-1"},
        ),
      );
      final screen = widget as SessionDetailScreen;
      expect(screen.projectId, "proj-1");
      expect(screen.sessionId, "ses-1");
      expect(screen.sessionTitle, isNull);
      expect(screen.readOnly, isFalse);
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

class _FakeBuildContext extends Fake implements BuildContext {}

// ignore: avoid_implementing_value_types
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
