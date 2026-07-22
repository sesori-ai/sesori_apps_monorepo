import "package:sesori_shared/sesori_shared.dart";

const testPluginA = PluginManagementMetadata(
  setup: PluginSetupMetadata(
    id: "plugin-a",
    displayName: "Plugin A",
    state: PluginSetupState.ready,
    actionHint: null,
  ),
  runtimeState: PluginRuntimeState.active,
  workState: PluginManagementWorkState.idle,
  idleTimeoutMins: 10,
  hasIdleTimeoutOverride: false,
  actionHint: null,
);

const testPluginB = PluginManagementMetadata(
  setup: PluginSetupMetadata(
    id: "plugin-b",
    displayName: "Plugin B",
    state: PluginSetupState.runtimeMissing,
    actionHint: "Install its runtime.",
  ),
  runtimeState: PluginRuntimeState.blocked,
  workState: PluginManagementWorkState.unknown,
  idleTimeoutMins: 20,
  hasIdleTimeoutOverride: true,
  actionHint: "Resolve setup, then refresh.",
);

const testPluginManagementResponse = PluginManagementResponse(
  revision: 1,
  defaultPluginId: "plugin-a",
  defaultIdleTimeoutMins: 10,
  plugins: [testPluginA, testPluginB],
);

PluginManagementResponse testPluginManagementResponseAt({required int revision}) {
  return testPluginManagementResponse.copyWith(revision: revision);
}
