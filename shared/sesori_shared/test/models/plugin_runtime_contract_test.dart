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
          isDefault: true,
          state: PluginLifecycleState.degraded,
          actionHint: "Check the bridge console if this plugin needs attention.",
          supportsPromptAttachments: true,
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
    expect(response.toJson()["bridgeId"], "br_abc12345");
    expect(response.toJson()["plugins"], hasLength(2));
  });

  test("plugin metadata defaults omitted prompt attachment support to false", () {
    final metadata = PluginMetadata.fromJson(const {
      "id": "legacy",
      "displayName": "Legacy",
      "isDefault": true,
      "state": "ready",
    });

    expect(metadata.supportsPromptAttachments, isFalse);
  });

  test("plugin discovery omits a null bridge ID and decodes a missing one as null", () {
    const response = PluginListResponse(bridgeId: null, plugins: []);

    final json = response.toJson();

    expect(json, isNot(contains("bridgeId")));
    expect(PluginListResponse.fromJson(json).bridgeId, isNull);
  });

  test("plugin discovery defaults an omitted session-options capability to false", () {
    final response = PluginListResponse.fromJson(const {
      "plugins": <Object>[],
      "bridgeId": null,
    });

    expect(response.supportsSessionOptions, isFalse);
  });

  test("plugin discovery preserves an explicit false session-options capability", () {
    final response = PluginListResponse.fromJson(const {
      "plugins": <Object>[],
      "bridgeId": null,
      "supportsSessionOptions": false,
    });

    expect(response.supportsSessionOptions, isFalse);
  });

  test("plugin discovery preserves an explicit true session-options capability", () {
    final response = PluginListResponse.fromJson(const {
      "plugins": <Object>[],
      "bridgeId": null,
      "supportsSessionOptions": true,
    });

    expect(response.supportsSessionOptions, isTrue);
    expect(response.toJson()["supportsSessionOptions"], isTrue);
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
          runtimeVersion: "0.42.0",
          actionHint: "Run codex login on this machine.",
        ),
        PluginSetupMetadata(
          id: "opencode",
          displayName: "OpenCode",
          state: PluginSetupState.ready,
          runtimeVersion: "1.18.11",
          actionHint: null,
        ),
      ],
    );

    expect(PluginSetupResponse.fromJson(response.toJson()), response);
    final oldPayload = response.toJson();
    ((oldPayload["plugins"] as List<Object?>).first! as Map<String, dynamic>).remove("runtimeVersion");
    expect(PluginSetupResponse.fromJson(oldPayload).plugins.first.runtimeVersion, isNull);
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
