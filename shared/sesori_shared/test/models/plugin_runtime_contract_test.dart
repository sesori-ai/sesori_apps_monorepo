import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("plugin discovery round-trips ordered metadata", () {
    const response = PluginListResponse(
      plugins: [
        PluginMetadata(
          id: "codex",
          displayName: "Codex",
          isDefault: true,
          state: PluginLifecycleState.degraded,
          actionHint: "Check the bridge console if this plugin needs attention.",
        ),
        PluginMetadata(
          id: "opencode",
          displayName: "OpenCode",
          isDefault: false,
          state: PluginLifecycleState.ready,
          actionHint: null,
        ),
      ],
    );

    expect(PluginListResponse.fromJson(response.toJson()), response);
    expect(response.toJson()["plugins"], hasLength(2));
  });

  test("plugin discovery maps a future lifecycle state to unavailable", () {
    final metadata = PluginMetadata.fromJson(const {
      "id": "future-plugin",
      "displayName": "Future Plugin",
      "isDefault": false,
      "state": "starting_up",
    });

    expect(metadata.state, PluginLifecycleState.unavailable);
  });

  test("plugin setup round-trips ordered generic metadata and maps future states to unknown", () {
    const response = PluginSetupResponse(
      plugins: [
        PluginSetupMetadata(
          id: "codex",
          displayName: "Codex",
          state: PluginSetupState.authenticationRequired,
          actionHint: "Run codex login on this machine.",
        ),
        PluginSetupMetadata(
          id: "opencode",
          displayName: "OpenCode",
          state: PluginSetupState.ready,
          actionHint: null,
        ),
      ],
    );

    expect(PluginSetupResponse.fromJson(response.toJson()), response);
    expect(
      PluginSetupMetadata.fromJson(const {
        "id": "future",
        "displayName": "Future",
        "state": "partially_ready",
      }).state,
      PluginSetupState.unknown,
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
