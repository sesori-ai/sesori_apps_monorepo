import "package:sesori_bridge/src/bridge/runtime/plugin_runtime.dart";
import "package:sesori_bridge/src/repositories/plugin_lifecycle_repository.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/plugin_runtime_test_support.dart";

void main() {
  test("derives alphabetical eligibility, eager startup, and default from setup", () {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["zeta", "alpha", "beta"]);
    addTearDown(runtime.dispose);
    final service = _service(
      runtime: runtime,
      plugins: const [
        (id: "zeta", displayName: "Zeta"),
        (id: "beta", displayName: "Beta"),
        (id: "alpha", displayName: "Alpha"),
      ],
    );
    addTearDown(service.dispose);

    final policy = service.initialize(
      disabledPluginIds: const {"beta", "future-plugin"},
      setupById: const {
        "alpha": PluginSetupReady(),
        "beta": PluginSetupNotInspected(),
        "zeta": PluginSetupRuntimeMissing(actionHint: "Install Zeta."),
      },
    );

    expect(policy.eligiblePluginIds, ["alpha", "zeta"]);
    expect(policy.eagerPluginIds, ["alpha"]);
    expect(policy.defaultPluginId, "alpha");
    expect(service.compositionView.eligiblePluginIds, ["alpha", "zeta"]);
    expect(runtime.snapshot.singleWhere((entry) => entry.pluginId == "beta").state, PluginRuntimeState.disabled);
    expect(runtime.snapshot.singleWhere((entry) => entry.pluginId == "zeta").state, PluginRuntimeState.blocked);
  });

  test("availability narrows startup access without changing eligibility", () {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["alpha", "beta"]);
    addTearDown(runtime.dispose);
    final service = _service(
      runtime: runtime,
      plugins: const [
        (id: "alpha", displayName: "Alpha"),
        (id: "beta", displayName: "Beta"),
      ],
    );
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {},
      setupById: const {
        "alpha": PluginSetupReady(),
        "beta": PluginSetupReady(),
      },
    );

    service.applyAvailability(availablePluginIds: const {"beta"});

    expect(runtime.snapshot.singleWhere((entry) => entry.pluginId == "alpha").state, PluginRuntimeState.blocked);
    expect(runtime.snapshot.singleWhere((entry) => entry.pluginId == "beta").state, PluginRuntimeState.dormant);
    expect(service.compositionView.eligiblePluginIds, ["alpha", "beta"]);
  });

  test("setup endpoint remains an alphabetical startup snapshot", () {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["cursor", "opencode"]);
    addTearDown(runtime.dispose);
    final service = _service(
      runtime: runtime,
      plugins: const [
        (id: "opencode", displayName: "OpenCode"),
        (id: "cursor", displayName: "Cursor"),
      ],
    );
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {"cursor"},
      setupById: const {
        "cursor": PluginSetupNotInspected(),
        "opencode": PluginSetupAuthenticationRequired(actionHint: "Run opencode auth login."),
      },
    );

    expect(
      service.setupSnapshot.plugins,
      [
        const PluginSetupMetadata(
          id: "cursor",
          displayName: "Cursor",
          state: PluginSetupState.notInspected,
          actionHint: null,
        ),
        const PluginSetupMetadata(
          id: "opencode",
          displayName: "OpenCode",
          state: PluginSetupState.authenticationRequired,
          actionHint: "Run opencode auth login.",
        ),
      ],
    );
  });

  test("runtime snapshots drive selectable metadata and derived default", () async {
    final alpha = _FakePluginApi(id: "alpha");
    final beta = _FakePluginApi(id: "beta");
    final runtime = createTestPluginRuntime(plugins: [beta, alpha]);
    addTearDown(runtime.dispose);
    final service = _service(
      runtime: runtime,
      plugins: const [
        (id: "beta", displayName: "Beta"),
        (id: "alpha", displayName: "Alpha"),
      ],
    );
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {},
      setupById: const {
        "alpha": PluginSetupReady(),
        "beta": PluginSetupReady(),
      },
    );

    await Future<void>.delayed(Duration.zero);

    expect(service.selectableMetadataSnapshot.map((entry) => entry.id), ["alpha", "beta"]);
    expect(service.compositionView.defaultPluginId, "alpha");
  });

  test("supports a zero-plugin composition", () {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const []);
    addTearDown(runtime.dispose);
    final service = _service(runtime: runtime, plugins: const []);
    addTearDown(service.dispose);

    final policy = service.initialize(disabledPluginIds: const {}, setupById: const {});

    expect(policy.eligiblePluginIds, isEmpty);
    expect(policy.eagerPluginIds, isEmpty);
    expect(policy.defaultPluginId, isNull);
    expect(service.metadataSnapshot, isEmpty);
    expect(service.setupSnapshot.plugins, isEmpty);
  });

  test("rejects incomplete setup snapshots", () {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["alpha"]);
    addTearDown(runtime.dispose);
    final service = _service(
      runtime: runtime,
      plugins: const [(id: "alpha", displayName: "Alpha")],
    );
    addTearDown(service.dispose);

    expect(
      () => service.initialize(disabledPluginIds: const {}, setupById: const {}),
      throwsArgumentError,
    );
  });
}

PluginLifecycleService _service({
  required PluginRuntime runtime,
  required List<RegisteredPluginMetadata> plugins,
}) {
  return PluginLifecycleService(
    lifecycleRepository: PluginLifecycleRepository(runtime: runtime),
  )..registerPlugins(plugins: plugins);
}

class _FakePluginApi extends BridgeDerivedProjectsPluginApi {
  _FakePluginApi({required this.id});

  @override
  final String id;

  @override
  Stream<BridgeSseEvent> get events => const Stream.empty();

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
