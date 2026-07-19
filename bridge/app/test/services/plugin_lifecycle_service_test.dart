import "dart:async";

import "package:sesori_bridge/src/bridge/runtime/plugin_runtime.dart";
import "package:sesori_bridge/src/repositories/bridge_settings.dart";
import "package:sesori_bridge/src/repositories/plugin_lifecycle_repository.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" hide PluginRuntimeState;
import "package:sesori_shared/sesori_shared.dart" as shared show PluginRuntimeState;
import "package:test/test.dart";

import "../helpers/plugin_lifecycle_test_support.dart";
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

  test("management snapshot is alphabetical and exposes only derived runtime policy", () {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["zeta", "alpha", "beta"]);
    addTearDown(runtime.dispose);
    final settings = TestBridgeSettingsRepository(
      settings: const BridgeSettings(
        plugins: BridgePluginSettings(
          defaults: PluginLifecycleSettings(idleTimeoutMins: 30),
          settingsByPluginId: {
            "zeta": PluginLifecycleSettings(idleTimeoutMins: 0),
          },
        ),
      ),
    );
    final service =
        PluginLifecycleService(
          lifecycleRepository: PluginLifecycleRepository(runtime: runtime),
          bridgeSettingsRepository: settings,
          idleTimerScheduler: const PluginIdleTimerScheduler(),
        )..registerPlugins(
          plugins: const [
            (id: "zeta", displayName: "Zeta"),
            (id: "beta", displayName: "Beta"),
            (id: "alpha", displayName: "Alpha"),
          ],
        );
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {"beta"},
      setupById: const {
        "alpha": PluginSetupReady(),
        "beta": PluginSetupNotInspected(),
        "zeta": PluginSetupRuntimeMissing(actionHint: "Install Zeta."),
      },
    );

    final snapshot = service.managementSnapshot;
    expect(snapshot.revision, 0);
    expect(snapshot.defaultPluginId, "alpha");
    expect(snapshot.defaultIdleTimeoutMins, 30);
    expect(snapshot.plugins.map((plugin) => plugin.setup.id), ["alpha", "beta", "zeta"]);
    expect(snapshot.plugins.map((plugin) => plugin.runtimeState), [
      shared.PluginRuntimeState.dormant,
      shared.PluginRuntimeState.disabled,
      shared.PluginRuntimeState.blocked,
    ]);
    expect(snapshot.plugins.last.idleTimeoutMins, 0);
    expect(snapshot.plugins.last.hasIdleTimeoutOverride, isTrue);
  });

  test("equal plugin commands join while differing commands return a typed transition conflict", () async {
    final repository = _ManagementLifecycleRepository(
      setup: const PluginSetupRuntimeMissing(actionHint: "Install it."),
    );
    final inspectGate = Completer<void>();
    repository
      ..inspectGate = inspectGate
      ..inspectResult = const PluginSetupReady();
    final service = _managementService(repository: repository);
    addTearDown(repository.dispose);
    addTearDown(service.dispose);

    final first = service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.refresh());
    final joined = service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.refresh());

    expect(identical(first, joined), isTrue);
    expect(
      () => service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.enable()),
      throwsA(
        isA<PluginManagementConflictException>().having(
          (error) => error.conflict.reasons,
          "reasons",
          [PluginLifecycleConflictReason.transitioning],
        ),
      ),
    );
    inspectGate.complete();
    await first;
    expect(repository.inspectCalls, 1);
  });

  test("enable persists eligibility, inspects setup, and leaves non-ready plugins blocked", () async {
    final repository = _ManagementLifecycleRepository(
      accessGate: PluginRuntimeAccessGate.disabled,
      setup: const PluginSetupNotInspected(),
    )..inspectResult = const PluginSetupRuntimeMissing(actionHint: "Install it.");
    final settings = TestBridgeSettingsRepository(
      settings: const BridgeSettings(
        plugins: BridgePluginSettings(disabledPluginIds: {"one"}),
      ),
    );
    final service = _managementService(repository: repository, settings: settings, disabled: const {"one"});
    addTearDown(repository.dispose);
    addTearDown(service.dispose);

    final response = await service.command(
      pluginId: "one",
      request: const PluginLifecycleCommandRequest.enable(),
    );

    expect(settings.settings.plugins.disabledPluginIds, isEmpty);
    expect(repository.inspectCalls, 1);
    expect(repository.startCalls, 0);
    expect(response.plugins.single.runtimeState, shared.PluginRuntimeState.blocked);
  });

  const eligibleRecoveryCases = <({String name, PluginRuntimeState state, PluginSetupStatus setup})>[
    (name: "dormant", state: PluginRuntimeState.dormant, setup: PluginSetupReady()),
    (name: "failed", state: PluginRuntimeState.failed, setup: PluginSetupReady()),
    (
      name: "blocked",
      state: PluginRuntimeState.blocked,
      setup: PluginSetupRuntimeMissing(actionHint: "Install it."),
    ),
  ];
  for (final recoveryCase in eligibleRecoveryCases) {
    test("enable retries an already eligible ${recoveryCase.name} plugin without rewriting settings", () async {
      final repository = _ManagementLifecycleRepository(
        setup: recoveryCase.setup,
        state: recoveryCase.state,
      )..inspectResult = const PluginSetupReady();
      final settings = TestBridgeSettingsRepository(settings: const BridgeSettings());
      final service = _managementService(repository: repository, settings: settings);
      addTearDown(repository.dispose);
      addTearDown(service.dispose);

      final response = await service.command(
        pluginId: "one",
        request: const PluginLifecycleCommandRequest.enable(),
      );

      expect(settings.saveCalls, 0);
      expect(repository.inspectCalls, 1);
      expect(repository.startCalls, 1);
      expect(response.plugins.single.runtimeState, shared.PluginRuntimeState.active);
    });
  }

  test("disable conflicts restore access and perform no settings write", () async {
    final repository = _ManagementLifecycleRepository()
      ..disableConflictReasons = const [PluginRuntimeConflictReason.busy];
    final settings = TestBridgeSettingsRepository(settings: const BridgeSettings());
    final service = _managementService(repository: repository, settings: settings);
    addTearDown(repository.dispose);
    addTearDown(service.dispose);

    await expectLater(
      service.command(
        pluginId: "one",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
      ),
      throwsA(
        isA<PluginManagementConflictException>().having(
          (error) => error.conflict.reasons,
          "reasons",
          [PluginLifecycleConflictReason.busy],
        ),
      ),
    );

    expect(settings.saveCalls, 0);
    expect(repository.snapshot.single.accessGate, PluginRuntimeAccessGate.enabled);
  });

  test("disable persistence failure restores enabled dormant state without restart", () async {
    final repository = _ManagementLifecycleRepository();
    final settings = TestBridgeSettingsRepository(settings: const BridgeSettings())
      ..saveError = StateError("disk full");
    final service = _managementService(repository: repository, settings: settings);
    addTearDown(repository.dispose);
    addTearDown(service.dispose);

    await expectLater(
      service.command(
        pluginId: "one",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
      ),
      throwsA(isA<PluginManagementCommandFailedException>()),
    );

    expect(repository.restoreCalls, 1);
    expect(repository.startCalls, 0);
    expect(repository.snapshot.single.accessGate, PluginRuntimeAccessGate.enabled);
    expect(repository.snapshot.single.state, PluginRuntimeState.dormant);
    expect(settings.settings.plugins.disabledPluginIds, isEmpty);
  });

  test("management revision is published only after disable final state is queryable", () async {
    final repository = _ManagementLifecycleRepository();
    final settings = TestBridgeSettingsRepository(settings: const BridgeSettings())..saveGate = Completer<void>();
    final service = _managementService(repository: repository, settings: settings);
    addTearDown(repository.dispose);
    addTearDown(service.dispose);
    final revisions = <int>[];
    final subscription = service.managementRevisions.listen(revisions.add);
    addTearDown(subscription.cancel);

    final command = service.command(
      pluginId: "one",
      request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
    );
    await settings.saveStarted.future;

    expect(revisions, isEmpty);
    expect(service.managementSnapshot.plugins.single.runtimeState, shared.PluginRuntimeState.stopping);
    settings.saveGate!.complete();
    final response = await command;

    expect(revisions, [1]);
    expect(response.revision, 1);
    expect(response.plugins.single.runtimeState, shared.PluginRuntimeState.disabled);
    expect((await service.managementSnapshots.first).revision, 1);
  });

  test("restart re-inspects setup and does not replace a generation that becomes blocked", () async {
    final repository = _ManagementLifecycleRepository()
      ..inspectResult = const PluginSetupAuthenticationRequired(actionHint: "Sign in.");
    final service = _managementService(repository: repository);
    addTearDown(repository.dispose);
    addTearDown(service.dispose);

    final response = await service.command(
      pluginId: "one",
      request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.force),
    );

    expect(repository.inspectCalls, 1);
    expect(repository.restartCalls, 0);
    expect(response.plugins.single.runtimeState, shared.PluginRuntimeState.blocked);
  });

  test("refresh widens ready ids without directly starting the plugin", () async {
    final repository = _ManagementLifecycleRepository(
      setup: const PluginSetupRuntimeMissing(actionHint: "Install it."),
    )..inspectResult = const PluginSetupReady();
    final service = _managementService(repository: repository);
    addTearDown(repository.dispose);
    addTearDown(service.dispose);
    final ready = service.readyPluginIds.firstWhere((ids) => ids.contains("one"));

    await service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.refresh());

    expect(await ready, ["one"]);
    expect(repository.startCalls, 0);
  });

  test("numeric idle timeout updates clear only registered overrides and accept negative integers", () async {
    final repository = _ManagementLifecycleRepository();
    final settings = TestBridgeSettingsRepository(
      settings: const BridgeSettings(
        plugins: BridgePluginSettings(
          settingsByPluginId: {
            "one": PluginLifecycleSettings(
              idleTimeoutMins: 5,
              additionalProperties: {"futureOption": "registered-kept"},
            ),
            "future-plugin": PluginLifecycleSettings(
              idleTimeoutMins: 7,
              additionalProperties: {"futureOption": "unknown-kept"},
            ),
          },
        ),
      ),
    );
    final service = _managementService(repository: repository, settings: settings);
    addTearDown(repository.dispose);
    addTearDown(service.dispose);

    final response = await service.updateIdleTimeout(
      request: const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 30),
    );

    expect(response.defaultIdleTimeoutMins, 30);
    expect(response.plugins.single.idleTimeoutMins, 30);
    expect(response.plugins.single.hasIdleTimeoutOverride, isFalse);
    expect(settings.settings.plugins.toJson()["one"], {"futureOption": "registered-kept"});
    expect(settings.settings.plugins.toJson()["future-plugin"], {
      "futureOption": "unknown-kept",
      "idleTimeoutMins": 7,
    });
    expect(
      () => service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "missing"),
      ),
      throwsA(isA<PluginManagementPluginNotFoundException>()),
    );

    final negative = await service.updateIdleTimeout(
      request: const PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "one", idleTimeoutMins: -1),
    );

    expect(negative.plugins.single.idleTimeoutMins, -1);
    expect(negative.plugins.single.hasIdleTimeoutOverride, isTrue);
    expect(settings.settings.plugins.settingsByPluginId["one"]?.idleTimeoutMins, -1);
  });

  test("ready plugin ids replay eligible setup-ready available dormant plugins", () async {
    final repository = _IdleLifecycleRepository(initialState: PluginRuntimeState.dormant);
    addTearDown(repository.dispose);
    final service = PluginLifecycleService(
      lifecycleRepository: repository,
      bridgeSettingsRepository: createTestBridgeSettingsRepository(),
      idleTimerScheduler: const PluginIdleTimerScheduler(),
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
    final timerScheduler = _ControllablePluginIdleTimerScheduler();
    final service = PluginLifecycleService(
      lifecycleRepository: repository,
      bridgeSettingsRepository: createTestBridgeSettingsRepository(),
      idleTimerScheduler: timerScheduler,
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
    expect(timerScheduler.timers, isEmpty);

    repository.publish(
      state: PluginRuntimeState.degraded,
      workState: PluginWorkState.idle,
      leaseCount: 0,
    );
    await _waitUntil(() => timerScheduler.timers.length == 1);
    expect(timerScheduler.timers.single.duration, const Duration(minutes: defaultPluginIdleTimeoutMins));

    repository.publish(workState: PluginWorkState.busy, leaseCount: 0);
    expect(timerScheduler.timers.single.isActive, isFalse);
    timerScheduler.timers.single.elapse();
    await Future<void>.delayed(Duration.zero);
    expect(repository.stopCalls, isZero);

    repository.publish(workState: PluginWorkState.idle, leaseCount: 0);
    await _waitUntil(() => timerScheduler.timers.length == 2);
    repository.replaceWithoutPublishing(workState: PluginWorkState.unknown);
    timerScheduler.timers.last.elapse();
    await Future<void>.delayed(Duration.zero);
    expect(repository.stopCalls, isZero, reason: "expiry must recheck current work state");

    repository.publish(workState: PluginWorkState.idle, leaseCount: 0);
    await _waitUntil(() => timerScheduler.timers.length == 3);
    timerScheduler.timers.last.elapse();
    await _waitUntil(() => repository.stopCalls == 1);
  });

  test("dispose cancels a scheduled idle timer and prevents a later stop", () async {
    final repository = _IdleLifecycleRepository();
    addTearDown(repository.dispose);
    final timerScheduler = _ControllablePluginIdleTimerScheduler();
    final service = PluginLifecycleService(
      lifecycleRepository: repository,
      bridgeSettingsRepository: createTestBridgeSettingsRepository(),
      idleTimerScheduler: timerScheduler,
    )..registerPlugins(plugins: const [(id: "one", displayName: "One")]);
    service.initialize(
      disabledPluginIds: const {},
      setupById: const {"one": PluginSetupReady()},
    );
    repository.publish(workState: PluginWorkState.idle, leaseCount: 0);
    await _waitUntil(() => timerScheduler.timers.length == 1);

    final timer = timerScheduler.timers.single;
    await service.dispose();

    expect(timer.isActive, isFalse);
    timer.elapse();
    await Future<void>.delayed(Duration.zero);
    expect(repository.stopCalls, isZero);
  });

  test("negative idle timeout never auto-stops a demanded plugin", () async {
    final repository = _IdleLifecycleRepository();
    addTearDown(repository.dispose);
    final timerScheduler = _ControllablePluginIdleTimerScheduler();
    final service = PluginLifecycleService(
      lifecycleRepository: repository,
      bridgeSettingsRepository: createTestBridgeSettingsRepository(
        settings: const BridgeSettings(
          plugins: BridgePluginSettings(
            settingsByPluginId: {
              "one": PluginLifecycleSettings(idleTimeoutMins: -7),
            },
          ),
        ),
      ),
      idleTimerScheduler: timerScheduler,
    )..registerPlugins(plugins: const [(id: "one", displayName: "One")]);
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {},
      setupById: const {"one": PluginSetupReady()},
    );

    repository.publish(workState: PluginWorkState.idle, leaseCount: 0);
    await Future<void>.delayed(Duration.zero);

    expect(timerScheduler.timers, isEmpty);
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
    idleTimerScheduler: const PluginIdleTimerScheduler(),
  )..registerPlugins(plugins: plugins);
}

PluginLifecycleService _managementService({
  required _ManagementLifecycleRepository repository,
  TestBridgeSettingsRepository? settings,
  Set<String> disabled = const {},
}) {
  return PluginLifecycleService(
      lifecycleRepository: repository,
      bridgeSettingsRepository: settings ?? TestBridgeSettingsRepository(settings: const BridgeSettings()),
      idleTimerScheduler: const PluginIdleTimerScheduler(),
    )
    ..registerPlugins(plugins: const [(id: "one", displayName: "One")])
    ..initialize(
      disabledPluginIds: disabled,
      setupById: {"one": repository.snapshot.single.setup},
    );
}

class _ManagementLifecycleRepository implements PluginLifecycleRepository {
  _ManagementLifecycleRepository({
    PluginRuntimeAccessGate accessGate = PluginRuntimeAccessGate.enabled,
    PluginSetupStatus setup = const PluginSetupReady(),
    PluginRuntimeState state = PluginRuntimeState.active,
  }) : _current = _snapshot(accessGate: accessGate, setup: setup, state: state);

  final StreamController<List<PluginLifecycleSnapshot>> _snapshots = StreamController.broadcast(sync: true);
  PluginLifecycleSnapshot _current;
  PluginSetupStatus inspectResult = const PluginSetupReady();
  Completer<void>? inspectGate;
  List<PluginRuntimeConflictReason>? disableConflictReasons;
  int inspectCalls = 0;
  int startCalls = 0;
  int restartCalls = 0;
  int restoreCalls = 0;

  @override
  List<PluginLifecycleSnapshot> get snapshot => [_current];

  @override
  Stream<List<PluginLifecycleSnapshot>> get snapshots => _snapshots.stream;

  @override
  void applyAccess({required Set<String> eligiblePluginIds, required Set<String> startAllowedPluginIds}) {
    final enabled = eligiblePluginIds.contains("one");
    final startAllowed = startAllowedPluginIds.contains("one");
    final currentState = _current.state;
    _publish(
      accessGate: enabled ? PluginRuntimeAccessGate.enabled : PluginRuntimeAccessGate.disabled,
      startAllowed: startAllowed,
      state: !enabled
          ? PluginRuntimeState.disabled
          : !startAllowed
          ? PluginRuntimeState.blocked
          : currentState == PluginRuntimeState.disabled || currentState == PluginRuntimeState.blocked
          ? PluginRuntimeState.dormant
          : currentState,
    );
  }

  @override
  Future<Map<String, PluginSetupStatus>> inspect({
    required Set<String> pluginIds,
    required bool markUnselectedNotInspected,
  }) async {
    inspectCalls++;
    await inspectGate?.future;
    _publish(setup: inspectResult);
    return {"one": inspectResult};
  }

  @override
  Future<PluginRuntimeCommandResult> start({required String pluginId}) async {
    startCalls++;
    _publish(state: PluginRuntimeState.active, workState: PluginWorkState.idle);
    return PluginRuntimeCommandApplied(snapshot: _runtimeSnapshot());
  }

  @override
  Future<PluginRuntimeCommandResult> disable({required String pluginId, required PluginStopIntent intent}) async {
    final reasons = disableConflictReasons;
    if (reasons != null) {
      _publish(accessGate: PluginRuntimeAccessGate.enabled);
      return PluginRuntimeCommandConflict(snapshot: _runtimeSnapshot(), reasons: reasons);
    }
    _publish(
      accessGate: PluginRuntimeAccessGate.draining,
      state: PluginRuntimeState.stopping,
      workState: PluginWorkState.unknown,
      transitionSettled: false,
    );
    return PluginRuntimeCommandApplied(snapshot: _runtimeSnapshot());
  }

  @override
  void commitDisabled({required String pluginId}) {
    _publish(
      accessGate: PluginRuntimeAccessGate.disabled,
      state: PluginRuntimeState.disabled,
      startAllowed: false,
      transitionSettled: true,
    );
  }

  @override
  void restoreEnabledAfterDisable({required String pluginId}) {
    restoreCalls++;
    _publish(
      accessGate: PluginRuntimeAccessGate.enabled,
      state: PluginRuntimeState.dormant,
      transitionSettled: true,
    );
  }

  @override
  Future<PluginRuntimeCommandResult> restart({required String pluginId, required PluginStopIntent intent}) async {
    restartCalls++;
    _publish(state: PluginRuntimeState.active, workState: PluginWorkState.idle);
    return PluginRuntimeCommandApplied(snapshot: _runtimeSnapshot());
  }

  @override
  Future<PluginRuntimeCommandResult> stop({required String pluginId, required PluginStopIntent intent}) async {
    _publish(state: PluginRuntimeState.dormant, workState: PluginWorkState.unknown);
    return PluginRuntimeCommandApplied(snapshot: _runtimeSnapshot());
  }

  @override
  Future<PluginRuntimeCommandResult> stopSafely({required String pluginId}) {
    return stop(pluginId: pluginId, intent: PluginStopIntent.safe);
  }

  Future<void> dispose() => _snapshots.close();

  void _publish({
    PluginRuntimeAccessGate? accessGate,
    PluginSetupStatus? setup,
    bool? startAllowed,
    PluginRuntimeState? state,
    PluginWorkState? workState,
    bool? transitionSettled,
  }) {
    _current = _snapshot(
      accessGate: accessGate ?? _current.accessGate,
      setup: setup ?? _current.setup,
      startAllowed: startAllowed ?? _current.startAllowed,
      state: state ?? _current.state,
      workState: workState ?? _current.workState,
      transitionSettled: transitionSettled ?? _current.transitionSettled,
    );
    _snapshots.add(snapshot);
  }

  PluginRuntimeSnapshot _runtimeSnapshot() {
    return PluginRuntimeSnapshot(
      pluginId: "one",
      projectOwnership: PluginProjectOwnership.native,
      setup: _current.setup,
      accessGate: _current.accessGate,
      startAllowed: _current.startAllowed,
      generation: 1,
      state: _current.state,
      workState: _current.workState,
      leaseCount: _current.leaseCount,
      transition: _current.transitionSettled ? PluginRuntimeTransition.none : PluginRuntimeTransition.stopping,
    );
  }

  static PluginLifecycleSnapshot _snapshot({
    required PluginRuntimeAccessGate accessGate,
    required PluginSetupStatus setup,
    bool startAllowed = true,
    PluginRuntimeState state = PluginRuntimeState.active,
    PluginWorkState workState = PluginWorkState.idle,
    bool transitionSettled = true,
  }) {
    return PluginLifecycleSnapshot(
      pluginId: "one",
      projectOwnership: PluginProjectOwnership.native,
      setup: setup,
      accessGate: accessGate,
      startAllowed: startAllowed,
      state: state,
      workState: workState,
      leaseCount: 0,
      transitionSettled: transitionSettled,
    );
  }
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
        accessGate: PluginRuntimeAccessGate.enabled,
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
      accessGate: PluginRuntimeAccessGate.enabled,
      startAllowed: true,
      state: state,
      workState: workState,
      leaseCount: leaseCount,
      transitionSettled: transitionSettled,
    );
  }
}

class _ControllablePluginIdleTimerScheduler implements PluginIdleTimerScheduler {
  final List<_ControllablePluginIdleTimer> timers = [];

  @override
  Timer schedule({required Duration duration, required void Function() onElapsed}) {
    final timer = _ControllablePluginIdleTimer(duration: duration, onElapsed: onElapsed);
    timers.add(timer);
    return timer;
  }
}

class _ControllablePluginIdleTimer implements Timer {
  _ControllablePluginIdleTimer({required this.duration, required void Function() onElapsed}) : _onElapsed = onElapsed;

  final Duration duration;
  final void Function() _onElapsed;
  bool _isActive = true;

  void elapse() {
    if (!_isActive) return;
    _isActive = false;
    _onElapsed();
  }

  @override
  void cancel() => _isActive = false;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => _isActive ? 0 : 1;
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError("condition was not reached");
}
