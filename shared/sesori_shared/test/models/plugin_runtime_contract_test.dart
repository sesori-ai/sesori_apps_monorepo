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

  test("health round-trips per-plugin state and decodes the legacy default", () {
    const response = HealthResponse(
      healthy: true,
      version: "1.5.1",
      filesystemAccessDegraded: false,
      plugins: [PluginHealth(pluginId: "opencode", healthy: true)],
    );

    expect(HealthResponse.fromJson(response.toJson()), response);
    expect(
      HealthResponse.fromJson({
        "healthy": true,
        "version": "1.5.0",
        "filesystemAccessDegraded": false,
      }).plugins,
      isEmpty,
    );
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
