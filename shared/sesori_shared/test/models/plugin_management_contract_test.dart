import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const codex = PluginManagementMetadata(
    setup: PluginSetupMetadata(
      id: "codex",
      displayName: "Codex",
      state: PluginSetupState.ready,
      actionHint: null,
    ),
    runtimeState: PluginRuntimeState.active,
    workState: PluginManagementWorkState.idle,
    idleTimeoutMins: 30,
    hasIdleTimeoutOverride: false,
    actionHint: null,
  );
  const opencode = PluginManagementMetadata(
    setup: PluginSetupMetadata(
      id: "opencode",
      displayName: "OpenCode",
      state: PluginSetupState.authenticationRequired,
      actionHint: "Authenticate OpenCode on this machine.",
    ),
    runtimeState: PluginRuntimeState.blocked,
    workState: PluginManagementWorkState.unknown,
    idleTimeoutMins: 0,
    hasIdleTimeoutOverride: true,
    actionHint: "Resolve setup before enabling sessions.",
  );

  test("management response round-trips only the redesigned wire fields", () {
    const response = PluginManagementResponse(
      revision: 7,
      defaultPluginId: "codex",
      defaultIdleTimeoutMins: 30,
      plugins: [codex, opencode],
    );

    final json = response.toJson();
    final pluginJson = (json["plugins"] as List<Object?>).cast<Map<String, dynamic>>();

    expect(PluginManagementResponse.fromJson(json), response);
    expect(pluginJson.map((plugin) => (plugin["setup"] as Map<String, dynamic>)["displayName"]), ["Codex", "OpenCode"]);
    expect(json.keys, unorderedEquals(["revision", "defaultPluginId", "defaultIdleTimeoutMins", "plugins"]));
    expect(
      pluginJson.first.keys,
      unorderedEquals([
        "setup",
        "runtimeState",
        "workState",
        "idleTimeoutMins",
        "hasIdleTimeoutOverride",
      ]),
    );
    expect(pluginJson.first, isNot(contains("enabled")));
    expect(pluginJson.first, isNot(contains("isDefault")));
    expect(json, isNot(contains("authority")));
    expect(json, isNot(contains("order")));
    expect(json, isNot(contains("idlePolicy")));
  });

  test("future runtime and work states decode to fail-closed unknown values", () {
    final json = codex.toJson()
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

  test("lifecycle commands round-trip with explicit stop modes", () {
    const commands = <PluginLifecycleCommandRequest>[
      PluginLifecycleCommandRequest.enable(),
      PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
      PluginLifecycleCommandRequest.restart(mode: PluginStopMode.force),
      PluginLifecycleCommandRequest.refresh(),
    ];

    for (final command in commands) {
      expect(PluginLifecycleCommandRequest.fromJson(command.toJson()), command);
    }
    expect(commands[1].toJson(), {"type": "disable", "mode": "safe"});
    expect(commands[2].toJson(), {"type": "restart", "mode": "force"});
    expect(commands[3].toJson(), {"type": "refresh"});
  });

  test("disable and restart reject a missing stop mode", () {
    expect(
      () => PluginLifecycleCommandRequest.fromJson(const {"type": "disable"}),
      throwsArgumentError,
    );
    expect(
      () => PluginLifecycleCommandRequest.fromJson(const {"type": "restart"}),
      throwsArgumentError,
    );
  });

  test("idle-timeout updates round-trip integer minutes", () {
    const updates = <PluginIdleTimeoutUpdateRequest>[
      PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: -30),
      PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "opencode", idleTimeoutMins: 0),
      PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "opencode"),
    ];

    for (final update in updates) {
      expect(PluginIdleTimeoutUpdateRequest.fromJson(update.toJson()), update);
    }
  });

  test("idle-timeout requests reject fractional JSON numbers", () {
    expect(
      () => PluginIdleTimeoutUpdateRequest.fromJson(const {
        "type": "applyAll",
        "idleTimeoutMins": 1.5,
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => PluginIdleTimeoutUpdateRequest.fromJson(const {
        "type": "setOverride",
        "pluginId": "opencode",
        "idleTimeoutMins": -2.5,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test("lifecycle conflicts round-trip the current plugin row", () {
    const conflict = PluginLifecycleConflict(
      pluginId: "opencode",
      reasons: [PluginLifecycleConflictReason.busy, PluginLifecycleConflictReason.inFlight],
      current: opencode,
    );

    expect(PluginLifecycleConflict.fromJson(conflict.toJson()), conflict);
    expect(conflict.toJson()["current"], opencode.toJson());
  });

  test("plugin management invalidation SSE round-trips with its revision", () {
    const event = SesoriSseEvent.pluginManagementChanged(revision: 8);

    expect(event.toJson(), {"type": "plugin.management.changed", "revision": 8});
    expect(SesoriSseEvent.fromJson(event.toJson()), event);
  });
}
