import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  group("AppRoute", () {
    test("sessions round-trips the known worktree capability", () {
      const route = AppRoute.sessions(
        projectId: "project-1",
        projectName: "Project One",
        supportsDedicatedWorktrees: false,
      );

      final uri = Uri.parse(route.buildPath());
      final decoded =
          AppRoute.fromDef(
                def: AppRouteDef.sessions,
                pathParams: {"projectId": uri.pathSegments[1]},
                queryParams: uri.queryParameters,
              )
              as AppRouteSessions;

      expect(decoded.supportsDedicatedWorktrees, isFalse);
    });

    test("sessions keeps an omitted worktree capability unknown", () {
      final decoded =
          AppRoute.fromDef(
                def: AppRouteDef.sessions,
                pathParams: const {"projectId": "project-1"},
                queryParams: const {},
              )
              as AppRouteSessions;

      expect(decoded.supportsDedicatedWorktrees, isNull);
    });

    test("session detail with name encodes path params exactly once and round-trips", () {
      const route = AppRoute.sessionDetail(
        projectId: "project/with?special&chars",
        projectName: "Project / Name?",
        sessionId: "session/with?special&chars",
        sessionTitle: "Title / Name?",
        readOnly: false,
      );

      final path = route.buildPath();
      final uri = Uri.parse(path);
      final decoded = AppRoute.fromDef(
        def: AppRouteDef.sessionDetail,
        pathParams: {
          "projectId": uri.pathSegments[1],
          "sessionId": uri.pathSegments[3],
        },
        queryParams: uri.queryParameters,
      );

      expect(path, startsWith("/projects/project%2Fwith%3Fspecial%26chars/sessions/session%2Fwith%3Fspecial%26chars?"));
      expect(path, isNot(contains("%252F")));
      expect(decoded, isA<AppRouteSessionDetail>());
      final detail = decoded as AppRouteSessionDetail;
      expect(detail.projectId, "project/with?special&chars");
      expect(detail.projectName, "Project / Name?");
      expect(detail.sessionId, "session/with?special&chars");
      expect(detail.sessionTitle, "Title / Name?");
      expect(detail.readOnly, isFalse);
    });

    test("session diffs with name encodes path params exactly once and round-trips", () {
      const route = AppRoute.sessionDiffs(
        projectId: "project/with?special&chars",
        projectName: "Project / Name?",
        sessionId: "session/with?special&chars",
      );

      final path = route.buildPath();
      final uri = Uri.parse(path);
      final decoded = AppRoute.fromDef(
        def: AppRouteDef.sessionDiffs,
        pathParams: {
          "projectId": uri.pathSegments[1],
          "sessionId": uri.pathSegments[3],
        },
        queryParams: uri.queryParameters,
      );

      expect(
        path,
        startsWith("/projects/project%2Fwith%3Fspecial%26chars/sessions/session%2Fwith%3Fspecial%26chars/diffs?"),
      );
      expect(path, isNot(contains("%252F")));
      expect(decoded, isA<AppRouteSessionDiffs>());
      final diffs = decoded as AppRouteSessionDiffs;
      expect(diffs.projectId, "project/with?special&chars");
      expect(diffs.projectName, "Project / Name?");
      expect(diffs.sessionId, "session/with?special&chars");
    });
  });
}
