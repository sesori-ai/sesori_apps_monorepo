import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const plugin = PluginManagementMetadata(
    setup: PluginSetupMetadata(
      id: "opencode",
      displayName: "OpenCode",
      state: PluginSetupState.ready,
      actionHint: null,
    ),
    runtimeState: PluginRuntimeState.active,
    workState: PluginManagementWorkState.idle,
    idleTimeoutMins: 0,
    hasIdleTimeoutOverride: true,
    managementCapabilities: {
      PluginManagementCapability.lifecycle,
      PluginManagementCapability.setupRefresh,
      PluginManagementCapability.idleTimeout,
    },
    actionHint: null,
  );

  test("management response round-trips only read snapshot fields", () {
    const response = PluginManagementResponse(
      snapshotToken: "snapshot-token",
      bridgeId: "br_abc12345",
      defaultPluginId: "opencode",
      defaultIdleTimeoutMins: 30,
      plugins: [plugin],
    );

    final json = response.toJson();
    final plugins = json["plugins"] as List<Object?>?;
    final pluginJson = plugins!.single! as Map<String, dynamic>;

    expect(PluginManagementResponse.fromJson(json), response);
    expect(
      json.keys,
      unorderedEquals(["snapshotToken", "bridgeId", "defaultPluginId", "defaultIdleTimeoutMins", "plugins"]),
    );
    expect(
      pluginJson.keys,
      unorderedEquals([
        "setup",
        "runtimeState",
        "workState",
        "idleTimeoutMins",
        "hasIdleTimeoutOverride",
        "managementCapabilities",
      ]),
    );
    expect(json["snapshotToken"], "snapshot-token");
    expect(json["bridgeId"], "br_abc12345");
    expect(pluginJson, isNot(contains("enabled")));
    expect(pluginJson, isNot(contains("isDefault")));
    expect(json, isNot(contains("authority")));
    expect(json, isNot(contains("order")));
  });

  test("declared management capabilities round-trip", () {
    final json = plugin.toJson();

    expect(
      json["managementCapabilities"],
      unorderedEquals(["lifecycle", "setupRefresh", "idleTimeout"]),
    );
    expect(
      PluginManagementMetadata.fromJson(json).managementCapabilities,
      plugin.managementCapabilities,
    );
  });

  test("management capabilities are required", () {
    final json = plugin.toJson()..remove("managementCapabilities");

    expect(
      () => PluginManagementMetadata.fromJson(json),
      throwsA(anything),
    );
  });

  test("future management capabilities decode to unknown", () {
    final json = plugin.toJson()..["managementCapabilities"] = ["lifecycle", "futureCapability"];

    expect(
      PluginManagementMetadata.fromJson(json).managementCapabilities,
      {PluginManagementCapability.lifecycle, PluginManagementCapability.unknown},
    );
  });

  test("older management responses decode without a snapshot token", () {
    final json = const PluginManagementResponse(
      snapshotToken: null,
      bridgeId: null,
      defaultPluginId: "opencode",
      defaultIdleTimeoutMins: 30,
      plugins: [plugin],
    ).toJson()..remove("snapshotToken");

    expect(PluginManagementResponse.fromJson(json).snapshotToken, isNull);
  });

  test("management response omits a null bridge ID and decodes a missing one as null", () {
    final json = const PluginManagementResponse(
      snapshotToken: "snapshot-token",
      bridgeId: null,
      defaultPluginId: "opencode",
      defaultIdleTimeoutMins: 30,
      plugins: [plugin],
    ).toJson();

    expect(json, isNot(contains("bridgeId")));
    expect(PluginManagementResponse.fromJson(json).bridgeId, isNull);
  });

  test("future runtime and work states decode to fail-closed unknown values", () {
    final json = plugin.toJson()
      ..["runtimeState"] = "futureRuntime"
      ..["workState"] = "futureWork";

    final decoded = PluginManagementMetadata.fromJson(json);

    expect(decoded.runtimeState, PluginRuntimeState.unknown);
    expect(decoded.workState, PluginManagementWorkState.unknown);
    expect(decoded.runtimeState.isEnabled, isFalse);
    expect(decoded.runtimeState.isRoutable, isFalse);
  });

  test("runtime helpers derive enabled and routable state without wire fields", () {
    expect(PluginRuntimeState.disabled.isEnabled, isFalse);
    expect(PluginRuntimeState.blocked.isEnabled, isTrue);
    expect(PluginRuntimeState.failed.isEnabled, isTrue);
    expect(PluginRuntimeState.dormant.isRoutable, isTrue);
    expect(PluginRuntimeState.starting.isRoutable, isTrue);
    expect(PluginRuntimeState.active.isRoutable, isTrue);
    expect(PluginRuntimeState.degraded.isRoutable, isTrue);
    expect(PluginRuntimeState.blocked.isRoutable, isFalse);
    expect(PluginRuntimeState.stopping.isRoutable, isFalse);
    expect(PluginRuntimeState.failed.isRoutable, isFalse);
  });

  test("idle timeout update variants round-trip", () {
    const requests = <PluginIdleTimeoutUpdateRequest>[
      PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 30),
      PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "opencode", idleTimeoutMins: -1),
      PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "opencode"),
    ];

    for (final request in requests) {
      expect(PluginIdleTimeoutUpdateRequest.fromJson(request.toJson()), request);
    }
  });

  test("idle timeout updates reject fractional timeout fields", () {
    for (final json in const [
      <String, dynamic>{"type": "applyAll", "idleTimeoutMins": 1.5},
      <String, dynamic>{"type": "setOverride", "pluginId": "opencode", "idleTimeoutMins": -2.5},
    ]) {
      expect(
        () => PluginIdleTimeoutUpdateRequest.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test("lifecycle command variants and conflicts round-trip", () {
    const requests = <PluginLifecycleCommandRequest>[
      PluginLifecycleCommandRequest.enable(),
      PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
      PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
      PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe),
      PluginLifecycleCommandRequest.restart(mode: PluginStopMode.force),
      PluginLifecycleCommandRequest.refresh(),
    ];
    const expectedJson = <Map<String, dynamic>>[
      {"type": "enable"},
      {"type": "disable", "mode": "safe"},
      {"type": "disable", "mode": "force"},
      {"type": "restart", "mode": "safe"},
      {"type": "restart", "mode": "force"},
      {"type": "refresh"},
    ];
    for (final (index, request) in requests.indexed) {
      final json = request.toJson();
      expect(json, expectedJson[index]);
      expect(PluginLifecycleCommandRequest.fromJson(json), request);
    }

    const conflict = PluginLifecycleConflict(
      pluginId: "opencode",
      reasons: [PluginLifecycleConflictReason.unsupported],
      current: plugin,
    );
    expect(conflict.toJson()["reasons"], ["unsupported"]);
    expect(PluginLifecycleConflict.fromJson(conflict.toJson()), conflict);
  });

  test("commands require an exact type and stop mode while future conflicts fail closed", () {
    for (final json in const [
      <String, dynamic>{"mode": "safe"},
      <String, dynamic>{"type": "future", "mode": "safe"},
      <String, dynamic>{"type": "disable"},
      <String, dynamic>{"type": "restart"},
    ]) {
      expect(
        () => PluginLifecycleCommandRequest.fromJson(json),
        throwsA(anything),
      );
    }
    final json = const PluginLifecycleConflict(
      pluginId: "opencode",
      reasons: [PluginLifecycleConflictReason.busy],
      current: plugin,
    ).toJson()..["reasons"] = ["futureReason"];

    expect(
      PluginLifecycleConflict.fromJson(json).reasons,
      [PluginLifecycleConflictReason.unknown],
    );
  });
}
