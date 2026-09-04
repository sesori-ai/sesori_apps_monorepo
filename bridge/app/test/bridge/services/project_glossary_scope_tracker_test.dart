import "package:sesori_bridge/src/auth/bridge_id_provider.dart";
import "package:sesori_bridge/src/services/project_glossary_scope_tracker.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  final projectKey = ProjectGlossaryKey.parse(
    value: "prj_v1_1yuLLmK3NKRJfpiX26q507WHb9ZxINRCpBKCBTgnGlQ",
  );

  test("records, reads, and removes scopes by normalized project path", () {
    final tracker = ProjectGlossaryScopeTracker(
      bridgeIdProvider: _FakeBridgeIdProvider(bridgeId: "br_bridge0001"),
    );
    final scope = ProjectGlossaryScope.repository(projectKey: projectKey);

    tracker.record(projectPath: "/tmp/projects/sesori/", scope: scope);

    expect(tracker.projectKeyFor(projectPath: "/tmp/projects/sesori"), projectKey);

    tracker.record(projectPath: "/tmp/projects/sesori", scope: null);

    expect(tracker.projectKeyFor(projectPath: "/tmp/projects/sesori/"), isNull);
  });

  test("invalidates a bridge-local scope when the registered bridge changes", () {
    final bridgeIdProvider = _FakeBridgeIdProvider(bridgeId: "br_bridge0001");
    final tracker = ProjectGlossaryScopeTracker(bridgeIdProvider: bridgeIdProvider);
    tracker.record(
      projectPath: "/tmp/projects/sesori",
      scope: ProjectGlossaryScope.bridgeLocal(
        projectKey: projectKey,
        bridgeId: "br_bridge0001",
      ),
    );

    expect(tracker.projectKeyFor(projectPath: "/tmp/projects/sesori"), projectKey);

    bridgeIdProvider.bridgeId = "br_bridge0002";

    expect(tracker.projectKeyFor(projectPath: "/tmp/projects/sesori"), isNull);
    bridgeIdProvider.bridgeId = "br_bridge0001";
    expect(tracker.projectKeyFor(projectPath: "/tmp/projects/sesori"), isNull);
  });

  test("retains repository scopes across bridge registration changes", () {
    final bridgeIdProvider = _FakeBridgeIdProvider(bridgeId: "br_bridge0001");
    final tracker = ProjectGlossaryScopeTracker(bridgeIdProvider: bridgeIdProvider);
    tracker.record(
      projectPath: "/tmp/projects/sesori",
      scope: ProjectGlossaryScope.repository(projectKey: projectKey),
    );

    bridgeIdProvider.bridgeId = "br_bridge0002";

    expect(tracker.projectKeyFor(projectPath: "/tmp/projects/sesori"), projectKey);
  });
}

class _FakeBridgeIdProvider({@override required var String? bridgeId}) implements BridgeIdProvider;
