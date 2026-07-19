import "dart:async";

import "package:sesori_bridge/src/bridge/runtime/plugin_runtime.dart";
import "package:sesori_bridge/src/repositories/bridge_settings.dart";
import "package:sesori_bridge/src/repositories/plugin_lifecycle_repository.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/plugin_lifecycle_test_support.dart" show createTestBridgeSettingsRepository;
import "../helpers/plugin_runtime_test_support.dart";

void main() {
  test("derives alphabetical dormant eligibility and default from setup", () {
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
    expect(policy.defaultPluginId, "alpha");
    expect(service.compositionView.eligiblePluginIds, ["alpha", "zeta"]);
    expect(runtime.snapshot.singleWhere((entry) => entry.pluginId == "beta").state, PluginRuntimeState.disabled);
    expect(runtime.snapshot.singleWhere((entry) => entry.pluginId == "zeta").state, PluginRuntimeState.blocked);
    expect(runtime.snapshot.singleWhere((entry) => entry.pluginId == "alpha").state, PluginRuntimeState.dormant);
    expect(service.selectableMetadataSnapshot.map((entry) => entry.id), ["alpha"]);
    expect(service.metadataSnapshot.first.state, PluginLifecycleState.ready);
  });

  test("availability narrows startup access without changing eligibility", () async {
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
    expect(service.selectableMetadataSnapshot.map((entry) => entry.id), ["beta"]);
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

  test("ready plugin ids replay eligible setup-ready available dormant plugins", () async {
    final repository = _IdleLifecycleRepository(initialState: PluginRuntimeState.dormant);
    addTearDown(repository.dispose);
    final service = PluginLifecycleService(
      lifecycleRepository: repository,
      bridgeSettingsRepository: createTestBridgeSettingsRepository(),
      clock: const ServerClock(),
    )..registerPlugins(plugins: const [(id: "one", displayName: "One")]);
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {},
      setupById: const {"one": PluginSetupReady()},
    );

    expect(await service.readyPluginIds.first, ["one"]);
    expect(service.selectableMetadataSnapshot.map((entry) => entry.id), ["one"]);
  });

  test("idle suspension requires every safe-stop gate and uses a full positive timeout", () async {
    final repository = _IdleLifecycleRepository();
    addTearDown(repository.dispose);
    final clock = _ControllableServerClock();
    final service = PluginLifecycleService(
      lifecycleRepository: repository,
      bridgeSettingsRepository: createTestBridgeSettingsRepository(),
      clock: clock,
    )..registerPlugins(plugins: const [(id: "one", displayName: "One")]);
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {},
      setupById: const {"one": PluginSetupReady()},
    );

    repository.publish(workState: PluginWorkState.unknown, leaseCount: 0);
    repository.publish(workState: PluginWorkState.busy, leaseCount: 0);
    repository.publish(workState: PluginWorkState.idle, leaseCount: 1);
    repository.publish(
      state: PluginRuntimeState.active,
      workState: PluginWorkState.idle,
      leaseCount: 0,
      transitionSettled: false,
    );
    repository.publish(
      state: PluginRuntimeState.dormant,
      workState: PluginWorkState.idle,
      leaseCount: 0,
    );
    await Future<void>.delayed(Duration.zero);
    expect(clock.delays, isEmpty);

    repository.publish(
      state: PluginRuntimeState.degraded,
      workState: PluginWorkState.idle,
      leaseCount: 0,
    );
    await _waitUntil(() => clock.delays.length == 1);
    expect(clock.delays.single.duration, const Duration(minutes: defaultPluginIdleTimeoutMins));

    repository.publish(workState: PluginWorkState.busy, leaseCount: 0);
    clock.delays.single.completer.complete();
    await Future<void>.delayed(Duration.zero);
    expect(repository.stopCalls, isZero);

    repository.publish(workState: PluginWorkState.idle, leaseCount: 0);
    await _waitUntil(() => clock.delays.length == 2);
    repository.replaceWithoutPublishing(workState: PluginWorkState.unknown);
    clock.delays.last.completer.complete();
    await Future<void>.delayed(Duration.zero);
    expect(repository.stopCalls, isZero, reason: "expiry must recheck current work state");

    repository.publish(workState: PluginWorkState.idle, leaseCount: 0);
    await _waitUntil(() => clock.delays.length == 3);
    clock.delays.last.completer.complete();
    await _waitUntil(() => repository.stopCalls == 1);
  });

  test("non-positive idle timeout never auto-stops a demanded plugin", () async {
    final repository = _IdleLifecycleRepository();
    addTearDown(repository.dispose);
    final clock = _ControllableServerClock();
    final service = PluginLifecycleService(
      lifecycleRepository: repository,
      bridgeSettingsRepository: createTestBridgeSettingsRepository(
        settings: const BridgeSettings(
          plugins: BridgePluginSettings(
            settingsByPluginId: {
              "one": PluginLifecycleSettings(idleTimeoutMins: 0),
            },
          ),
        ),
      ),
      clock: clock,
    )..registerPlugins(plugins: const [(id: "one", displayName: "One")]);
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {},
      setupById: const {"one": PluginSetupReady()},
    );

    repository.publish(workState: PluginWorkState.idle, leaseCount: 0);
    await Future<void>.delayed(Duration.zero);

    expect(clock.delays, isEmpty);
    expect(repository.stopCalls, isZero);
  });
}

PluginLifecycleService _service({
  required PluginRuntime runtime,
  required List<RegisteredPluginMetadata> plugins,
}) {
  return PluginLifecycleService(
    lifecycleRepository: PluginLifecycleRepository(runtime: runtime),
    bridgeSettingsRepository: createTestBridgeSettingsRepository(),
    clock: const ServerClock(),
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

class _IdleLifecycleRepository implements PluginLifecycleRepository {
  _IdleLifecycleRepository({PluginRuntimeState initialState = PluginRuntimeState.active})
    : _current = [
        _snapshot(
          state: initialState,
          workState: PluginWorkState.unknown,
          leaseCount: 0,
        ),
      ];

  final StreamController<List<PluginLifecycleSnapshot>> _snapshots = StreamController.broadcast(sync: true);
  List<PluginLifecycleSnapshot> _current;
  int stopCalls = 0;

  @override
  Stream<List<PluginLifecycleSnapshot>> get snapshots => _snapshots.stream;

  @override
  List<PluginLifecycleSnapshot> get snapshot => List.unmodifiable(_current);

  @override
  void applyAccess({required Set<String> eligiblePluginIds, required Set<String> startAllowedPluginIds}) {}

  void publish({
    PluginRuntimeState state = PluginRuntimeState.active,
    required PluginWorkState workState,
    required int leaseCount,
    bool transitionSettled = true,
  }) {
    _current = [
      _snapshot(
        state: state,
        workState: workState,
        leaseCount: leaseCount,
        transitionSettled: transitionSettled,
      ),
    ];
    _snapshots.add(snapshot);
  }

  void replaceWithoutPublishing({required PluginWorkState workState}) {
    _current = [_snapshot(workState: workState, leaseCount: 0)];
  }

  @override
  Future<PluginRuntimeCommandResult> stopSafely({required String pluginId}) async {
    stopCalls++;
    _current = [
      _snapshot(
        state: PluginRuntimeState.dormant,
        workState: PluginWorkState.unknown,
        leaseCount: 0,
      ),
    ];
    _snapshots.add(snapshot);
    return PluginRuntimeCommandApplied(
      snapshot: PluginRuntimeSnapshot(
        pluginId: pluginId,
        projectOwnership: PluginProjectOwnership.native,
        setup: const PluginSetupReady(),
        eligible: true,
        startAllowed: true,
        generation: 1,
        state: PluginRuntimeState.dormant,
        workState: PluginWorkState.unknown,
        leaseCount: 0,
        transition: PluginRuntimeTransition.none,
      ),
    );
  }

  Future<void> dispose() => _snapshots.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  static PluginLifecycleSnapshot _snapshot({
    PluginRuntimeState state = PluginRuntimeState.active,
    required PluginWorkState workState,
    required int leaseCount,
    bool transitionSettled = true,
  }) {
    return PluginLifecycleSnapshot(
      pluginId: "one",
      projectOwnership: PluginProjectOwnership.native,
      setup: const PluginSetupReady(),
      eligible: true,
      startAllowed: true,
      state: state,
      workState: workState,
      leaseCount: leaseCount,
      transitionSettled: transitionSettled,
    );
  }
}

class _ControllableServerClock extends ServerClock {
  final List<({Duration duration, Completer<void> completer})> delays = [];

  @override
  Future<void> delay({required Duration duration}) {
    final completer = Completer<void>();
    delays.add((duration: duration, completer: completer));
    return completer.future;
  }
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError("condition was not reached");
}
