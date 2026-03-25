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
        expect(route.path, isNotEmpty, reason: "${route.name} should have a path");
        expect(route.path.startsWith("/"), isTrue, reason: "${route.name} path should start with /");
      }
    });
  });

  group("AppRoute.buildPath", () {
    test("returns raw path when no params given", () {
      expect(AppRoute.login.buildPath(), "/login");
      expect(AppRoute.projects.buildPath(), "/projects");
    });

    test("substitutes path params", () {
      final result = AppRoute.sessions.buildPath(
        pathParams: {"projectId": "proj-123"},
      );
      expect(result, "/projects/proj-123/sessions");
    });

    test("substitutes path params for sessionDetail", () {
      final result = AppRoute.sessionDetail.buildPath(
        pathParams: {"projectId": "proj-123", "sessionId": "ses-456"},
      );
      expect(result, "/projects/proj-123/sessions/ses-456");
    });

    test("builds /projects/p1/sessions/s1 for sessionDetail", () {
      final result = AppRoute.sessionDetail.buildPath(
        pathParams: {"projectId": "p1", "sessionId": "s1"},
      );
      expect(result, "/projects/p1/sessions/s1");
    });

    test("appends query params", () {
      final result = AppRoute.projects.buildPath(
        queryParams: {"filter": "active"},
      );
      expect(result, "/projects?filter=active");
    });

    test("combines path and query params", () {
      final result = AppRoute.sessions.buildPath(
        pathParams: {"projectId": "proj-123"},
        queryParams: {"name": "My Project"},
      );
      expect(result, contains("/projects/proj-123/sessions?"));
      expect(result, contains("name=My+Project"));
    });

    test("encodes query param values automatically", () {
      final result = AppRoute.sessionDetail.buildPath(
        pathParams: {"projectId": "proj-1", "sessionId": "ses-1"},
        queryParams: {"title": "hello world & more"},
      );
      expect(result, contains("/projects/proj-1/sessions/ses-1?"));
      // Verify the value is encoded (space becomes + or %20, & becomes %26)
      expect(result, isNot(contains("& more")));
    });

    test("encodes sessionDetail path params with special characters", () {
      final result = AppRoute.sessionDetail.buildPath(
        pathParams: {
          "projectId": "project/with?special&chars",
          "sessionId": "id/with?special&chars",
        },
      );
      // Special characters in the param value must be percent-encoded
      expect(
        result,
        "/projects/project%2Fwith%3Fspecial%26chars/sessions/id%2Fwith%3Fspecial%26chars",
      );
    });

    test("ignores empty query params map", () {
      final result = AppRoute.login.buildPath(queryParams: {});
      expect(result, "/login");
    });

    test("ignores null params", () {
      final result = AppRoute.login.buildPath(
        pathParams: null,
        queryParams: null,
      );
      expect(result, "/login");
    });
  });

  group("AppRoute.toGoRoute", () {
    test("returns GoRoute with matching path for every route", () {
      for (final route in AppRoute.values) {
        final goRoute = route.toGoRoute();
        expect(goRoute.path, route.path, reason: "${route.name} GoRoute path should match enum path");
      }
    });

    test("login route builds LoginScreen", () {
      final goRoute = AppRoute.login.toGoRoute();
      final widget = goRoute.builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(),
      );
      expect(widget, isA<LoginScreen>());
    });

    test("projects route builds ProjectListScreen", () {
      final goRoute = AppRoute.projects.toGoRoute();
      final widget = goRoute.builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(),
      );
      expect(widget, isA<ProjectListScreen>());
    });

    test("sessions route builds SessionListScreen with path and query params", () {
      final goRoute = AppRoute.sessions.toGoRoute();
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
      final goRoute = AppRoute.sessions.toGoRoute();
      final widget = goRoute.builder!(
        _FakeBuildContext(),
        _FakeGoRouterState(),
      );
      final screen = widget as SessionListScreen;
      expect(screen.projectId, "");
      expect(screen.projectName, isNull);
    });

    test("sessionDetail route builds SessionDetailScreen with params", () {
      final goRoute = AppRoute.sessionDetail.toGoRoute();
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
      final goRoute = AppRoute.sessionDetail.toGoRoute();
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
