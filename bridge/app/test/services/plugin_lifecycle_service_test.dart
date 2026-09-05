import "dart:async";

import "package:sesori_bridge/src/repositories/bridge_settings.dart";
import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/repositories/plugin_lifecycle_repository.dart";
import "package:sesori_bridge/src/runtime/plugin_runtime.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared show PluginRuntimeState;
import "package:sesori_shared/sesori_shared.dart" hide PluginRuntimeState;
import "package:test/test.dart";

import "../helpers/plugin_lifecycle_test_support.dart";
import "../helpers/plugin_runtime_test_support.dart";
import "../helpers/test_helpers.dart";

void main() {
  test("authentication joins, publishes state, reinspects, and starts when ready", () async {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupReady(),
      inspectionGate: null,
      startFailureMessage: null,
    );
    final service = _commandService(
      repository: repository,
      settingsRepository: null,
      managementCapabilities: const {PluginControlCapability.authentication},
    );
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {},
      setupById: const {"one": PluginSetupAuthenticationRequired(actionHint: "Sign in.")},
    );
    final progress = <PluginAuthenticationProgressUpdate>[];
    service.authenticationProgress.listen(progress.add);

    final first = service.authenticate(pluginId: "one");
    final joined = service.authenticate(pluginId: "one");
    expect(service.managementSnapshot.plugins.single.authenticationState, PluginAuthenticationState.inProgress);
    repository.authenticationEvents.add(
      PluginAuthenticationDeviceCodeChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    );

    expect(await first, await joined);
    expect(repository.authenticationCalls, 1);
    repository.authenticationEvents.add(const PluginAuthenticationCompleted());
    await repository.authenticationEvents.close();
    while (progress.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(progress.single.progress, const PluginAuthenticationProgress.completed());
    expect(repository.inspectCalls, 1);
    expect(repository.startCalls, 1);
    expect(service.managementSnapshot.plugins.single.authenticationState, PluginAuthenticationState.idle);
    expect(service.managementSnapshot.plugins.single.setup.state, PluginSetupState.ready);
  });

  test("authentication continuation maps active-generation outcomes and terminal cleanup", () async {
    final repository =
        _CommandLifecycleRepository(
            inspectionResult: const PluginSetupAuthenticationRequired(actionHint: "Sign in."),
            inspectionGate: null,
            startFailureMessage: null,
          )
          ..authenticationContinuationResult = const PluginRuntimeAuthenticationContinuationConflict(
            reason: PluginRuntimeAuthenticationContinuationConflictReason.wrongKind,
          );
    final service = _commandService(
      repository: repository,
      settingsRepository: null,
      managementCapabilities: const {PluginControlCapability.authentication},
    );
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {},
      setupById: const {"one": PluginSetupAuthenticationRequired(actionHint: "Sign in.")},
    );
    final challenge = service.authenticate(pluginId: "one");
    final redirectUri = Uri.parse("http://127.0.0.1/callback?code=code");

    await expectLater(
      service.submitAuthenticationRedirect(pluginId: "one", redirectUri: redirectUri),
      throwsA(
        isA<PluginAuthenticationContinuationConflictException>().having(
          (error) => error.reason,
          "reason",
          PluginAuthenticationContinuationConflictReason.wrongKind,
        ),
      ),
    );
    repository.authenticationEvents.add(
      PluginAuthenticationDeviceCodeChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    );
    await challenge;

    repository.authenticationContinuationResult = const PluginRuntimeAuthenticationContinuationConflict(
      reason: PluginRuntimeAuthenticationContinuationConflictReason.alreadySubmitted,
    );
    await expectLater(
      service.submitAuthenticationRedirect(pluginId: "one", redirectUri: redirectUri),
      throwsA(
        isA<PluginAuthenticationContinuationConflictException>().having(
          (error) => error.reason,
          "reason",
          PluginAuthenticationContinuationConflictReason.alreadySubmitted,
        ),
      ),
    );
    repository.authenticationContinuationResult = const PluginRuntimeAuthenticationContinuationConflict(
      reason: PluginRuntimeAuthenticationContinuationConflictReason.staleGeneration,
    );
    await expectLater(
      service.submitAuthenticationRedirect(pluginId: "one", redirectUri: redirectUri),
      throwsA(
        isA<PluginAuthenticationContinuationConflictException>().having(
          (error) => error.reason,
          "reason",
          PluginAuthenticationContinuationConflictReason.noActive,
        ),
      ),
    );
    repository.authenticationContinuationResult = const PluginRuntimeAuthenticationContinuationApplied();
    await service.submitAuthenticationRedirect(pluginId: "one", redirectUri: redirectUri);
    expect(repository.authenticationRedirects.map((request) => request.generation), everyElement(1));

    repository.authenticationEvents.add(const PluginAuthenticationFailed(message: "done"));
    await repository.authenticationEvents.close();
    while (service.managementSnapshot.plugins.single.authenticationState != PluginAuthenticationState.idle) {
      await Future<void>.delayed(Duration.zero);
    }
    await expectLater(
      service.submitAuthenticationRedirect(pluginId: "one", redirectUri: redirectUri),
      throwsA(
        isA<PluginAuthenticationContinuationConflictException>().having(
          (error) => error.reason,
          "reason",
          PluginAuthenticationContinuationConflictReason.noActive,
        ),
      ),
    );
  });

  test("authentication cancellation aborts upstream and emits cancelled", () async {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupAuthenticationRequired(actionHint: "Sign in."),
      inspectionGate: null,
      startFailureMessage: null,
    );
    final service = _commandService(
      repository: repository,
      settingsRepository: null,
      managementCapabilities: const {PluginControlCapability.authentication},
    );
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {},
      setupById: const {"one": PluginSetupAuthenticationRequired(actionHint: "Sign in.")},
    );
    final progress = <PluginAuthenticationProgressUpdate>[];
    service.authenticationProgress.listen(progress.add);
    final challenge = service.authenticate(pluginId: "one");
    repository.authenticationEvents.add(
      PluginAuthenticationDeviceCodeChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    );
    await challenge;

    await service.cancelAuthentication(pluginId: "one");

    expect(repository.authenticationAborted, isTrue);
    expect(progress.single.progress, const PluginAuthenticationProgress.cancelled());
    expect(service.managementSnapshot.plugins.single.authenticationState, PluginAuthenticationState.idle);
    await expectLater(
      service.submitAuthenticationRedirect(
        pluginId: "one",
        redirectUri: Uri.parse("http://127.0.0.1/callback?code=late"),
      ),
      throwsA(
        isA<PluginAuthenticationContinuationConflictException>().having(
          (error) => error.reason,
          "reason",
          PluginAuthenticationContinuationConflictReason.noActive,
        ),
      ),
    );
  });

  test("authentication cancellation remains cancelled when setup inspection fails", () async {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupAuthenticationRequired(actionHint: "Sign in."),
      inspectionGate: null,
      startFailureMessage: null,
    )..inspectionError = StateError("inspection failed");
    final service = _commandService(
      repository: repository,
      settingsRepository: null,
      managementCapabilities: const {PluginControlCapability.authentication},
    );
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {},
      setupById: const {"one": PluginSetupAuthenticationRequired(actionHint: "Sign in.")},
    );
    final progress = <PluginAuthenticationProgressUpdate>[];
    service.authenticationProgress.listen(progress.add);
    final started = service.authenticate(pluginId: "one");

    final cancelled = service.cancelAuthentication(pluginId: "one");
    await expectLater(started, throwsA(isA<PluginAuthenticationChallengeUnavailableException>()));
    await cancelled;

    expect(repository.authenticationAborted, isTrue);
    expect(progress.single.progress, const PluginAuthenticationProgress.cancelled());
  });

  test("authentication plugin failure message is replaced before wire progress", () async {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupAuthenticationRequired(actionHint: "Sign in."),
      inspectionGate: null,
      startFailureMessage: null,
    );
    final service = _commandService(
      repository: repository,
      settingsRepository: null,
      managementCapabilities: const {PluginControlCapability.authentication},
    );
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {},
      setupById: const {"one": PluginSetupAuthenticationRequired(actionHint: "Sign in.")},
    );
    final progress = <PluginAuthenticationProgressUpdate>[];
    service.authenticationProgress.listen(progress.add);
    final started = service.authenticate(pluginId: "one");
    repository.authenticationEvents
      ..add(
        PluginAuthenticationDeviceCodeChallenge(
          verificationUri: Uri.parse("https://auth.example/device"),
          userCode: "ABCD-EFGH",
        ),
      )
      ..add(const PluginAuthenticationFailed(message: "private workspace policy detail"));
    await started;
    await repository.authenticationEvents.close();
    while (progress.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(
      progress.single.progress,
      const PluginAuthenticationProgress.failed(
        message: "Authentication failed. Check the bridge logs for details.",
      ),
    );
  });

  test("authentication completion fails when authoritative setup stays blocked", () async {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupAuthenticationRequired(actionHint: "Sign in."),
      inspectionGate: null,
      startFailureMessage: null,
    );
    final service = _commandService(
      repository: repository,
      settingsRepository: null,
      managementCapabilities: const {PluginControlCapability.authentication},
    );
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {},
      setupById: const {"one": PluginSetupAuthenticationRequired(actionHint: "Sign in.")},
    );
    final progress = <PluginAuthenticationProgressUpdate>[];
    service.authenticationProgress.listen(progress.add);
    final challenge = service.authenticate(pluginId: "one");
    repository.authenticationEvents
      ..add(
        PluginAuthenticationDeviceCodeChallenge(
          verificationUri: Uri.parse("https://auth.example/device"),
          userCode: "ABCD-EFGH",
        ),
      )
      ..add(const PluginAuthenticationCompleted());
    await challenge;
    await repository.authenticationEvents.close();
    while (progress.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(progress.single.progress, isA<PluginAuthenticationFailedProgress>());
    expect(repository.startCalls, 0);
  });

  test("authentication rejects unsupported, unnecessary, and command-conflicting starts", () async {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupReady(),
      inspectionGate: Completer<void>(),
      startFailureMessage: null,
    );
    final unsupported = _commandService(repository: repository, settingsRepository: null)
      ..initialize(
        disabledPluginIds: const {},
        setupById: const {"one": PluginSetupAuthenticationRequired(actionHint: "Sign in.")},
      );
    addTearDown(unsupported.dispose);
    expect(
      () => unsupported.authenticate(pluginId: "one"),
      throwsA(
        isA<PluginAuthenticationConflictException>().having(
          (error) => error.conflict.reasons,
          "reasons",
          [PluginAuthenticationConflictReason.unsupported],
        ),
      ),
    );

    final ready = _commandService(
      repository: repository,
      settingsRepository: null,
      managementCapabilities: const {PluginControlCapability.authentication},
    )..initialize(disabledPluginIds: const {}, setupById: const {"one": PluginSetupReady()});
    addTearDown(ready.dispose);
    expect(
      () => ready.authenticate(pluginId: "one"),
      throwsA(
        isA<PluginAuthenticationConflictException>().having(
          (error) => error.conflict.reasons,
          "reasons",
          [PluginAuthenticationConflictReason.setupNotRequired],
        ),
      ),
    );

    final commandRepository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupAuthenticationRequired(actionHint: "Sign in."),
      inspectionGate: Completer<void>(),
      startFailureMessage: null,
    );
    final commandConflict =
        _commandService(
          repository: commandRepository,
          settingsRepository: null,
          managementCapabilities: const {
            PluginControlCapability.authentication,
            PluginControlCapability.setupRefresh,
          },
        )..initialize(
          disabledPluginIds: const {},
          setupById: const {"one": PluginSetupAuthenticationRequired(actionHint: "Sign in.")},
        );
    addTearDown(commandConflict.dispose);
    unawaited(commandConflict.command(pluginId: "one", request: const PluginLifecycleCommandRequest.refresh()));
    await Future<void>.delayed(Duration.zero);
    expect(
      () => commandConflict.authenticate(pluginId: "one"),
      throwsA(
        isA<PluginAuthenticationConflictException>().having(
          (error) => error.conflict.reasons,
          "reasons",
          [PluginAuthenticationConflictReason.inFlight],
        ),
      ),
    );
    commandRepository.inspectionGate!.complete();
  });

  test("rejects duplicate plugin ids during construction", () {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["one"]);
    addTearDown(runtime.dispose);
    const plugin = (
      id: "one",
      displayName: "One",
      activationPolicy: PluginActivationPolicy.onDemand,
      residencyPolicy: PluginResidencyPolicy.transient,
      sessionOptionsScope: PluginSessionOptionsScope.project,
      managementCapabilities: defaultManagementCapabilities,
      supportsPromptAttachments: false,
    );

    expect(
      () => _service(runtime: runtime, plugins: const [plugin, plugin]),
      throwsArgumentError,
    );
  });

  test("derives alphabetical eligibility and default from setup", () {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["zeta", "alpha", "beta"]);
    addTearDown(runtime.dispose);
    final service = _service(
      runtime: runtime,
      plugins: const [
        (
          id: "zeta",
          displayName: "Zeta",
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
        ),
        (
          id: "beta",
          displayName: "Beta",
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.plugin,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
        ),
        (
          id: "alpha",
          displayName: "Alpha",
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
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
    expect(policy.eagerPluginIds, isEmpty);
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

  test("eager plugins activate only when eligible and setup-ready", () {
    final runtime = createRegisteredTestPluginRuntime(pluginIds: const ["wombat", "xenon", "yeti", "zebra"]);
    addTearDown(runtime.dispose);
    final service = _service(
      runtime: runtime,
      plugins: const [
        (
          id: "zebra",
          displayName: "Zebra",
          activationPolicy: PluginActivationPolicy.eager,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
        ),
        (
          id: "yeti",
          displayName: "Yeti",
          activationPolicy: PluginActivationPolicy.eager,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
        ),
        (
          id: "xenon",
          displayName: "Xenon",
          activationPolicy: PluginActivationPolicy.eager,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.plugin,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
        ),
        (
          id: "wombat",
          displayName: "Wombat",
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
        ),
      ],
    );
    addTearDown(service.dispose);

    final policy = service.initialize(
      disabledPluginIds: const {"yeti"},
      setupById: const {
        "zebra": PluginSetupReady(),
        "yeti": PluginSetupReady(),
        "xenon": PluginSetupRuntimeMissing(actionHint: "Install Xenon."),
        "wombat": PluginSetupReady(),
      },
    );

    expect(policy.eagerPluginIds, ["zebra"]);
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
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
        ),
        (
          id: "opencode",
          displayName: "OpenCode",
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
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
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
        ),
        (
          id: "alpha",
          displayName: "Alpha",
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
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
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
        ),
        (
          id: "cursor",
          displayName: "Cursor",
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.plugin,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
        ),
      ],
    );
    addTearDown(service.dispose);
    service.initialize(
      disabledPluginIds: const {"cursor"},
      setupById: const {
        "cursor": PluginSetupNotInspected(),
        "opencode": PluginSetupAuthenticationRequired.versioned(
          actionHint: "Run opencode auth login.",
          runtimeVersion: "1.18.11",
        ),
      },
    );

    expect(
      service.setupSnapshot.plugins,
      [
        const PluginSetupMetadata(
          id: "cursor",
          displayName: "Cursor",
          state: PluginSetupState.notInspected,
          runtimeVersion: null,
          actionHint: null,
        ),
        const PluginSetupMetadata(
          id: "opencode",
          displayName: "OpenCode",
          state: PluginSetupState.authenticationRequired,
          runtimeVersion: "1.18.11",
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
          plugins: const [
            (
              id: "opencode",
              displayName: "OpenCode",
              activationPolicy: PluginActivationPolicy.onDemand,
              residencyPolicy: PluginResidencyPolicy.resident,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: defaultManagementCapabilities,
              supportsPromptAttachments: false,
            ),
            (
              id: "alpha",
              displayName: "Alpha",
              activationPolicy: PluginActivationPolicy.onDemand,
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: defaultManagementCapabilities,
              supportsPromptAttachments: false,
            ),
            (
              id: "beta",
              displayName: "Beta",
              activationPolicy: PluginActivationPolicy.onDemand,
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.plugin,
              managementCapabilities: defaultManagementCapabilities,
              supportsPromptAttachments: false,
            ),
          ],
        )..initialize(
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
    // Residency no longer zeroes the reported timeout: the configured value is
    // surfaced so resident plugins that consume it internally show the real knob.
    expect(opencode.idleTimeoutMins, 45);
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
    final service = PluginLifecycleService(
      lifecycleRepository: PluginLifecycleRepository(runtime: runtime),
      preferredDefaultPluginId: legacyMissingPluginId,
      bridgeSettingsRepository: settingsRepository,
      idleTimerScheduler: const PluginIdleTimerScheduler(),
      bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
      plugins: const [
        (
          id: "external",
          displayName: "External",
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.resident,
          sessionOptionsScope: PluginSessionOptionsScope.plugin,
          managementCapabilities: {PluginControlCapability.setupRefresh},
          supportsPromptAttachments: false,
        ),
        (
          id: "managed",
          displayName: "Managed",
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
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
              activationPolicy: PluginActivationPolicy.onDemand,
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: defaultManagementCapabilities,
              supportsPromptAttachments: false,
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
              activationPolicy: PluginActivationPolicy.onDemand,
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: defaultManagementCapabilities,
              supportsPromptAttachments: false,
            ),
            (
              id: "beta",
              displayName: "Beta",
              activationPolicy: PluginActivationPolicy.onDemand,
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.plugin,
              managementCapabilities: defaultManagementCapabilities,
              supportsPromptAttachments: false,
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
          plugins: const [
            (
              id: "managed",
              displayName: "Managed",
              activationPolicy: PluginActivationPolicy.onDemand,
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: {PluginControlCapability.idleTimeout},
              supportsPromptAttachments: false,
            ),
            (
              id: "external",
              displayName: "External",
              activationPolicy: PluginActivationPolicy.onDemand,
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.plugin,
              managementCapabilities: {PluginControlCapability.setupRefresh},
              supportsPromptAttachments: false,
            ),
          ],
        )..initialize(
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
          plugins: const [
            (
              id: "one",
              displayName: "One",
              activationPolicy: PluginActivationPolicy.onDemand,
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: defaultManagementCapabilities,
              supportsPromptAttachments: false,
            ),
          ],
        )..initialize(
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

  test("resident plugins persist timeout edits and report the configured value", () async {
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
    // The configured value is reported (a resident plugin may consume it for
    // internal reclamation via PluginHost.pluginIdleTimeout); only the
    // whole-plugin suspension timer stays disarmed.
    expect(response.plugins.single.idleTimeoutMins, 20);
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
          plugins: const [
            (
              id: "one",
              displayName: "One",
              activationPolicy: PluginActivationPolicy.onDemand,
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: defaultManagementCapabilities,
              supportsPromptAttachments: false,
            ),
          ],
        )..initialize(
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
          plugins: const [
            (
              id: "one",
              displayName: "One",
              activationPolicy: PluginActivationPolicy.onDemand,
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: defaultManagementCapabilities,
              supportsPromptAttachments: false,
            ),
          ],
        )..initialize(
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
          plugins: const [
            (
              id: "one",
              displayName: "One",
              activationPolicy: PluginActivationPolicy.onDemand,
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: defaultManagementCapabilities,
              supportsPromptAttachments: false,
            ),
          ],
        )..initialize(
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
          plugins: const [
            (
              id: "one",
              displayName: "One",
              activationPolicy: PluginActivationPolicy.onDemand,
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: defaultManagementCapabilities,
              supportsPromptAttachments: false,
            ),
          ],
        )..initialize(
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
    expect(runtime.snapshot.single.accessGate != PluginRuntimeAccessGate.disabled, isTrue);
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
    expect(repository.snapshot.single.transition, PluginRuntimeTransition.none);
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

  test("install streams progress, enables, re-inspects, and starts when ready", () async {
    final repository =
        _CommandLifecycleRepository(
            inspectionResult: const PluginSetupReady(),
            inspectionGate: null,
            startFailureMessage: null,
          )
          ..installEvents = const [
            ProvisionResolving(),
            ProvisionDownloading(receivedBytes: 10, totalBytes: 100),
            ProvisionVerifying(),
            ProvisionExtracting(),
            ProvisionReady(binaryPath: "/managed/one"),
          ];
    addTearDown(repository.dispose);
    final settingsRepository = _MutableBridgeSettingsRepository(
      settings: const BridgeSettings(
        plugins: BridgePluginSettings(disabledPluginIds: {"one"}),
      ),
    );
    final service =
        _commandService(
          repository: repository,
          settingsRepository: settingsRepository,
          managementCapabilities: installCapableManagementCapabilities,
        )..initialize(
          disabledPluginIds: const {"one"},
          setupById: const {"one": PluginSetupNotInspected()},
        );
    addTearDown(service.dispose);
    final progress = <PluginInstallProgressUpdate>[];
    final progressSubscription = service.installProgress.listen(progress.add);
    addTearDown(progressSubscription.cancel);

    final accepted = await service.command(
      pluginId: "one",
      request: const PluginLifecycleCommandRequest.install(),
    );
    expect(accepted.plugins.single.setup.state, PluginSetupState.notInspected);

    await installSettled(progress: progress);

    expect(repository.installCalls, 1);
    expect(repository.inspectCalls, 1);
    expect(repository.startCalls, 1);
    expect(settingsRepository.settings.plugins.isDisabled(pluginId: "one"), isFalse);
    expect(progress.map((update) => update.phase).toList(), const [
      PluginInstallPhase.downloading,
      PluginInstallPhase.verifying,
      PluginInstallPhase.extracting,
      PluginInstallPhase.finalizing,
      PluginInstallPhase.completed,
    ]);
    expect(progress.first.percent, 10);
  });

  test("a failed install reports a terminal failure without enabling the plugin", () async {
    final repository =
        _CommandLifecycleRepository(
            inspectionResult: const PluginSetupRuntimeMissing(actionHint: "Install"),
            inspectionGate: null,
            startFailureMessage: null,
          )
          ..installEvents = const [
            ProvisionResolving(),
            ProvisionFailed(message: "checksum verification failed"),
          ];
    addTearDown(repository.dispose);
    final settingsRepository = _MutableBridgeSettingsRepository(
      settings: const BridgeSettings(
        plugins: BridgePluginSettings(disabledPluginIds: {"one"}),
      ),
    );
    final service =
        _commandService(
          repository: repository,
          settingsRepository: settingsRepository,
          managementCapabilities: installCapableManagementCapabilities,
        )..initialize(
          disabledPluginIds: const {"one"},
          setupById: const {"one": PluginSetupNotInspected()},
        );
    addTearDown(service.dispose);
    final progress = <PluginInstallProgressUpdate>[];
    final progressSubscription = service.installProgress.listen(progress.add);
    addTearDown(progressSubscription.cancel);

    await service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.install());
    await installSettled(progress: progress);

    expect(progress.last.phase, PluginInstallPhase.failed);
    // The descriptor's failure text never reaches the wire.
    expect(progress.last.message, isNot(contains("checksum")));
    expect(repository.inspectCalls, isZero);
    expect(repository.startCalls, isZero);
    expect(settingsRepository.settings.plugins.isDisabled(pluginId: "one"), isTrue);
  });

  test("an installed runtime that is still setup-blocked does not report completed", () async {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupAuthenticationRequired(actionHint: "Log in"),
      inspectionGate: null,
      startFailureMessage: null,
    )..installEvents = const [ProvisionReady(binaryPath: "/managed/one")];
    addTearDown(repository.dispose);
    final service =
        _commandService(
          repository: repository,
          settingsRepository: null,
          managementCapabilities: installCapableManagementCapabilities,
        )..initialize(
          disabledPluginIds: const {"one"},
          setupById: const {"one": PluginSetupNotInspected()},
        );
    addTearDown(service.dispose);
    final progress = <PluginInstallProgressUpdate>[];
    final progressSubscription = service.installProgress.listen(progress.add);
    addTearDown(progressSubscription.cancel);

    await service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.install());
    await installSettled(progress: progress);

    expect(progress.map((update) => update.phase).toList(), const [
      PluginInstallPhase.finalizing,
      PluginInstallPhase.failed,
    ]);
    expect(repository.startCalls, isZero);
  });

  test("a duplicate install joins and a different command conflicts while installing", () async {
    final installGate = Completer<void>();
    final repository =
        _CommandLifecycleRepository(
            inspectionResult: const PluginSetupReady(),
            inspectionGate: null,
            startFailureMessage: null,
          )
          ..installEvents = const [ProvisionReady(binaryPath: "/managed/one")]
          ..installGate = installGate;
    addTearDown(repository.dispose);
    final service =
        _commandService(
          repository: repository,
          settingsRepository: null,
          managementCapabilities: installCapableManagementCapabilities,
        )..initialize(
          disabledPluginIds: const {},
          setupById: const {"one": PluginSetupNotInspected()},
        );
    addTearDown(service.dispose);
    final progress = <PluginInstallProgressUpdate>[];
    final progressSubscription = service.installProgress.listen(progress.add);
    addTearDown(progressSubscription.cancel);

    await service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.install());
    await service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.install());
    expect(repository.installCalls, 1);

    final conflict = isA<PluginManagementConflictException>().having(
      (error) => error.conflict.reasons,
      "reasons",
      [PluginLifecycleConflictReason.transitioning],
    );
    expect(
      () => service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.refresh()),
      throwsA(conflict),
    );

    installGate.complete();
    await installSettled(progress: progress);
    expect(repository.startCalls, 1);
  });

  test("startup upgrades only eligible plugins with a superseded managed runtime", () async {
    final installGate = Completer<void>();
    final repository =
        _CommandLifecycleRepository(
            inspectionResult: const PluginSetupReady(),
            inspectionGate: null,
            startFailureMessage: null,
          )
          ..installEvents = const [ProvisionReady(binaryPath: "/managed/one")]
          ..installGate = installGate
          ..needsUpgrade = true;
    addTearDown(repository.dispose);
    final service =
        _commandService(
          repository: repository,
          settingsRepository: null,
          managementCapabilities: installCapableManagementCapabilities,
        )..initialize(
          disabledPluginIds: const {},
          setupById: const {"one": PluginSetupReady()},
        );
    addTearDown(service.dispose);
    final progress = <PluginInstallProgressUpdate>[];
    final progressSubscription = service.installProgress.listen(progress.add);
    addTearDown(progressSubscription.cancel);

    // Returns synchronously: bridge startup must not wait on a download.
    service.upgradeManagedRuntimes();
    expect(repository.upgradeQueries, ["one"]);

    await Future<void>.delayed(Duration.zero);
    expect(repository.installCalls, 1);
    expect(progress, isEmpty, reason: "the install is admitted but still gated on the download");

    installGate.complete();
    await installSettled(progress: progress);
    expect(repository.startCalls, isZero, reason: "a startup upgrade never spawns a process");
    expect(progress.last.phase, PluginInstallPhase.completed);
  });

  test("startup skips a plugin whose descriptor reports no superseded runtime", () {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupReady(),
      inspectionGate: null,
      startFailureMessage: null,
    );
    addTearDown(repository.dispose);
    final service =
        _commandService(
          repository: repository,
          settingsRepository: null,
          managementCapabilities: installCapableManagementCapabilities,
        )..initialize(
          disabledPluginIds: const {},
          setupById: const {"one": PluginSetupReady()},
        );
    addTearDown(service.dispose);

    service.upgradeManagedRuntimes();

    expect(repository.upgradeQueries, ["one"]);
    expect(repository.installCalls, isZero);
  });

  test("startup does not ask a disabled plugin whether it needs an upgrade", () {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupReady(),
      inspectionGate: null,
      startFailureMessage: null,
    )..needsUpgrade = true;
    addTearDown(repository.dispose);
    final service =
        _commandService(
          repository: repository,
          settingsRepository: null,
          managementCapabilities: installCapableManagementCapabilities,
        )..initialize(
          disabledPluginIds: const {"one"},
          setupById: const {"one": PluginSetupReady()},
        );
    addTearDown(service.dispose);

    service.upgradeManagedRuntimes();

    expect(repository.upgradeQueries, isEmpty);
    expect(repository.installCalls, isZero);
  });

  test("a startup upgrade makes a blocked harness ready without starting it", () async {
    final repository =
        _CommandLifecycleRepository(
            inspectionResult: const PluginSetupReady(),
            inspectionGate: null,
            startFailureMessage: null,
          )
          ..installEvents = const [ProvisionReady(binaryPath: "/managed/one")]
          ..needsUpgrade = true;
    addTearDown(repository.dispose);
    final service =
        _commandService(
          repository: repository,
          settingsRepository: null,
          managementCapabilities: installCapableManagementCapabilities,
        )..initialize(
          disabledPluginIds: const {},
          setupById: const {"one": PluginSetupRuntimeMissing(actionHint: "This bridge needs a newer One.")},
        );
    addTearDown(service.dispose);
    final progress = <PluginInstallProgressUpdate>[];
    final progressSubscription = service.installProgress.listen(progress.add);
    addTearDown(progressSubscription.cancel);
    final ready = <List<String>>[];
    final readySubscription = service.readyPluginIds.listen(ready.add);
    addTearDown(readySubscription.cancel);

    service.upgradeManagedRuntimes();
    await installSettled(progress: progress);

    expect(repository.inspectCalls, 1);
    expect(repository.startCalls, isZero);
    expect(ready.last, ["one"]);
  });

  test("a failed startup upgrade leaves the previous setup in place", () async {
    final repository =
        _CommandLifecycleRepository(
            inspectionResult: const PluginSetupReady(),
            inspectionGate: null,
            startFailureMessage: null,
          )
          ..installEvents = const [ProvisionFailed(message: "download died")]
          ..needsUpgrade = true;
    addTearDown(repository.dispose);
    const priorSetup = PluginSetupReady.versioned(runtimeVersion: "1.0.0");
    final service =
        _commandService(
          repository: repository,
          settingsRepository: null,
          managementCapabilities: installCapableManagementCapabilities,
        )..initialize(
          disabledPluginIds: const {},
          setupById: const {"one": priorSetup},
        );
    addTearDown(service.dispose);
    final progress = <PluginInstallProgressUpdate>[];
    final progressSubscription = service.installProgress.listen(progress.add);
    addTearDown(progressSubscription.cancel);

    service.upgradeManagedRuntimes();
    await installSettled(progress: progress);

    expect(progress.single.phase, PluginInstallPhase.failed);
    expect(repository.inspectCalls, isZero, reason: "a failed upgrade must not re-inspect");
    expect(service.setupSnapshot.plugins.single.runtimeVersion, "1.0.0");
  });

  test("an explicit install joins a running startup upgrade and a refresh conflicts", () async {
    final installGate = Completer<void>();
    final repository =
        _CommandLifecycleRepository(
            inspectionResult: const PluginSetupReady(),
            inspectionGate: null,
            startFailureMessage: null,
          )
          ..installEvents = const [ProvisionReady(binaryPath: "/managed/one")]
          ..installGate = installGate
          ..needsUpgrade = true;
    addTearDown(repository.dispose);
    final service =
        _commandService(
          repository: repository,
          settingsRepository: null,
          managementCapabilities: installCapableManagementCapabilities,
        )..initialize(
          disabledPluginIds: const {},
          setupById: const {"one": PluginSetupReady()},
        );
    addTearDown(service.dispose);
    final progress = <PluginInstallProgressUpdate>[];
    final progressSubscription = service.installProgress.listen(progress.add);
    addTearDown(progressSubscription.cancel);

    service.upgradeManagedRuntimes();
    await service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.install());

    expect(repository.installCalls, 1, reason: "the explicit install joined the upgrade already in flight");
    expect(
      () => service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.refresh()),
      throwsA(
        isA<PluginManagementConflictException>().having(
          (error) => error.conflict.reasons,
          "reasons",
          [PluginLifecycleConflictReason.transitioning],
        ),
      ),
    );

    installGate.complete();
    await installSettled(progress: progress);
    expect(
      repository.startCalls,
      1,
      reason: "the explicit Install carries the user's intent to start, so it promotes the upgrade",
    );
  });

  test("a startup upgrade alone still does not start the harness", () async {
    final installGate = Completer<void>();
    final repository =
        _CommandLifecycleRepository(
            inspectionResult: const PluginSetupReady(),
            inspectionGate: null,
            startFailureMessage: null,
          )
          ..installEvents = const [ProvisionReady(binaryPath: "/managed/one")]
          ..installGate = installGate
          ..needsUpgrade = true;
    addTearDown(repository.dispose);
    final service =
        _commandService(
          repository: repository,
          settingsRepository: null,
          managementCapabilities: installCapableManagementCapabilities,
        )..initialize(
          disabledPluginIds: const {},
          setupById: const {"one": PluginSetupReady()},
        );
    addTearDown(service.dispose);
    final progress = <PluginInstallProgressUpdate>[];
    final progressSubscription = service.installProgress.listen(progress.add);
    addTearDown(progressSubscription.cancel);

    service.upgradeManagedRuntimes();
    installGate.complete();
    await installSettled(progress: progress);

    expect(repository.startCalls, isZero);
  });

  test("install requires the install capability", () async {
    final repository = _CommandLifecycleRepository(
      inspectionResult: const PluginSetupReady(),
      inspectionGate: null,
      startFailureMessage: null,
    );
    addTearDown(repository.dispose);
    final service = _commandService(repository: repository, settingsRepository: null)
      ..initialize(
        disabledPluginIds: const {},
        setupById: const {"one": PluginSetupNotInspected()},
      );
    addTearDown(service.dispose);

    expect(
      () => service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.install()),
      throwsA(
        isA<PluginManagementConflictException>().having(
          (error) => error.conflict.reasons,
          "reasons",
          [PluginLifecycleConflictReason.unsupported],
        ),
      ),
    );
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
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.plugin,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
        ),
        (
          id: "alpha",
          displayName: "Alpha",
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: true,
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
    expect(
      {
        for (final metadata in service.selectableMetadataSnapshot) metadata.id: metadata.supportsPromptAttachments,
      },
      {"alpha": true, "beta": false},
    );
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
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
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
    final service = PluginLifecycleService(
      lifecycleRepository: repository,
      preferredDefaultPluginId: legacyMissingPluginId,
      bridgeSettingsRepository: createTestBridgeSettingsRepository(),
      idleTimerScheduler: const PluginIdleTimerScheduler(),
      bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
      plugins: const [
        (
          id: "one",
          displayName: "One",
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
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
    final service = PluginLifecycleService(
      lifecycleRepository: repository,
      preferredDefaultPluginId: legacyMissingPluginId,
      bridgeSettingsRepository: createTestBridgeSettingsRepository(),
      idleTimerScheduler: timerScheduler,
      bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
      plugins: const [
        (
          id: "one",
          displayName: "One",
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
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
    repository.publish(
      workState: PluginWorkState.idle,
      leaseCount: 0,
      transition: PluginRuntimeTransition.stopping,
    );
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
    final service = PluginLifecycleService(
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
      plugins: const [
        (
          id: "one",
          displayName: "One",
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.transient,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
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
    final service = PluginLifecycleService(
      lifecycleRepository: repository,
      preferredDefaultPluginId: legacyMissingPluginId,
      bridgeSettingsRepository: settingsRepository,
      idleTimerScheduler: timerScheduler,
      bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
      plugins: const [
        (
          id: "one",
          displayName: "One",
          activationPolicy: PluginActivationPolicy.onDemand,
          residencyPolicy: PluginResidencyPolicy.resident,
          sessionOptionsScope: PluginSessionOptionsScope.project,
          managementCapabilities: defaultManagementCapabilities,
          supportsPromptAttachments: false,
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

const installCapableManagementCapabilities = <PluginControlCapability>{
  ...defaultManagementCapabilities,
  PluginControlCapability.install,
};

/// Completes when [progress] contains a terminal install event, then yields
/// once more so the service's finally-block cleanup runs. The caller must
/// subscribe its collector before issuing the install command.
Future<void> installSettled({required List<PluginInstallProgressUpdate> progress}) async {
  while (!progress.any(
    (update) => update.phase == PluginInstallPhase.completed || update.phase == PluginInstallPhase.failed,
  )) {
    await Future<void>.delayed(Duration.zero);
  }
  await Future<void>.delayed(Duration.zero);
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
    plugins: plugins,
  );
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
    plugins: [
      (
        id: "one",
        displayName: "One",
        activationPolicy: PluginActivationPolicy.onDemand,
        residencyPolicy: residencyPolicy,
        sessionOptionsScope: PluginSessionOptionsScope.project,
        managementCapabilities: managementCapabilities,
        supportsPromptAttachments: false,
      ),
    ],
  )..initialize(
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
    plugins: [
      (
        id: "one",
        displayName: "One",
        activationPolicy: PluginActivationPolicy.onDemand,
        residencyPolicy: PluginResidencyPolicy.transient,
        sessionOptionsScope: PluginSessionOptionsScope.project,
        managementCapabilities: managementCapabilities,
        supportsPromptAttachments: false,
      ),
    ],
  );
}

class _FakePluginApi({@override required final String id}) extends BridgeDerivedProjectsPluginApi {
  @override
  Stream<BridgeSseEvent> get events => const Stream.empty();

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _IdleLifecycleRepository({PluginRuntimeState initialState = PluginRuntimeState.active})
    implements PluginLifecycleRepository {
  final StreamController<List<PluginRuntimeSnapshot>> _snapshots = StreamController.broadcast(sync: true);
  List<PluginRuntimeSnapshot> _current = [
    _snapshot(state: initialState, workState: PluginWorkState.unknown, leaseCount: 0),
  ];
  int stopCalls = 0;

  @override
  Stream<List<PluginRuntimeSnapshot>> get snapshots => _snapshots.stream;

  @override
  List<PluginRuntimeSnapshot> get snapshot => List.unmodifiable(_current);

  @override
  void applyAccess({required Set<String> eligiblePluginIds, required Set<String> startAllowedPluginIds}) {}

  void publish({
    PluginRuntimeState state = PluginRuntimeState.active,
    required PluginWorkState workState,
    required int leaseCount,
    PluginRuntimeTransition transition = PluginRuntimeTransition.none,
  }) {
    _current = [
      _snapshot(
        state: state,
        workState: workState,
        leaseCount: leaseCount,
        transition: transition,
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

  static PluginRuntimeSnapshot _snapshot({
    PluginRuntimeState state = PluginRuntimeState.active,
    required PluginWorkState workState,
    required int leaseCount,
    PluginRuntimeTransition transition = PluginRuntimeTransition.none,
    PluginRuntimeAccessGate accessGate = PluginRuntimeAccessGate.enabled,
    bool startAllowed = true,
  }) {
    return PluginRuntimeSnapshot(
      pluginId: "one",
      projectOwnership: PluginProjectOwnership.native,
      setup: const PluginSetupReady(),
      accessGate: accessGate,
      startAllowed: startAllowed,
      generation: 1,
      state: state,
      workState: workState,
      leaseCount: leaseCount,
      transition: transition,
    );
  }
}

class _ConflictingDisableLifecycleRepository() extends _IdleLifecycleRepository {
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

class _CommitFailingDisableLifecycleRepository() extends _IdleLifecycleRepository {
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

class _CommandLifecycleRepository({
  required var PluginSetupStatus inspectionResult,
  required final Completer<void>? inspectionGate,
  required var String? startFailureMessage,
}) implements PluginLifecycleRepository {
  final StreamController<List<PluginRuntimeSnapshot>> _snapshots = StreamController.broadcast(sync: true);
  PluginRuntimeSnapshot _current = const PluginRuntimeSnapshot(
    pluginId: "one",
    projectOwnership: PluginProjectOwnership.native,
    setup: PluginSetupNotInspected(),
    accessGate: PluginRuntimeAccessGate.disabled,
    startAllowed: false,
    generation: null,
    state: PluginRuntimeState.disabled,
    workState: PluginWorkState.unknown,
    leaseCount: 0,
    transition: PluginRuntimeTransition.none,
  );
  int inspectCalls = 0;
  int startCalls = 0;
  int restartCalls = 0;
  int prepareDisableCalls = 0;
  int installCalls = 0;
  List<RuntimeProvisionProgress> installEvents = const [];
  Completer<void>? installGate;
  bool needsUpgrade = false;
  final List<String> upgradeQueries = [];
  final StreamController<PluginAuthenticationEvent> authenticationEvents =
      StreamController<PluginAuthenticationEvent>();
  int authenticationCalls = 0;
  bool authenticationAborted = false;
  PluginRuntimeAuthenticationContinuationResult authenticationContinuationResult =
      const PluginRuntimeAuthenticationContinuationApplied();
  final List<({String pluginId, int generation, Uri redirectUri})> authenticationRedirects = [];
  Object? inspectionError;

  @override
  PluginRuntimeAuthenticationOperation authenticate({required String pluginId}) {
    authenticationCalls++;
    return PluginRuntimeAuthenticationOperation(
      events: authenticationEvents.stream,
      abort: () {
        authenticationAborted = true;
        authenticationEvents
          ..addError(const PluginStartAbortedException())
          ..close();
      },
      generation: authenticationCalls,
    );
  }

  @override
  Future<PluginRuntimeAuthenticationContinuationResult> submitAuthenticationRedirect({
    required String pluginId,
    required int generation,
    required Uri redirectUri,
  }) async {
    authenticationRedirects.add((pluginId: pluginId, generation: generation, redirectUri: redirectUri));
    return authenticationContinuationResult;
  }

  @override
  Stream<RuntimeProvisionProgress> installRuntime({required String pluginId}) async* {
    installCalls++;
    await installGate?.future;
    yield* Stream.fromIterable(installEvents);
  }

  @override
  bool needsManagedRuntimeUpgrade({required String pluginId}) {
    upgradeQueries.add(pluginId);
    return needsUpgrade;
  }

  @override
  List<PluginRuntimeSnapshot> get snapshot => [_current];

  @override
  Stream<List<PluginRuntimeSnapshot>> get snapshots => _snapshots.stream;

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
      transition: PluginRuntimeTransition.none,
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
    final currentInspectionError = inspectionError;
    if (currentInspectionError != null) throw currentInspectionError;
    _current = _copySnapshot(
      setup: inspectionResult,
      accessGate: _current.accessGate,
      startAllowed: _current.startAllowed,
      state: _current.state,
      transition: PluginRuntimeTransition.none,
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
      transition: PluginRuntimeTransition.none,
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
    return await start(pluginId: pluginId);
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
      transition: PluginRuntimeTransition.stopping,
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
      transition: PluginRuntimeTransition.none,
    );
    _publish();
  }

  @override
  void rollbackDisable({required String pluginId}) => throw UnsupportedError("unused");

  PluginRuntimeSnapshot _copySnapshot({
    required PluginSetupStatus setup,
    required PluginRuntimeAccessGate accessGate,
    required bool startAllowed,
    required PluginRuntimeState state,
    required PluginRuntimeTransition transition,
  }) {
    return PluginRuntimeSnapshot(
      pluginId: "one",
      projectOwnership: PluginProjectOwnership.native,
      setup: setup,
      accessGate: accessGate,
      startAllowed: startAllowed,
      generation: _current.generation,
      state: state,
      workState: PluginWorkState.unknown,
      leaseCount: 0,
      transition: transition,
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
    transition: _current.transition,
  );

  void _publish() => _snapshots.add(snapshot);

  Future<void> dispose() => _snapshots.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MutableBridgeSettingsRepository({required var BridgeSettings settings}) implements BridgeSettingsRepository {
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

class _ControllablePluginIdleTimerScheduler() implements PluginIdleTimerScheduler {
  final List<_ControllablePluginIdleTimer> timers = [];

  @override
  Timer schedule({required Duration duration, required void Function() onElapsed}) {
    final timer = _ControllablePluginIdleTimer(duration: duration, onElapsed: onElapsed);
    timers.add(timer);
    return timer;
  }
}

class _ControllablePluginIdleTimer({required final Duration duration, required final void Function() _onElapsed})
    implements Timer {
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
