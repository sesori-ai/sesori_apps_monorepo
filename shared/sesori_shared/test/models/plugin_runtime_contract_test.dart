import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("plugin discovery round-trips ordered metadata", () {
    const response = PluginListResponse(
      bridgeId: "br_abc12345",
      plugins: [
        PluginMetadata(
          id: "codex",
          displayName: "Codex",
          brandLogoKey: "codex",
          isDefault: true,
          state: PluginLifecycleState.degraded,
          actionHint: "Check the bridge console if this plugin needs attention.",
        ),
        PluginMetadata(
          id: "opencode",
          displayName: "OpenCode",
          brandLogoKey: null,
          isDefault: false,
          state: PluginLifecycleState.ready,
          actionHint: null,
        ),
      ],
    );

    expect(PluginListResponse.fromJson(response.toJson()), response);
    expect(response.toJson()["bridgeId"], "br_abc12345");
    expect(response.toJson()["plugins"], hasLength(2));
    expect((response.toJson()["plugins"]! as List<Object?>).first, containsPair("brandLogoKey", "codex"));
    expect((response.toJson()["plugins"]! as List<Object?>).last, isNot(contains("brandLogoKey")));
  });

  test("plugin discovery omits a null bridge ID and decodes a missing one as null", () {
    const response = PluginListResponse(bridgeId: null, plugins: []);

    final json = response.toJson();

    expect(json, isNot(contains("bridgeId")));
    expect(PluginListResponse.fromJson(json).bridgeId, isNull);
  });

  test("plugin discovery maps a future lifecycle state to unavailable", () {
    final metadata = PluginMetadata.fromJson(const {
      "id": "future-plugin",
      "displayName": "Future Plugin",
      "isDefault": false,
      "state": "starting_up",
    });

    expect(metadata.state, PluginLifecycleState.unavailable);
    expect(metadata.brandLogoKey, isNull);
  });

  test("plugin setup round-trips ordered generic metadata and maps future states to unknown", () {
    const response = PluginSetupResponse(
      plugins: [
        PluginSetupMetadata(
          id: "codex",
          displayName: "Codex",
          brandLogoKey: "codex",
          state: PluginSetupState.authenticationRequired,
          actionHint: "Run codex login on this machine.",
        ),
        PluginSetupMetadata(
          id: "opencode",
          displayName: "OpenCode",
          brandLogoKey: null,
          state: PluginSetupState.ready,
          actionHint: null,
        ),
      ],
    );

    expect(PluginSetupResponse.fromJson(response.toJson()), response);
    final setupJson = response.toJson()["plugins"]! as List<Object?>;
    expect(setupJson.first, containsPair("brandLogoKey", "codex"));
    expect(setupJson.last, isNot(contains("brandLogoKey")));
    expect(
      PluginSetupMetadata.fromJson(const {
        "id": "future",
        "displayName": "Future",
        "state": "partially_ready",
      }).state,
      PluginSetupState.unknown,
    );
    expect(
      PluginSetupMetadata.fromJson(const {
        "id": "legacy",
        "displayName": "Legacy",
        "state": "ready",
      }).brandLogoKey,
      isNull,
    );
  });

  test("bridge health remains plugin-neutral", () {
    const response = HealthResponse(
      healthy: true,
      version: "1.5.1",
      filesystemAccessDegraded: false,
    );

    expect(HealthResponse.fromJson(response.toJson()), response);
    expect(response.toJson(), isNot(contains("plugins")));
  });

  test("statuses round-trip unavailable sources and decode the legacy default", () {
    const response = SessionStatusResponse(
      statuses: {"session": SessionStatus.busy()},
      unavailablePluginIds: ["cursor"],
    );

    expect(SessionStatusResponse.fromJson(response.toJson()), response);
    expect(SessionStatusResponse.fromJson(const {"statuses": <String, Object?>{}}).unavailablePluginIds, isEmpty);
  });
}
