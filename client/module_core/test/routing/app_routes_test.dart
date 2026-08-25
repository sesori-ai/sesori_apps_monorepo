import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  group("AppRoute", () {
    test("settings Harnesses route round-trips its presentation", () {
      for (final presentation in HarnessSettingsPresentation.values) {
        final route = AppRoute.settingsHarnesses(presentation: presentation);

        expect(route.buildPath(), "/settings/harnesses?presentation=${presentation.name}");
        expect(
          AppRoute.fromDef(
            def: AppRouteDef.settingsHarnesses,
            pathParams: const {},
            queryParams: {harnessSettingsPresentationQueryParam: presentation.name},
          ),
          isA<AppRouteSettingsHarnesses>().having(
            (route) => route.presentation,
            "presentation",
            presentation,
          ),
        );
      }
    });

    test("settings Harnesses route without a known presentation decodes as a modal", () {
      for (final queryParams in [
        const <String, String>{},
        const {harnessSettingsPresentationQueryParam: "sheet"},
      ]) {
        expect(
          AppRoute.fromDef(
            def: AppRouteDef.settingsHarnesses,
            pathParams: const {},
            queryParams: queryParams,
          ),
          isA<AppRouteSettingsHarnesses>().having(
            (route) => route.presentation,
            "presentation",
            HarnessSettingsPresentation.modal,
          ),
        );
      }
    });

    test("settings Harness management route is removed", () {
      expect(AppRouteDef.values.map((def) => def.name), isNot(contains("settingsHarnessManagement")));
      expect(AppRouteDef.values.map((def) => def.path), isNot(contains("/settings/harnesses/manage")));
    });

    test("sessions ignores legacy worktree capability query parameters", () {
      final decoded = AppRoute.fromDef(
        def: AppRouteDef.sessions,
        pathParams: const {"projectId": "project-1"},
        queryParams: const {"name": "Project One", "supportsDedicatedWorktrees": "false"},
      ) as AppRouteSessions;

      expect(decoded.projectId, "project-1");
      expect(decoded.projectName, "Project One");
      expect(decoded.buildPath(), "/projects/project-1/sessions?name=Project+One");
    });

    test("session detail with name encodes path params exactly once and round-trips", () {
      const route = AppRoute.sessionDetail(
        projectId: "project/with?special&chars",
        projectName: "Project / Name?",
        sessionId: "session/with?special&chars",
        sessionTitle: "Title / Name?",
        readOnly: false,
        bridgeId: "bridge/with?special&chars",
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
      expect(detail.bridgeId, "bridge/with?special&chars");
    });

    test("Device Canvas session route omits project identity and round-trips", () {
      const route = AppRoute.deviceCanvasSession(
        sessionId: "session/with?special&chars",
        bridgeId: "bridge/with?special&chars",
        readOnly: false,
      );

      final path = route.buildPath();
      final uri = Uri.parse(path);
      final decoded = AppRoute.fromDef(
        def: AppRouteDef.deviceCanvasSession,
        pathParams: {"sessionId": uri.pathSegments[1]},
        queryParams: uri.queryParameters,
      ) as AppRouteDeviceCanvasSession;

      expect(path, startsWith("/sessions/session%2Fwith%3Fspecial%26chars?"));
      expect(path, isNot(contains("project")));
      expect(path, isNot(contains("%252F")));
      expect(decoded.sessionId, "session/with?special&chars");
      expect(decoded.bridgeId, "bridge/with?special&chars");
      expect(decoded.readOnly, isFalse);
    });

    test("session detail editable matching preserves bridge scope", () {
      const unscoped = AppRouteSessionDetail(
        projectId: "project-1",
        projectName: null,
        sessionId: "session-1",
        sessionTitle: null,
        readOnly: false,
        bridgeId: null,
      );
      const scoped = AppRouteSessionDetail(
        projectId: "project-1",
        projectName: null,
        sessionId: "session-1",
        sessionTitle: null,
        readOnly: false,
        bridgeId: "bridge-1",
      );

      expect(unscoped.showsEditableLocation(location: Uri.parse(unscoped.buildPath())), isTrue);
      expect(scoped.showsEditableLocation(location: Uri.parse(scoped.buildPath())), isTrue);
      expect(unscoped.showsEditableLocation(location: Uri.parse(scoped.buildPath())), isFalse);
      expect(scoped.showsEditableLocation(location: Uri.parse(unscoped.buildPath())), isFalse);
    });

    test("session diffs with name encodes path params exactly once and round-trips", () {
      const route = AppRoute.sessionDiffs(
        projectId: "project/with?special&chars",
        projectName: "Project / Name?",
        sessionId: "session/with?special&chars",
        bridgeId: "bridge/with?special&chars",
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
      expect(diffs.bridgeId, "bridge/with?special&chars");
    });

    test("session diffs preserves unscoped navigation", () {
      const route = AppRoute.sessionDiffs(
        projectId: "project-1",
        projectName: null,
        sessionId: "session-1",
        bridgeId: null,
      );

      final uri = Uri.parse(route.buildPath());
      final decoded = AppRoute.fromDef(
        def: AppRouteDef.sessionDiffs,
        pathParams: const {"projectId": "project-1", "sessionId": "session-1"},
        queryParams: uri.queryParameters,
      ) as AppRouteSessionDiffs;

      expect(uri.queryParameters, isNot(contains(bridgeIdQueryParam)));
      expect(decoded.bridgeId, isNull);
    });
  });
}
