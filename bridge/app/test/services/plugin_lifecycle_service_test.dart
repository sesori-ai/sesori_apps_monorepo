import "dart:async";

import "package:sesori_bridge/src/bridge/runtime/plugin_runtime.dart";
import "package:sesori_bridge/src/repositories/bridge_settings.dart";
import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/repositories/plugin_lifecycle_repository.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" hide PluginRuntimeState;
import "package:sesori_shared/sesori_shared.dart" as shared show PluginRuntimeState;
import "package:test/test.dart";

import "../helpers/plugin_lifecycle_test_support.dart";
import "../helpers/plugin_runtime_test_support.dart";
import "../helpers/test_helpers.dart";

void main() {
  test("derives alphabetical eligibility and default from setup", () {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["zeta", "alpha", "beta"]);
    addTearDown(runtime.dispose);
    final service = _service(
      runtime: runtime,
      plugins: const [
        (
          id: "zeta",
          displayName: "Zeta",
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
        ),
        (
          id: "beta",
          displayName: "Beta",
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.plugin,
          managementCapabilities: defaultManagementCapabilities,
        ),
        (
          id: "alpha",
          displayName: "Alpha",
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
        ),
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
    expect(service.compositionView.orderedPluginIds, ["alpha", "beta", "zeta"]);
    final sessionOptionsScopeById = service.compositionView.sessionOptionsScopeById;
    expect(sessionOptionsScopeById, const {
      "alpha": PluginSessionOptionsScope.project,
      "beta": PluginSessionOptionsScope.plugin,
      "zeta": PluginSessionOptionsScope.project,
    });
    expect(
      () => sessionOptionsScopeById["alpha"] = PluginSessionOptionsScope.plugin,
      throwsUnsupportedError,
    );
    expect(runtime.snapshot.singleWhere((entry) => entry.pluginId == "beta").state, PluginRuntimeState.disabled);
    expect(runtime.snapshot.singleWhere((entry) => entry.pluginId == "zeta").state, PluginRuntimeState.blocked);
  });

  test("prefers OpenCode as the default before falling back to alphabetical setup readiness", () async {
    final opencode = _FakePluginApi(id: "opencode");
    final alpha = _FakePluginApi(id: "alpha");
    final runtime = createTestPluginRuntime(plugins: [alpha, opencode]);
    addTearDown(runtime.dispose);
    final service = _service(
      runtime: runtime,
      plugins: const [
        (
          id: "alpha",
          displayName: "Alpha",
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
        ),
        (
          id: "opencode",
          displayName: "OpenCode",
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
        ),
      ],
    );
    addTearDown(service.dispose);

    final policy = service.initialize(
      disabledPluginIds: const {},
      setupById: const {
        "alpha": PluginSetupReady(),
        "opencode": PluginSetupReady(),
      },
    );
    await Future<void>.delayed(Duration.zero);

    expect(policy.defaultPluginId, "opencode");
    expect(service.compositionView.defaultPluginId, "opencode");
    expect(
      service.selectableMetadataSnapshot.singleWhere((entry) => entry.isDefault).id,
      "opencode",
    );
  });

  test("falls back to the first setup-ready plugin when OpenCode is unavailable", () {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["opencode", "alpha"]);
    addTearDown(runtime.dispose);
    final service = _service(
      runtime: runtime,
      plugins: const [
        (
          id: "opencode",
          displayName: "OpenCode",
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
        ),
        (
          id: "alpha",
          displayName: "Alpha",
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
        ),
      ],
    );
    addTearDown(service.dispose);

    final policy = service.initialize(
      disabledPluginIds: const {},
      setupById: const {
        "opencode": PluginSetupRuntimeMissing(actionHint: "Install OpenCode."),
        "alpha": PluginSetupReady(),
      },
    );

    expect(policy.defaultPluginId, "alpha");
  });

  test("setup endpoint remains an alphabetical startup snapshot", () {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["cursor", "opencode"]);
    addTearDown(runtime.dispose);
    final service = _service(
      runtime: runtime,
      plugins: const [
        (
          id: "opencode",
          displayName: "OpenCode",
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
        ),
        (
          id: "cursor",
          displayName: "Cursor",
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.plugin,
          managementCapabilities: defaultManagementCapabilities,
        ),
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

  test("management snapshot reports stable read-only lifecycle and timeout state", () {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["opencode", "alpha", "beta"]);
    addTearDown(runtime.dispose);
    final settingsRepository = createTestBridgeSettingsRepository(
      settings: const BridgeSettings(
        plugins: BridgePluginSettings(
          defaults: PluginLifecycleSettings(idleTimeoutMins: 30),
          settingsByPluginId: {
            "opencode": PluginLifecycleSettings(idleTimeoutMins: 45),
          },
        ),
      ),
    );
    final bridgeIdProvider = FakeBridgeIdProvider();
    final service =
        PluginLifecycleService(
            lifecycleRepository: PluginLifecycleRepository(runtime: runtime),
            preferredDefaultPluginId: legacyMissingPluginId,
            bridgeSettingsRepository: settingsRepository,
            idleTimerScheduler: const PluginIdleTimerScheduler(),
            bridgeIdProvider: bridgeIdProvider,
          )
          ..registerPlugins(
            plugins: const [
              (
                id: "opencode",
                displayName: "OpenCode",
                residencyPolicy: PluginResidencyPolicy.resident,
                sessionOptionsScope: PluginSessionOptionsScope.project,
                managementCapabilities: defaultManagementCapabilities,
              ),
              (
                id: "alpha",
                displayName: "Alpha",
                residencyPolicy: PluginResidencyPolicy.transient,
                sessionOptionsScope: PluginSessionOptionsScope.project,
                managementCapabilities: defaultManagementCapabilities,
              ),
              (
                id: "beta",
                displayName: "Beta",
                residencyPolicy: PluginResidencyPolicy.transient,
                sessionOptionsScope: PluginSessionOptionsScope.plugin,
                managementCapabilities: defaultManagementCapabilities,
              ),
            ],
          )
          ..initialize(
            disabledPluginIds: const {"beta"},
            setupById: const {
              "opencode": PluginSetupReady(),
              "alpha": PluginSetupRuntimeMissing(actionHint: "Install Alpha."),
              "beta": PluginSetupNotInspected(),
            },
          );
    addTearDown(service.dispose);

    // Lifecycle initialization precedes bridge registration in the runtime;
    // management must fail closed until the authority supplies an identity,
    // then attach that current identity when returning.
    expect(() => service.managementSnapshot, throwsStateError);
    expect(
      () => service.command(
        pluginId: "opencode",
        request: const PluginLifecycleCommandRequest.refresh(),
      ),
      throwsStateError,
    );
    expect(
      () => service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 60),
      ),
      throwsStateError,
    );
    expect(settingsRepository.currentSettings.plugins.defaults.idleTimeoutMins, 30);
    bridgeIdProvider.id = "br_test1234";
    final response = service.managementSnapshot;

    expect(response.bridgeId, "br_test1234");
    expect(response.defaultPluginId, "opencode");
    expect(response.defaultIdleTimeoutMins, 30);
    expect(response.plugins.map((plugin) => plugin.setup.id), ["alpha", "beta", "opencode"]);
    final alpha = response.plugins[0];
    final beta = response.plugins[1];
    final opencode = response.plugins[2];
    expect(alpha.runtimeState, shared.PluginRuntimeState.blocked);
    expect(alpha.idleTimeoutMins, 30);
    expect(alpha.actionHint, "Install Alpha.");
    expect(beta.runtimeState, shared.PluginRuntimeState.disabled);
    expect(opencode.runtimeState, shared.PluginRuntimeState.dormant);
    expect(opencode.idleTimeoutMins, 0);
    expect(opencode.hasIdleTimeoutOverride, isTrue);
    expect(settingsRepository.currentSettings.plugins.idleTimeoutMinsFor(pluginId: "opencode"), 45);
    expect(runtime.activePluginIds, isEmpty);
  });

  test("management snapshot publishes each plugin's declared capabilities", () {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupReady(),
      inspectionGate: null,
      startFailureMessage: null,
    );
    final service =
        _commandService(
          repository: repository,
          settingsRepository: null,
          managementCapabilities: const {PluginControlCapability.setupRefresh},
        )..initialize(
          disabledPluginIds: const {},
          setupById: const {"one": PluginSetupReady()},
        );
    addTearDown(() async {
      await service.dispose();
      await repository.dispose();
    });

    expect(
      service.managementSnapshot.plugins.single.managementCapabilities,
      const {PluginManagementCapability.setupRefresh},
    );
  });

  test("management snapshot uses the immutable capability registration snapshot", () {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupReady(),
      inspectionGate: null,
      startFailureMessage: null,
    );
    final capabilities = <PluginControlCapability>{PluginControlCapability.setupRefresh};
    final service = _commandService(
      repository: repository,
      settingsRepository: null,
      managementCapabilities: capabilities,
    );
    capabilities
      ..clear()
      ..add(PluginControlCapability.lifecycle);
    service.initialize(
      disabledPluginIds: const {},
      setupById: const {"one": PluginSetupReady()},
    );
    addTearDown(() async {
      await service.dispose();
      await repository.dispose();
    });

    expect(
      service.managementSnapshot.plugins.single.managementCapabilities,
      const {PluginManagementCapability.setupRefresh},
    );
  });

  test("reports disabled plugins that cannot be lifecycle-managed", () {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["external", "managed"]);
    addTearDown(runtime.dispose);
    final settingsRepository = _MutableBridgeSettingsRepository(
      settings: const BridgeSettings(
        plugins: BridgePluginSettings(disabledPluginIds: {"external", "managed", "future-plugin"}),
      ),
    );
    final service =
        PluginLifecycleService(
          lifecycleRepository: PluginLifecycleRepository(runtime: runtime),
          preferredDefaultPluginId: legacyMissingPluginId,
          bridgeSettingsRepository: settingsRepository,
          idleTimerScheduler: const PluginIdleTimerScheduler(),
          bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
        )..registerPlugins(
          plugins: const [
            (
              id: "external",
              displayName: "External",
              residencyPolicy: PluginResidencyPolicy.resident,
              sessionOptionsScope: PluginSessionOptionsScope.plugin,
              managementCapabilities: {PluginControlCapability.setupRefresh},
            ),
            (
              id: "managed",
              displayName: "Managed",
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: defaultManagementCapabilities,
            ),
          ],
        );
    addTearDown(service.dispose);

    final disabledPluginIds = service.uncontrollableDisabledPluginIds(
      disabledPluginIds: settingsRepository.currentSettings.plugins.disabledPluginIds,
    );

    expect(disabledPluginIds, const {"external"});
    expect(
      settingsRepository.currentSettings.plugins.disabledPluginIds,
      const {"external", "managed", "future-plugin"},
    );
  });

  test("management snapshot tokens publish only externally visible changes", () async {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["alpha"]);
    final service =
        _service(
          runtime: runtime,
          plugins: const [
            (
              id: "alpha",
              displayName: "Alpha",
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: defaultManagementCapabilities,
            ),
          ],
        )..initialize(
          disabledPluginIds: const {},
          setupById: const {"alpha": PluginSetupReady()},
        );
    addTearDown(() async {
      await service.dispose();
      await runtime.dispose();
    });
    final snapshotTokens = <String>[];
    final subscription = service.managementSnapshotTokens.listen(snapshotTokens.add);
    addTearDown(subscription.cancel);

    final initialToken = service.managementSnapshot.snapshotToken;
    expect(initialToken, isNotNull);
    expect(initialToken, hasLength(22));

    runtime.applyAccess(
      entries: const [
        PluginRuntimeAccess(
          pluginId: "alpha",
          gate: PluginRuntimeAccessGate.enabled,
          startAllowed: false,
        ),
      ],
    );
    await Future<void>.delayed(Duration.zero);

    expect(snapshotTokens, hasLength(1));
    expect(service.managementSnapshot.snapshotToken, snapshotTokens.single);
    expect(snapshotTokens.single, isNot(initialToken));
    expect(service.managementSnapshot.plugins.single.runtimeState, shared.PluginRuntimeState.blocked);

    runtime.applyAccess(
      entries: const [
        PluginRuntimeAccess(
          pluginId: "alpha",
          gate: PluginRuntimeAccessGate.enabled,
          startAllowed: false,
        ),
      ],
    );
    await Future<void>.delayed(Duration.zero);

    expect(snapshotTokens, hasLength(1));
  });

  test("management tokens do not strand transient or unrelated plugin changes", () async {
    final alpha = _FakePluginApi(id: "alpha");
    final beta = _FakePluginApi(id: "beta");
    final runtime = createTestPluginRuntime(plugins: [alpha, beta]);
    final service =
        _service(
          runtime: runtime,
          plugins: const [
            (
              id: "alpha",
              displayName: "Alpha",
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: defaultManagementCapabilities,
            ),
            (
              id: "beta",
              displayName: "Beta",
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.plugin,
              managementCapabilities: defaultManagementCapabilities,
            ),
          ],
        )..initialize(
          disabledPluginIds: const {},
          setupById: const {"alpha": PluginSetupReady(), "beta": PluginSetupReady()},
        );
    addTearDown(() async {
      await service.dispose();
      await runtime.dispose();
    });
    final snapshotTokens = <String>[];
    final subscription = service.managementSnapshotTokens.listen(snapshotTokens.add);
    addTearDown(subscription.cancel);
    final initialToken = service.managementSnapshot.snapshotToken;
    await Future<void>.delayed(Duration.zero);

    runtime.emitRuntimeState(
      pluginId: "alpha",
      state: PluginRuntimeState.starting,
      transition: PluginRuntimeTransition.starting,
    );

    expect(service.managementSnapshot.plugins.first.runtimeState, shared.PluginRuntimeState.starting);
    expect(snapshotTokens, hasLength(1));
    expect(service.managementSnapshot.snapshotToken, snapshotTokens.last);

    runtime.emitRuntimeState(pluginId: "beta", state: PluginRuntimeState.degraded);

    expect(service.managementSnapshot.plugins.last.runtimeState, shared.PluginRuntimeState.degraded);
    expect(snapshotTokens, hasLength(2));
    expect(service.managementSnapshot.snapshotToken, snapshotTokens.last);

    runtime.emitRuntimeState(pluginId: "alpha", state: PluginRuntimeState.active);

    expect(service.managementSnapshot.plugins.first.runtimeState, shared.PluginRuntimeState.active);
    expect(snapshotTokens, hasLength(3));
    expect(service.managementSnapshot.snapshotToken, snapshotTokens.last);
    expect({initialToken, ...snapshotTokens}, hasLength(4));
  });

  test("unsupported per-plugin timeout updates fail before settings or runtime effects", () async {
    final repository = _IdleLifecycleRepository();
    final settingsRepository = _MutableBridgeSettingsRepository(
      settings: const BridgeSettings(
        plugins: BridgePluginSettings(
          settingsByPluginId: {
            "one": PluginLifecycleSettings(idleTimeoutMins: 15),
          },
        ),
      ),
    );
    final timerScheduler = _ControllablePluginIdleTimerScheduler();
    final service = _singleIdleService(
      lifecycleRepository: repository,
      settingsRepository: settingsRepository,
      timerScheduler: timerScheduler,
      residencyPolicy: PluginResidencyPolicy.transient,
      managementCapabilities: const {PluginControlCapability.setupRefresh},
    );
    addTearDown(() async {
      await service.dispose();
      await repository.dispose();
    });
    final unsupportedConflict = isA<PluginManagementConflictException>()
        .having((error) => error.conflict.pluginId, "pluginId", "one")
        .having(
          (error) => error.conflict.reasons,
          "reasons",
          const [PluginLifecycleConflictReason.unsupported],
        );

    for (final request in const <PluginIdleTimeoutUpdateRequest>[
      PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "one", idleTimeoutMins: 45),
      PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "one"),
    ]) {
      await expectLater(
        Future<PluginManagementResponse>.sync(
          () => service.updateIdleTimeout(request: request),
        ),
        throwsA(unsupportedConflict),
      );
    }

    expect(settingsRepository.loadCalls, isZero);
    expect(settingsRepository.settings.plugins.settingsByPluginId["one"]?.idleTimeoutMins, 15);
    expect(timerScheduler.timers, isEmpty);
    expect(repository.stopCalls, isZero);
  });

  test("apply-all updates the default and clears only timeout-capable overrides", () async {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["managed", "external"]);
    final settingsRepository = _MutableBridgeSettingsRepository(
      settings: const BridgeSettings(
        plugins: BridgePluginSettings(
          defaults: PluginLifecycleSettings(idleTimeoutMins: 10),
          settingsByPluginId: {
            "managed": PluginLifecycleSettings(idleTimeoutMins: 20),
            "external": PluginLifecycleSettings(idleTimeoutMins: 25),
          },
        ),
      ),
    );
    final service =
        PluginLifecycleService(
            lifecycleRepository: PluginLifecycleRepository(runtime: runtime),
            preferredDefaultPluginId: legacyMissingPluginId,
            bridgeSettingsRepository: settingsRepository,
            idleTimerScheduler: const PluginIdleTimerScheduler(),
            bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
          )
          ..registerPlugins(
            plugins: const [
              (
                id: "managed",
                displayName: "Managed",
                residencyPolicy: PluginResidencyPolicy.transient,
                sessionOptionsScope: PluginSessionOptionsScope.project,
                managementCapabilities: {PluginControlCapability.idleTimeout},
              ),
              (
                id: "external",
                displayName: "External",
                residencyPolicy: PluginResidencyPolicy.transient,
                sessionOptionsScope: PluginSessionOptionsScope.plugin,
                managementCapabilities: {PluginControlCapability.setupRefresh},
              ),
            ],
          )
          ..initialize(
            disabledPluginIds: const {},
            setupById: const {
              "managed": PluginSetupReady(),
              "external": PluginSetupReady(),
            },
          );
    addTearDown(() async {
      await service.dispose();
      await runtime.dispose();
    });

    final response = await service.updateIdleTimeout(
      request: const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 30),
    );
    final responseById = {for (final plugin in response.plugins) plugin.setup.id: plugin};

    expect(response.defaultIdleTimeoutMins, 30);
    expect(settingsRepository.settings.plugins.defaults.idleTimeoutMins, 30);
    expect(settingsRepository.settings.plugins.settingsByPluginId, isNot(contains("managed")));
    expect(settingsRepository.settings.plugins.settingsByPluginId["external"]?.idleTimeoutMins, 25);
    expect(responseById["managed"]?.idleTimeoutMins, 30);
    expect(responseById["managed"]?.hasIdleTimeoutOverride, isFalse);
    expect(responseById["external"]?.idleTimeoutMins, 25);
    expect(responseById["external"]?.hasIdleTimeoutOverride, isTrue);
  });

  test("idle timeout writes serialize and preserve unknown plugin settings", () async {
    final repository = _IdleLifecycleRepository();
    addTearDown(repository.dispose);
    final settingsRepository = _MutableBridgeSettingsRepository(
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
    )..saveGate = Completer<void>();
    final service = _singleIdleService(
      lifecycleRepository: repository,
      settingsRepository: settingsRepository,
      timerScheduler: _ControllablePluginIdleTimerScheduler(),
      residencyPolicy: PluginResidencyPolicy.transient,
    );
    addTearDown(service.dispose);
    final snapshotTokens = <String>[];
    final subscription = service.managementSnapshotTokens.listen(snapshotTokens.add);
    addTearDown(subscription.cancel);

    final applyAll = service.updateIdleTimeout(
      request: const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 30),
    );
    await settingsRepository.saveStarted.future;
    final setOverride = service.updateIdleTimeout(
      request: const PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "one", idleTimeoutMins: -1),
    );
    await Future<void>.delayed(Duration.zero);

    expect(settingsRepository.loadCalls, 1);
    settingsRepository.saveGate!.complete();
    final responses = await Future.wait([applyAll, setOverride]);

    expect(responses.first.defaultIdleTimeoutMins, 30);
    expect(responses.first.plugins.single.hasIdleTimeoutOverride, isFalse);
    expect(responses.last.plugins.single.idleTimeoutMins, -1);
    expect(responses.last.plugins.single.hasIdleTimeoutOverride, isTrue);
    expect(settingsRepository.loadCalls, 2);
    expect(settingsRepository.settings.plugins.settingsByPluginId["one"]?.idleTimeoutMins, -1);
    expect(settingsRepository.settings.plugins.toJson()["future-plugin"], {
      "futureOption": "unknown-kept",
      "idleTimeoutMins": 7,
    });
    expect(snapshotTokens, hasLength(2));
    expect(service.managementSnapshot.snapshotToken, snapshotTokens.last);
    expect(
      () => service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "missing"),
      ),
      throwsA(isA<PluginManagementPluginNotFoundException>()),
    );
  });

  test("queued idle timeout writes fail closed after bridge identity is revoked", () async {
    final repository = _IdleLifecycleRepository();
    addTearDown(repository.dispose);
    final settingsRepository = _MutableBridgeSettingsRepository(settings: const BridgeSettings())
      ..saveGate = Completer<void>();
    final bridgeIdProvider = FakeBridgeIdProvider("br_test1234");
    final service =
        PluginLifecycleService(
            lifecycleRepository: repository,
            preferredDefaultPluginId: legacyMissingPluginId,
            bridgeSettingsRepository: settingsRepository,
            idleTimerScheduler: const PluginIdleTimerScheduler(),
            bridgeIdProvider: bridgeIdProvider,
          )
          ..registerPlugins(
            plugins: const [
              (
                id: "one",
                displayName: "One",
                residencyPolicy: PluginResidencyPolicy.transient,
                sessionOptionsScope: PluginSessionOptionsScope.project,
                managementCapabilities: defaultManagementCapabilities,
              ),
            ],
          )
          ..initialize(
            disabledPluginIds: const {},
            setupById: const {"one": PluginSetupReady()},
          );
    addTearDown(service.dispose);

    final active = service.updateIdleTimeout(
      request: const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 30),
    );
    await settingsRepository.saveStarted.future;
    final queued = service.updateIdleTimeout(
      request: const PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "one", idleTimeoutMins: 45),
    );
    bridgeIdProvider.id = null;
    final activeExpectation = expectLater(active, throwsA(isA<PluginManagementMutationOutcomeUncertainException>()));
    final queuedExpectation = expectLater(queued, throwsStateError);
    settingsRepository.saveGate!.complete();

    await Future.wait([activeExpectation, queuedExpectation]);
    expect(settingsRepository.loadCalls, 1);
    expect(settingsRepository.settings.plugins.defaults.idleTimeoutMins, 30);
    expect(settingsRepository.settings.plugins.settingsByPluginId, isEmpty);
  });

  test("successful timeout writes resync live timers while failed writes change nothing", () async {
    final repository = _IdleLifecycleRepository();
    addTearDown(repository.dispose);
    final settingsRepository = _MutableBridgeSettingsRepository(settings: const BridgeSettings());
    final timerScheduler = _ControllablePluginIdleTimerScheduler();
    final service = _singleIdleService(
      lifecycleRepository: repository,
      settingsRepository: settingsRepository,
      timerScheduler: timerScheduler,
      residencyPolicy: PluginResidencyPolicy.transient,
    );
    addTearDown(service.dispose);
    repository.publish(workState: PluginWorkState.idle, leaseCount: 0);
    await _waitFor(() => timerScheduler.timers.length == 1);
    final initialTimer = timerScheduler.timers.single;
    final snapshotTokens = <String>[];
    final subscription = service.managementSnapshotTokens.listen(snapshotTokens.add);
    addTearDown(subscription.cancel);

    final response = await service.updateIdleTimeout(
      request: const PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "one", idleTimeoutMins: 25),
    );

    expect(initialTimer.isActive, isFalse);
    expect(timerScheduler.timers.last.duration, const Duration(minutes: 25));
    expect(timerScheduler.timers.last.isActive, isTrue);
    expect(response.plugins.single.idleTimeoutMins, 25);
    expect(snapshotTokens, hasLength(1));

    final cleared = await service.updateIdleTimeout(
      request: const PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "one"),
    );

    expect(timerScheduler.timers[1].isActive, isFalse);
    expect(timerScheduler.timers.last.duration, const Duration(minutes: defaultPluginIdleTimeoutMins));
    expect(timerScheduler.timers.last.isActive, isTrue);
    expect(cleared.plugins.single.idleTimeoutMins, defaultPluginIdleTimeoutMins);
    expect(cleared.plugins.single.hasIdleTimeoutOverride, isFalse);
    expect(snapshotTokens, hasLength(2));
    final successfulToken = cleared.snapshotToken;

    settingsRepository.saveError = StateError("disk full");
    await expectLater(
      service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "one", idleTimeoutMins: 40),
      ),
      throwsA(isA<StateError>()),
    );

    expect(
      settingsRepository.settings.plugins.idleTimeoutMinsFor(pluginId: "one"),
      defaultPluginIdleTimeoutMins,
    );
    expect(timerScheduler.timers, hasLength(3));
    expect(timerScheduler.timers.last.isActive, isTrue);
    expect(service.managementSnapshot.snapshotToken, successfulToken);
    expect(service.managementSnapshot.plugins.single.idleTimeoutMins, defaultPluginIdleTimeoutMins);
    expect(snapshotTokens, hasLength(2));

    settingsRepository.saveError = null;
    final recovered = await service.updateIdleTimeout(
      request: const PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "one", idleTimeoutMins: 15),
    );

    expect(recovered.plugins.single.idleTimeoutMins, 15);
    expect(timerScheduler.timers, hasLength(4));
    expect(timerScheduler.timers.last.duration, const Duration(minutes: 15));
    expect(snapshotTokens, hasLength(3));
  });

  test("resident plugins persist timeout edits while retaining effective zero", () async {
    final repository = _IdleLifecycleRepository();
    addTearDown(repository.dispose);
    final settingsRepository = _MutableBridgeSettingsRepository(
      settings: const BridgeSettings(
        plugins: BridgePluginSettings(
          settingsByPluginId: {
            "one": PluginLifecycleSettings(idleTimeoutMins: 45),
          },
        ),
      ),
    );
    final timerScheduler = _ControllablePluginIdleTimerScheduler();
    final service = _singleIdleService(
      lifecycleRepository: repository,
      settingsRepository: settingsRepository,
      timerScheduler: timerScheduler,
      residencyPolicy: PluginResidencyPolicy.resident,
    );
    addTearDown(service.dispose);
    repository.publish(workState: PluginWorkState.idle, leaseCount: 0);

    final response = await service.updateIdleTimeout(
      request: const PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "one", idleTimeoutMins: 20),
    );

    expect(settingsRepository.settings.plugins.settingsByPluginId["one"]?.idleTimeoutMins, 20);
    expect(response.plugins.single.idleTimeoutMins, 0);
    expect(response.plugins.single.hasIdleTimeoutOverride, isTrue);
    expect(timerScheduler.timers, isEmpty);
  });

  test("idle suspension requires lifecycle and idle-timeout capabilities", () async {
    final repository = _IdleLifecycleRepository();
    final settingsRepository = _MutableBridgeSettingsRepository(settings: const BridgeSettings());
    final timerScheduler = _ControllablePluginIdleTimerScheduler();
    final service = _singleIdleService(
      lifecycleRepository: repository,
      settingsRepository: settingsRepository,
      timerScheduler: timerScheduler,
      residencyPolicy: PluginResidencyPolicy.transient,
      managementCapabilities: const {PluginControlCapability.setupRefresh},
    );
    addTearDown(() async {
      await service.dispose();
      await repository.dispose();
    });

    repository.publish(workState: PluginWorkState.idle, leaseCount: 0);

    expect(timerScheduler.timers, isEmpty);
    expect(repository.stopCalls, isZero);
  });

  test("unsupported lifecycle commands fail before runtime or settings effects", () async {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupReady(),
      inspectionGate: null,
      startFailureMessage: null,
    );
    final settingsRepository = _MutableBridgeSettingsRepository(settings: const BridgeSettings());
    final service =
        _commandService(
          repository: repository,
          settingsRepository: settingsRepository,
          managementCapabilities: const {PluginControlCapability.setupRefresh},
        )..initialize(
          disabledPluginIds: const {},
          setupById: const {"one": PluginSetupReady()},
        );
    addTearDown(() async {
      await service.dispose();
      await repository.dispose();
    });
    final unsupportedConflict = isA<PluginManagementConflictException>().having(
      (error) => error.conflict.reasons,
      "reasons",
      const [PluginLifecycleConflictReason.unsupported],
    );

    for (final request in const <PluginLifecycleCommandRequest>[
      PluginLifecycleCommandRequest.enable(),
      PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
      PluginLifecycleCommandRequest.restart(mode: PluginStopMode.force),
    ]) {
      await expectLater(
        Future<PluginManagementResponse>.sync(
          () => service.command(pluginId: "one", request: request),
        ),
        throwsA(unsupportedConflict),
      );
    }

    expect(repository.inspectCalls, isZero);
    expect(repository.startCalls, isZero);
    expect(repository.restartCalls, isZero);
    expect(repository.prepareDisableCalls, isZero);
    expect(repository.snapshot.single.state, PluginRuntimeState.dormant);
    expect(settingsRepository.loadCalls, isZero);
    expect(settingsRepository.settings, const BridgeSettings());
  });

  test("setup refresh remains allowed without lifecycle capability", () async {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupReady(),
      inspectionGate: null,
      startFailureMessage: null,
    );
    final settingsRepository = _MutableBridgeSettingsRepository(settings: const BridgeSettings());
    final service =
        _commandService(
          repository: repository,
          settingsRepository: settingsRepository,
          managementCapabilities: const {PluginControlCapability.setupRefresh},
        )..initialize(
          disabledPluginIds: const {},
          setupById: const {"one": PluginSetupRuntimeMissing(actionHint: "Install")},
        );
    addTearDown(() async {
      await service.dispose();
      await repository.dispose();
    });

    final response = await service.command(
      pluginId: "one",
      request: const PluginLifecycleCommandRequest.refresh(),
    );

    expect(repository.inspectCalls, 1);
    expect(repository.startCalls, isZero);
    expect(repository.restartCalls, isZero);
    expect(repository.prepareDisableCalls, isZero);
    expect(settingsRepository.loadCalls, isZero);
    expect(response.plugins.single.setup.state, PluginSetupState.ready);
  });

  test("disable commits durable eligibility and equal commands join", () async {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["one"]);
    final settingsRepository = _MutableBridgeSettingsRepository(settings: const BridgeSettings())
      ..saveGate = Completer<void>();
    final service =
        PluginLifecycleService(
            lifecycleRepository: PluginLifecycleRepository(runtime: runtime),
            preferredDefaultPluginId: legacyMissingPluginId,
            bridgeSettingsRepository: settingsRepository,
            idleTimerScheduler: const PluginIdleTimerScheduler(),
            bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
          )
          ..registerPlugins(
            plugins: const [
              (
                id: "one",
                displayName: "One",
                residencyPolicy: PluginResidencyPolicy.transient,
                sessionOptionsScope: PluginSessionOptionsScope.project,
                managementCapabilities: defaultManagementCapabilities,
              ),
            ],
          )
          ..initialize(
            disabledPluginIds: const {},
            setupById: const {"one": PluginSetupReady()},
          );
    addTearDown(() async {
      await service.dispose();
      await runtime.dispose();
    });
    const request = PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe);
    final initialToken = service.managementSnapshot.snapshotToken;

    final first = service.command(pluginId: "one", request: request);
    await settingsRepository.saveStarted.future;
    final joined = service.command(pluginId: "one", request: request);

    expect(settingsRepository.loadCalls, 1);
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.stopping);
    expect(service.managementSnapshot.snapshotToken, isNot(initialToken));
    expect(service.managementSnapshot.plugins.single.runtimeState, shared.PluginRuntimeState.stopping);
    settingsRepository.saveGate!.complete();
    final responses = await Future.wait([first, joined]);

    expect(responses[0], responses[1]);
    expect(responses.last.defaultPluginId, isNull);
    expect(responses.last.plugins.single.runtimeState, shared.PluginRuntimeState.disabled);
    expect(settingsRepository.settings.plugins.isDisabled(pluginId: "one"), isTrue);
    expect(runtime.snapshot.single.state, PluginRuntimeState.disabled);
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.none);
    expect(service.compositionView.eligiblePluginIds, isEmpty);
  });

  test("a different disable mode conflicts while a command is active", () async {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["one"]);
    final settingsRepository = _MutableBridgeSettingsRepository(settings: const BridgeSettings())
      ..saveGate = Completer<void>();
    final service =
        PluginLifecycleService(
            lifecycleRepository: PluginLifecycleRepository(runtime: runtime),
            preferredDefaultPluginId: legacyMissingPluginId,
            bridgeSettingsRepository: settingsRepository,
            idleTimerScheduler: const PluginIdleTimerScheduler(),
            bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
          )
          ..registerPlugins(
            plugins: const [
              (
                id: "one",
                displayName: "One",
                residencyPolicy: PluginResidencyPolicy.transient,
                sessionOptionsScope: PluginSessionOptionsScope.project,
                managementCapabilities: defaultManagementCapabilities,
              ),
            ],
          )
          ..initialize(
            disabledPluginIds: const {},
            setupById: const {"one": PluginSetupReady()},
          );
    addTearDown(() async {
      await service.dispose();
      await runtime.dispose();
    });
    final safe = service.command(
      pluginId: "one",
      request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
    );
    await settingsRepository.saveStarted.future;

    expect(
      () => service.command(
        pluginId: "one",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
      ),
      throwsA(
        isA<PluginManagementConflictException>().having(
          (error) => error.conflict.reasons,
          "reasons",
          [PluginLifecycleConflictReason.transitioning],
        ),
      ),
    );

    settingsRepository.saveGate!.complete();
    await safe;
  });

  test("command completion marks identity loss after dispatch as uncertain without hanging", () async {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["one"]);
    final settingsRepository = _MutableBridgeSettingsRepository(settings: const BridgeSettings())
      ..saveGate = Completer<void>();
    final bridgeIdProvider = FakeBridgeIdProvider("br_test1234");
    final service =
        PluginLifecycleService(
            lifecycleRepository: PluginLifecycleRepository(runtime: runtime),
            preferredDefaultPluginId: legacyMissingPluginId,
            bridgeSettingsRepository: settingsRepository,
            idleTimerScheduler: const PluginIdleTimerScheduler(),
            bridgeIdProvider: bridgeIdProvider,
          )
          ..registerPlugins(
            plugins: const [
              (
                id: "one",
                displayName: "One",
                residencyPolicy: PluginResidencyPolicy.transient,
                sessionOptionsScope: PluginSessionOptionsScope.project,
                managementCapabilities: defaultManagementCapabilities,
              ),
            ],
          )
          ..initialize(
            disabledPluginIds: const {},
            setupById: const {"one": PluginSetupReady()},
          );
    addTearDown(() async {
      await service.dispose();
      await runtime.dispose();
    });

    final response = service.command(
      pluginId: "one",
      request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
    );
    await settingsRepository.saveStarted.future;
    bridgeIdProvider.id = null;
    settingsRepository.saveGate!.complete();

    await expectLater(response, throwsA(isA<PluginManagementMutationOutcomeUncertainException>()));
  });

  test("failed disable persistence rolls runtime access back and allows retry", () async {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["one"]);
    final settingsRepository = _MutableBridgeSettingsRepository(settings: const BridgeSettings())
      ..saveError = StateError("disk full");
    final service =
        PluginLifecycleService(
            lifecycleRepository: PluginLifecycleRepository(runtime: runtime),
            preferredDefaultPluginId: legacyMissingPluginId,
            bridgeSettingsRepository: settingsRepository,
            idleTimerScheduler: const PluginIdleTimerScheduler(),
            bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
          )
          ..registerPlugins(
            plugins: const [
              (
                id: "one",
                displayName: "One",
                residencyPolicy: PluginResidencyPolicy.transient,
                sessionOptionsScope: PluginSessionOptionsScope.project,
                managementCapabilities: defaultManagementCapabilities,
              ),
            ],
          )
          ..initialize(
            disabledPluginIds: const {},
            setupById: const {"one": PluginSetupReady()},
          );
    addTearDown(() async {
      await service.dispose();
      await runtime.dispose();
    });
    const request = PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force);

    await expectLater(
      service.command(pluginId: "one", request: request),
      throwsA(isA<PluginManagementCommandFailedException>()),
    );

    expect(settingsRepository.settings.plugins.isDisabled(pluginId: "one"), isFalse);
    expect(runtime.snapshot.single.state, PluginRuntimeState.dormant);
    expect(runtime.snapshot.single.eligible, isTrue);
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.none);
    expect(service.compositionView.eligiblePluginIds, ["one"]);
    expect(service.managementSnapshot.plugins.single.runtimeState, shared.PluginRuntimeState.dormant);

    settingsRepository.saveError = null;
    final recovered = await service.command(pluginId: "one", request: request);

    expect(recovered.plugins.single.runtimeState, shared.PluginRuntimeState.disabled);
  });

  test("failed runtime commit retains durable disabled eligibility", () async {
    final repository = _CommitFailingDisableLifecycleRepository();
    addTearDown(repository.dispose);
    final settingsRepository = _MutableBridgeSettingsRepository(settings: const BridgeSettings());
    final service = _singleIdleService(
      lifecycleRepository: repository,
      settingsRepository: settingsRepository,
      timerScheduler: _ControllablePluginIdleTimerScheduler(),
      residencyPolicy: PluginResidencyPolicy.transient,
    );
    addTearDown(service.dispose);

    await expectLater(
      service.command(
        pluginId: "one",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
      ),
      throwsA(isA<PluginManagementCommandFailedException>()),
    );

    expect(settingsRepository.settings.plugins.isDisabled(pluginId: "one"), isTrue);
    expect(repository.rollbackCalls, isZero);
    expect(repository.snapshot.single.accessGate, PluginRuntimeAccessGate.disabled);
    expect(repository.snapshot.single.transitionSettled, isTrue);
    expect(service.compositionView.eligiblePluginIds, isEmpty);

    final retry = await service.command(
      pluginId: "one",
      request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
    );
    expect(retry.plugins.single.runtimeState, shared.PluginRuntimeState.disabled);
  });

  test("safe disable conflicts map to the typed management response without writing settings", () async {
    final repository = _ConflictingDisableLifecycleRepository();
    addTearDown(repository.dispose);
    final settingsRepository = _MutableBridgeSettingsRepository(settings: const BridgeSettings());
    final service = _singleIdleService(
      lifecycleRepository: repository,
      settingsRepository: settingsRepository,
      timerScheduler: _ControllablePluginIdleTimerScheduler(),
      residencyPolicy: PluginResidencyPolicy.transient,
    );
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

    expect(settingsRepository.loadCalls, isZero);
  });

  test("equal commands join while a different same-plugin command conflicts", () async {
    final inspectionGate = Completer<void>();
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupReady(),
      inspectionGate: inspectionGate,
      startFailureMessage: null,
    );
    addTearDown(repository.dispose);
    final service = _commandService(repository: repository, settingsRepository: null)
      ..initialize(
        disabledPluginIds: const {},
        setupById: const {"one": PluginSetupReady()},
      );
    addTearDown(service.dispose);

    final first = service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.refresh());
    final joined = service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.refresh());
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

    inspectionGate.complete();
    final responses = await Future.wait([first, joined]);

    expect(responses[0], responses[1]);
    expect(repository.inspectCalls, 1);
  });

  test("enable persists eligibility, inspects setup, and starts only when ready", () async {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupRuntimeMissing(actionHint: "Install"),
      inspectionGate: null,
      startFailureMessage: null,
    );
    addTearDown(repository.dispose);
    final settingsRepository = _MutableBridgeSettingsRepository(
      settings: const BridgeSettings(
        plugins: BridgePluginSettings(disabledPluginIds: {"one"}),
      ),
    );
    final service = _commandService(repository: repository, settingsRepository: settingsRepository)
      ..initialize(
        disabledPluginIds: const {"one"},
        setupById: const {"one": PluginSetupNotInspected()},
      );
    addTearDown(service.dispose);

    final blocked = await service.command(
      pluginId: "one",
      request: const PluginLifecycleCommandRequest.enable(),
    );

    expect(settingsRepository.settings.plugins.isDisabled(pluginId: "one"), isFalse);
    expect(service.compositionView.eligiblePluginIds, ["one"]);
    expect(repository.inspectCalls, 1);
    expect(repository.startCalls, isZero);
    expect(blocked.plugins.single.setup.state, PluginSetupState.runtimeMissing);
    expect(blocked.plugins.single.runtimeState, shared.PluginRuntimeState.blocked);

    repository.inspectionResult = const PluginSetupReady();
    final ready = service.readyPluginIds.firstWhere((ids) => ids.contains("one"));
    final enabled = await service.command(
      pluginId: "one",
      request: const PluginLifecycleCommandRequest.enable(),
    );

    expect(await ready, ["one"]);
    expect(repository.startCalls, 1);
    expect(enabled.plugins.single.runtimeState, shared.PluginRuntimeState.active);
    expect(settingsRepository.loadCalls, 1);
  });

  test("failed enable start defers the ready id until a successful retry", () async {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupReady(),
      inspectionGate: null,
      startFailureMessage: "start failed",
    );
    addTearDown(repository.dispose);
    final service = _commandService(repository: repository, settingsRepository: null)
      ..initialize(
        disabledPluginIds: const {"one"},
        setupById: const {"one": PluginSetupNotInspected()},
      );
    addTearDown(service.dispose);
    final readyEvents = <List<String>>[];
    final readySubscription = service.readyPluginIds.listen(readyEvents.add);
    addTearDown(readySubscription.cancel);

    await expectLater(
      service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.enable()),
      throwsA(isA<PluginManagementCommandFailedException>()),
    );
    expect(readyEvents, everyElement(isNot(contains("one"))));

    await service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.refresh());
    expect(readyEvents, everyElement(isNot(contains("one"))));

    repository.startFailureMessage = null;
    await service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.enable());

    expect(readyEvents.last, ["one"]);
  });

  test("restart requires eligibility and does not replace a newly blocked plugin", () async {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupRuntimeMissing(actionHint: "Install"),
      inspectionGate: null,
      startFailureMessage: null,
    );
    addTearDown(repository.dispose);
    final service = _commandService(repository: repository, settingsRepository: null)
      ..initialize(
        disabledPluginIds: const {},
        setupById: const {"one": PluginSetupReady()},
      );
    addTearDown(service.dispose);

    final response = await service.command(
      pluginId: "one",
      request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.force),
    );

    expect(repository.restartCalls, isZero);
    expect(response.plugins.single.setup.state, PluginSetupState.runtimeMissing);
    expect(response.plugins.single.runtimeState, shared.PluginRuntimeState.blocked);

    repository.inspectionResult = const PluginSetupReady();
    final restarted = await service.command(
      pluginId: "one",
      request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.force),
    );

    expect(repository.restartCalls, 1);
    expect(restarted.plugins.single.runtimeState, shared.PluginRuntimeState.active);

    await service.command(
      pluginId: "one",
      request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
    );
    await expectLater(
      service.command(
        pluginId: "one",
        request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe),
      ),
      throwsA(
        isA<PluginManagementConflictException>().having(
          (error) => error.conflict.reasons,
          "reasons",
          [PluginLifecycleConflictReason.notEnabled],
        ),
      ),
    );
  });

  test("refresh updates setup and ready ids without starting the plugin", () async {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupReady(),
      inspectionGate: null,
      startFailureMessage: null,
    );
    addTearDown(repository.dispose);
    final service = _commandService(repository: repository, settingsRepository: null)
      ..initialize(
        disabledPluginIds: const {},
        setupById: const {"one": PluginSetupRuntimeMissing(actionHint: "Install")},
      );
    addTearDown(service.dispose);
    final ready = service.readyPluginIds.firstWhere((ids) => ids.contains("one"));

    final response = await service.command(
      pluginId: "one",
      request: const PluginLifecycleCommandRequest.refresh(),
    );

    expect(await ready, ["one"]);
    expect(repository.startCalls, isZero);
    expect(response.plugins.single.setup.state, PluginSetupState.ready);
    expect(response.plugins.single.runtimeState, shared.PluginRuntimeState.dormant);
  });

  test("runtime snapshots drive selectable metadata and derived default", () async {
    final alpha = _FakePluginApi(id: "alpha");
    final beta = _FakePluginApi(id: "beta");
    final runtime = createTestPluginRuntime(plugins: [beta, alpha]);
    addTearDown(runtime.dispose);
    final service = _service(
      runtime: runtime,
      plugins: const [
        (
          id: "beta",
          displayName: "Beta",
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.plugin,
          managementCapabilities: defaultManagementCapabilities,
        ),
        (
          id: "alpha",
          displayName: "Alpha",
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
        ),
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
      plugins: const [
        (
          id: "alpha",
          displayName: "Alpha",
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
        ),
      ],
    );
    addTearDown(service.dispose);

    expect(
      () => service.initialize(disabledPluginIds: const {}, setupById: const {}),
      throwsArgumentError,
    );
  });

  test("ready plugin ids replay setup-ready dormant plugins", () async {
    final repository = _IdleLifecycleRepository(initialState: PluginRuntimeState.dormant);
    addTearDown(repository.dispose);
    final service =
        PluginLifecycleService(
          lifecycleRepository: repository,
          preferredDefaultPluginId: legacyMissingPluginId,
          bridgeSettingsRepository: createTestBridgeSettingsRepository(),
          idleTimerScheduler: const PluginIdleTimerScheduler(),
          bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
        )..registerPlugins(
          plugins: const [
            (
              id: "one",
              displayName: "One",
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: defaultManagementCapabilities,
            ),
          ],
        );
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {},
      setupById: const {"one": PluginSetupReady()},
    );

    expect(await service.readyPluginIds.first, ["one"]);
    expect(service.selectableMetadataSnapshot.map((entry) => entry.id), ["one"]);
  });

  test("idle suspension requires every safe-stop gate and a full timeout", () async {
    final repository = _IdleLifecycleRepository();
    addTearDown(repository.dispose);
    final timerScheduler = _ControllablePluginIdleTimerScheduler();
    final service =
        PluginLifecycleService(
          lifecycleRepository: repository,
          preferredDefaultPluginId: legacyMissingPluginId,
          bridgeSettingsRepository: createTestBridgeSettingsRepository(),
          idleTimerScheduler: timerScheduler,
          bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
        )..registerPlugins(
          plugins: const [
            (
              id: "one",
              displayName: "One",
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: defaultManagementCapabilities,
            ),
          ],
        );
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {},
      setupById: const {"one": PluginSetupReady()},
    );

    repository.publish(workState: PluginWorkState.busy, leaseCount: 0);
    repository.publish(workState: PluginWorkState.idle, leaseCount: 1);
    repository.publish(workState: PluginWorkState.idle, leaseCount: 0, transitionSettled: false);
    await Future<void>.delayed(Duration.zero);
    expect(timerScheduler.timers, isEmpty);

    repository.publish(workState: PluginWorkState.idle, leaseCount: 0);
    await _waitFor(() => timerScheduler.timers.length == 1);
    expect(timerScheduler.timers.single.duration, const Duration(minutes: defaultPluginIdleTimeoutMins));
    timerScheduler.timers.single.elapse();
    await _waitFor(() => repository.stopCalls == 1);
  });

  test("non-positive idle timeout keeps a demanded plugin resident", () async {
    final repository = _IdleLifecycleRepository();
    addTearDown(repository.dispose);
    final timerScheduler = _ControllablePluginIdleTimerScheduler();
    final service =
        PluginLifecycleService(
          lifecycleRepository: repository,
          preferredDefaultPluginId: legacyMissingPluginId,
          bridgeSettingsRepository: createTestBridgeSettingsRepository(
            settings: const BridgeSettings(
              plugins: BridgePluginSettings(
                settingsByPluginId: {
                  "one": PluginLifecycleSettings(idleTimeoutMins: 0),
                },
              ),
            ),
          ),
          idleTimerScheduler: timerScheduler,
          bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
        )..registerPlugins(
          plugins: const [
            (
              id: "one",
              displayName: "One",
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: defaultManagementCapabilities,
            ),
          ],
        );
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

  test("resident policy overrides a positive timeout without rewriting settings", () async {
    final repository = _IdleLifecycleRepository();
    addTearDown(repository.dispose);
    final timerScheduler = _ControllablePluginIdleTimerScheduler();
    final settingsRepository = createTestBridgeSettingsRepository(
      settings: const BridgeSettings(
        plugins: BridgePluginSettings(
          settingsByPluginId: {
            "one": PluginLifecycleSettings(idleTimeoutMins: 45),
          },
        ),
      ),
    );
    final service =
        PluginLifecycleService(
          lifecycleRepository: repository,
          preferredDefaultPluginId: legacyMissingPluginId,
          bridgeSettingsRepository: settingsRepository,
          idleTimerScheduler: timerScheduler,
          bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
        )..registerPlugins(
          plugins: const [
            (
              id: "one",
              displayName: "One",
              residencyPolicy: PluginResidencyPolicy.resident,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: defaultManagementCapabilities,
            ),
          ],
        );
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {},
      setupById: const {"one": PluginSetupReady()},
    );

    repository.publish(workState: PluginWorkState.idle, leaseCount: 0);
    await Future<void>.delayed(Duration.zero);

    expect(timerScheduler.timers, isEmpty);
    expect(repository.stopCalls, isZero);
    expect(settingsRepository.currentSettings.plugins.idleTimeoutMinsFor(pluginId: "one"), 45);
  });
}

PluginLifecycleService _service({
  required PluginRuntime runtime,
  required List<RegisteredPluginMetadata> plugins,
}) {
  return PluginLifecycleService(
    lifecycleRepository: PluginLifecycleRepository(runtime: runtime),
    preferredDefaultPluginId: legacyMissingPluginId,
    bridgeSettingsRepository: createTestBridgeSettingsRepository(),
    idleTimerScheduler: const PluginIdleTimerScheduler(),
    bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
  )..registerPlugins(plugins: plugins);
}

PluginLifecycleService _singleIdleService({
  required PluginLifecycleRepository lifecycleRepository,
  required BridgeSettingsRepository settingsRepository,
  required PluginIdleTimerScheduler timerScheduler,
  required PluginResidencyPolicy residencyPolicy,
  Set<PluginControlCapability> managementCapabilities = defaultManagementCapabilities,
}) {
  return PluginLifecycleService(
      lifecycleRepository: lifecycleRepository,
      preferredDefaultPluginId: legacyMissingPluginId,
      bridgeSettingsRepository: settingsRepository,
      idleTimerScheduler: timerScheduler,
      bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
    )
    ..registerPlugins(
      plugins: [
        (
          id: "one",
          displayName: "One",
          residencyPolicy: residencyPolicy,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: managementCapabilities,
        ),
      ],
    )
    ..initialize(
      disabledPluginIds: const {},
      setupById: const {"one": PluginSetupReady()},
    );
}

PluginLifecycleService _commandService({
  required PluginLifecycleRepository repository,
  required BridgeSettingsRepository? settingsRepository,
  Set<PluginControlCapability> managementCapabilities = defaultManagementCapabilities,
}) {
  return PluginLifecycleService(
    lifecycleRepository: repository,
    preferredDefaultPluginId: legacyMissingPluginId,
    bridgeSettingsRepository: settingsRepository ?? createTestBridgeSettingsRepository(),
    idleTimerScheduler: const PluginIdleTimerScheduler(),
    bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
  )..registerPlugins(
    plugins: [
      (
        id: "one",
        displayName: "One",
        residencyPolicy: PluginResidencyPolicy.transient,
        sessionOptionsScope: PluginSessionOptionsScope.project,
        managementCapabilities: managementCapabilities,
      ),
    ],
  );
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
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _IdleLifecycleRepository implements PluginLifecycleRepository {
  _IdleLifecycleRepository({PluginRuntimeState initialState = PluginRuntimeState.active})
    : _current = [_snapshot(state: initialState, workState: PluginWorkState.unknown, leaseCount: 0)];

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

  @override
  Future<PluginRuntimeCommandResult> stopSafely({required String pluginId}) async {
    stopCalls++;
    _current = [
      _snapshot(state: PluginRuntimeState.dormant, workState: PluginWorkState.unknown, leaseCount: 0),
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
    PluginRuntimeAccessGate accessGate = PluginRuntimeAccessGate.enabled,
    bool startAllowed = true,
  }) {
    return PluginLifecycleSnapshot(
      pluginId: "one",
      projectOwnership: PluginProjectOwnership.native,
      setup: const PluginSetupReady(),
      accessGate: accessGate,
      startAllowed: startAllowed,
      state: state,
      workState: workState,
      leaseCount: leaseCount,
      transitionSettled: transitionSettled,
    );
  }
}

class _ConflictingDisableLifecycleRepository extends _IdleLifecycleRepository {
  @override
  Future<PluginRuntimeCommandResult> prepareDisable({
    required String pluginId,
    required PluginStopIntent intent,
  }) async {
    return PluginRuntimeCommandConflict(
      snapshot: PluginRuntimeSnapshot(
        pluginId: pluginId,
        projectOwnership: PluginProjectOwnership.native,
        setup: const PluginSetupReady(),
        accessGate: PluginRuntimeAccessGate.enabled,
        startAllowed: true,
        generation: 1,
        state: PluginRuntimeState.active,
        workState: PluginWorkState.busy,
        leaseCount: 0,
        transition: PluginRuntimeTransition.none,
      ),
      reasons: const [PluginRuntimeConflictReason.busy],
    );
  }
}

class _CommitFailingDisableLifecycleRepository extends _IdleLifecycleRepository {
  int rollbackCalls = 0;

  @override
  Future<PluginRuntimeCommandResult> prepareDisable({
    required String pluginId,
    required PluginStopIntent intent,
  }) async {
    return PluginRuntimeCommandCurrent(
      snapshot: PluginRuntimeSnapshot(
        pluginId: pluginId,
        projectOwnership: PluginProjectOwnership.native,
        setup: const PluginSetupReady(),
        accessGate: PluginRuntimeAccessGate.draining,
        startAllowed: true,
        generation: 1,
        state: PluginRuntimeState.stopping,
        workState: PluginWorkState.unknown,
        leaseCount: 0,
        transition: PluginRuntimeTransition.stopping,
      ),
    );
  }

  @override
  void commitDisable({required String pluginId}) {
    _current = [
      _IdleLifecycleRepository._snapshot(
        state: PluginRuntimeState.disabled,
        workState: PluginWorkState.unknown,
        leaseCount: 0,
        accessGate: PluginRuntimeAccessGate.disabled,
        startAllowed: false,
      ),
    ];
    _snapshots.add(snapshot);
    throw StateError("commit invariant failed");
  }

  @override
  void rollbackDisable({required String pluginId}) {
    rollbackCalls++;
  }
}

class _CommandLifecycleRepository implements PluginLifecycleRepository {
  _CommandLifecycleRepository({
    required this.inspectionResult,
    required this.inspectionGate,
    required this.startFailureMessage,
  });

  PluginSetupStatus inspectionResult;
  final Completer<void>? inspectionGate;
  String? startFailureMessage;
  final StreamController<List<PluginLifecycleSnapshot>> _snapshots = StreamController.broadcast(sync: true);
  PluginLifecycleSnapshot _current = const PluginLifecycleSnapshot(
    pluginId: "one",
    projectOwnership: PluginProjectOwnership.native,
    setup: PluginSetupNotInspected(),
    accessGate: PluginRuntimeAccessGate.disabled,
    startAllowed: false,
    state: PluginRuntimeState.disabled,
    workState: PluginWorkState.unknown,
    leaseCount: 0,
    transitionSettled: true,
  );
  int inspectCalls = 0;
  int startCalls = 0;
  int restartCalls = 0;
  int prepareDisableCalls = 0;

  @override
  List<PluginLifecycleSnapshot> get snapshot => [_current];

  @override
  Stream<List<PluginLifecycleSnapshot>> get snapshots => _snapshots.stream;

  @override
  void applyAccess({required Set<String> eligiblePluginIds, required Set<String> startAllowedPluginIds}) {
    final enabled = eligiblePluginIds.contains("one");
    final startAllowed = startAllowedPluginIds.contains("one");
    _current = _copySnapshot(
      setup: _current.setup,
      accessGate: enabled ? PluginRuntimeAccessGate.enabled : PluginRuntimeAccessGate.disabled,
      startAllowed: startAllowed,
      state: !enabled
          ? PluginRuntimeState.disabled
          : !startAllowed
          ? PluginRuntimeState.blocked
          : _current.state == PluginRuntimeState.active
          ? PluginRuntimeState.active
          : PluginRuntimeState.dormant,
      transitionSettled: true,
    );
    _publish();
  }

  @override
  Future<Map<String, PluginSetupStatus>> inspect({
    required Set<String> pluginIds,
    required bool markUnselectedNotInspected,
  }) async {
    inspectCalls++;
    await inspectionGate?.future;
    _current = _copySnapshot(
      setup: inspectionResult,
      accessGate: _current.accessGate,
      startAllowed: _current.startAllowed,
      state: _current.state,
      transitionSettled: true,
    );
    _publish();
    return {"one": inspectionResult};
  }

  @override
  Future<PluginRuntimeCommandResult> start({required String pluginId}) async {
    startCalls++;
    final failureMessage = startFailureMessage;
    if (failureMessage != null) {
      return PluginRuntimeCommandFailed(snapshot: _runtimeSnapshot(), message: failureMessage);
    }
    _current = _copySnapshot(
      setup: _current.setup,
      accessGate: _current.accessGate,
      startAllowed: _current.startAllowed,
      state: PluginRuntimeState.active,
      transitionSettled: true,
    );
    _publish();
    return PluginRuntimeCommandApplied(snapshot: _runtimeSnapshot());
  }

  @override
  Future<PluginRuntimeCommandResult> restart({
    required String pluginId,
    required PluginStopIntent intent,
  }) async {
    restartCalls++;
    return start(pluginId: pluginId);
  }

  @override
  Future<PluginRuntimeCommandResult> prepareDisable({
    required String pluginId,
    required PluginStopIntent intent,
  }) async {
    prepareDisableCalls++;
    _current = _copySnapshot(
      setup: _current.setup,
      accessGate: PluginRuntimeAccessGate.draining,
      startAllowed: _current.startAllowed,
      state: PluginRuntimeState.stopping,
      transitionSettled: false,
    );
    _publish();
    return PluginRuntimeCommandApplied(snapshot: _runtimeSnapshot());
  }

  @override
  void commitDisable({required String pluginId}) {
    _current = _copySnapshot(
      setup: _current.setup,
      accessGate: PluginRuntimeAccessGate.disabled,
      startAllowed: false,
      state: PluginRuntimeState.disabled,
      transitionSettled: true,
    );
    _publish();
  }

  @override
  void rollbackDisable({required String pluginId}) => throw UnsupportedError("unused");

  PluginLifecycleSnapshot _copySnapshot({
    required PluginSetupStatus setup,
    required PluginRuntimeAccessGate accessGate,
    required bool startAllowed,
    required PluginRuntimeState state,
    required bool transitionSettled,
  }) {
    return PluginLifecycleSnapshot(
      pluginId: "one",
      projectOwnership: PluginProjectOwnership.native,
      setup: setup,
      accessGate: accessGate,
      startAllowed: startAllowed,
      state: state,
      workState: PluginWorkState.unknown,
      leaseCount: 0,
      transitionSettled: transitionSettled,
    );
  }

  PluginRuntimeSnapshot _runtimeSnapshot() => PluginRuntimeSnapshot(
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

  void _publish() => _snapshots.add(snapshot);

  Future<void> dispose() => _snapshots.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MutableBridgeSettingsRepository implements BridgeSettingsRepository {
  _MutableBridgeSettingsRepository({required this.settings});

  BridgeSettings settings;
  Completer<void>? saveGate;
  Object? saveError;
  int loadCalls = 0;
  final Completer<void> saveStarted = Completer<void>();

  @override
  BridgeSettings get currentSettings => settings;

  @override
  Future<BridgeSettings> loadSettings() async {
    loadCalls++;
    return settings;
  }

  @override
  Future<BridgeSettings> mutateSettings({
    required BridgeSettings Function({required BridgeSettings current}) mutation,
  }) async {
    loadCalls++;
    final updated = mutation(current: settings);
    if (!saveStarted.isCompleted) saveStarted.complete();
    await saveGate?.future;
    final error = saveError;
    if (error != null) throw error;
    return settings = updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError("condition was not reached");
}
