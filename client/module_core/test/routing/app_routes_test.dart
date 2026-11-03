import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  group("AppRoute", () {
    test("archived detail decoding requires project and session identity", () {
      expect(
        () => AppRoute.fromDef(
          def: AppRouteDef.archivedSessionDetail,
          pathParams: const {projectIdPathParam: "p1"},
          queryParams: const {},
        ),
        throwsArgumentError,
      );
    });

    test("archived detail round-trips encoded identity and never carries editable intent", () {
      const route = AppRoute.archivedSessionDetail(
        projectId: "project/1",
        projectName: "A & B",
        sessionId: "session/2",
        sessionTitle: "Audit ?",
      );
      final uri = Uri.parse(route.buildPath());
      expect(uri.pathSegments.first, "archived-sessions");
      final decoded = AppRoute.fromDef(
        def: route.def,
        pathParams: {projectIdPathParam: uri.pathSegments[1], sessionIdPathParam: uri.pathSegments[2]},
        queryParams: uri.queryParameters,
      );
      expect(decoded.buildPath(), route.buildPath());
      expect(uri.queryParameters.containsKey("readOnly"), isFalse);
    });

    test("Default input round-trips a parameterless settings route with a pinned screen name", () {
      const route = AppRoute.settingsDefaultInput();
      expect(route.buildPath(), "/settings/default-input");
      expect(
        AppRoute.fromDef(def: route.def, pathParams: const {}, queryParams: const {}),
        isA<AppRouteSettingsDefaultInput>(),
      );
      expect(AnalyticsScreen.settingsDefaultInput.wireValue, "settings_default_input");
    });

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

    test("harness detail encodes identity once and defaults presentation at the boundary", () {
      const id = "harness/with ? & symbols";
      for (final presentation in HarnessSettingsPresentation.values) {
        final uri = Uri.parse(AppRoute.settingsHarnessDetail(pluginId: id, presentation: presentation).buildPath());
        final decoded = AppRoute.fromDef(
          def: AppRouteDef.settingsHarnessDetail,
          pathParams: {pluginIdPathParam: uri.pathSegments.last},
          queryParams: uri.queryParameters,
        ) as AppRouteSettingsHarnessDetail;
        expect(decoded.pluginId, id);
        expect(decoded.presentation, presentation);
      }
      expect(
        AppRouteSettingsHarnessDetail.fromParams(
          pathParams: const {pluginIdPathParam: id},
          queryParams: const {},
        ).presentation,
        HarnessSettingsPresentation.modal,
      );
    });

    test("settings Harness management route is removed", () {
      expect(AppRouteDef.values.map((def) => def.name), isNot(contains("settingsHarnessManagement")));
      expect(AppRouteDef.values.map((def) => def.path), isNot(contains("/settings/harnesses/manage")));
    });

    test("the home and its new session sit under /sessions, the project optional", () {
      expect(const AppRoute.home().buildPath(), "/sessions");
      expect(
        const AppRoute.newSession(
          projectId: null,
          projectName: null,
          entry: NewSessionEntry.platform(),
        ).buildPath(),
        "/sessions/new",
      );

      const chosen = AppRoute.newSession(
        projectId: "project/1",
        projectName: "One",
        entry: NewSessionEntry.platform(),
      );
      final uri = Uri.parse(chosen.buildPath());
      expect(uri.path, "/sessions/new");
      final decoded = AppRoute.fromDef(
        def: AppRouteDef.newSession,
        pathParams: const {},
        queryParams: uri.queryParameters,
      ) as AppRouteNewSession;
      expect((decoded.projectId, decoded.projectName), ("project/1", "One"));
      expect(decoded.entry, isA<NewSessionPlatformEntry>());

      final unchosen = AppRoute.fromDef(
        def: AppRouteDef.newSession,
        pathParams: const {},
        queryParams: const {},
      ) as AppRouteNewSession;
      expect((unchosen.projectId, unchosen.projectName), (null, null));
      expect(unchosen.entry, isA<NewSessionPlatformEntry>());
    });

    test("a new session revealed from the + carries its origin through the URL", () {
      const revealed = AppRoute.newSession(
        projectId: "p1",
        projectName: null,
        entry: NewSessionEntry.reveal(x: 0.875, y: 0.9),
      );
      final uri = Uri.parse(revealed.buildPath());
      expect(uri.queryParameters, {"project": "p1", "reveal": "0.8750,0.9000"});
      final decoded = AppRouteNewSession.fromParams(queryParams: uri.queryParameters);
      expect(decoded.entry, isA<NewSessionRevealEntry>().having((entry) => (entry.x, entry.y), "origin", (0.875, 0.9)));

      // A malformed or off-screen origin opens the page as any other entry does.
      for (final malformed in ["", "0.5", "a,b", "0.5,1.5", "-0.1,0.5", "NaN,0.5", "0.1,0.2,0.3"]) {
        expect(
          AppRouteNewSession.fromParams(queryParams: {"reveal": malformed}).entry,
          isA<NewSessionPlatformEntry>(),
          reason: malformed,
        );
      }
    });

    test("session detail with name encodes path params exactly once and round-trips", () {
      const route = AppRoute.sessionDetail(
        projectId: "project/with?special&chars",
        projectName: "Project / Name?",
        sessionId: "session/with?special&chars",
        sessionTitle: "Title / Name?",
        readOnly: false,
        fromLaunch: false,
      );

      final path = route.buildPath();
      final uri = Uri.parse(path);
      final decoded = AppRoute.fromDef(
        def: AppRouteDef.sessionDetail,
        pathParams: {
          "projectId": uri.pathSegments[1],
          "sessionId": uri.pathSegments[2],
        },
        queryParams: uri.queryParameters,
      );

      expect(path, startsWith("/sessions/project%2Fwith%3Fspecial%26chars/session%2Fwith%3Fspecial%26chars?"));
      expect(path, isNot(contains("%252F")));
      expect(decoded, isA<AppRouteSessionDetail>());
      final detail = decoded as AppRouteSessionDetail;
      expect(detail.projectId, "project/with?special&chars");
      expect(detail.projectName, "Project / Name?");
      expect(detail.sessionId, "session/with?special&chars");
      expect(detail.sessionTitle, "Title / Name?");
      expect(detail.readOnly, isFalse);
    });

    test("session detail carries the launch marker only when set", () {
      AppRouteSessionDetail roundTrip({required bool fromLaunch}) {
        final uri = Uri.parse(
          AppRoute.sessionDetail(
            projectId: "p1",
            projectName: null,
            sessionId: "s1",
            sessionTitle: null,
            readOnly: false,
            fromLaunch: fromLaunch,
          ).buildPath(),
        );
        return AppRoute.fromDef(
          def: AppRouteDef.sessionDetail,
          pathParams: {"projectId": uri.pathSegments[1], "sessionId": uri.pathSegments[2]},
          queryParams: uri.queryParameters,
        ) as AppRouteSessionDetail;
      }

      expect(roundTrip(fromLaunch: true).fromLaunch, isTrue);
      expect(roundTrip(fromLaunch: false).fromLaunch, isFalse);
      expect(
        const AppRoute.sessionDetail(
          projectId: "p1",
          projectName: null,
          sessionId: "s1",
          sessionTitle: null,
          readOnly: false,
          fromLaunch: false,
        ).buildPath(),
        isNot(contains("fromLaunch")),
      );
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
          "sessionId": uri.pathSegments[2],
        },
        queryParams: uri.queryParameters,
      );

      expect(
        path,
        startsWith("/sessions/project%2Fwith%3Fspecial%26chars/session%2Fwith%3Fspecial%26chars/diffs?"),
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
