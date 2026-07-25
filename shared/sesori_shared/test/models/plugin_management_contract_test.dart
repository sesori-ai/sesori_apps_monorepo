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
    actionHint: null,
  );

  test("management response round-trips only read snapshot fields", () {
    const response = PluginManagementResponse(
      revision: 7,
      defaultPluginId: "opencode",
      defaultIdleTimeoutMins: 30,
      plugins: [plugin],
    );

    final json = response.toJson();
    final plugins = json["plugins"] as List<Object?>?;
    final pluginJson = plugins!.single! as Map<String, dynamic>;

    expect(PluginManagementResponse.fromJson(json), response);
    expect(json.keys, unorderedEquals(["revision", "defaultPluginId", "defaultIdleTimeoutMins", "plugins"]));
    expect(
      pluginJson.keys,
      unorderedEquals(["setup", "runtimeState", "workState", "idleTimeoutMins", "hasIdleTimeoutOverride"]),
    );
    expect(json["revision"], 7);
    expect(pluginJson, isNot(contains("enabled")));
    expect(pluginJson, isNot(contains("isDefault")));
    expect(json, isNot(contains("authority")));
    expect(json, isNot(contains("order")));
  });

  test("older management responses default to the initial process revision", () {
    final json = const PluginManagementResponse(
      defaultPluginId: "opencode",
      defaultIdleTimeoutMins: 30,
      plugins: [plugin],
    ).toJson()..remove("revision");

    expect(PluginManagementResponse.fromJson(json).revision, 0);
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
}
