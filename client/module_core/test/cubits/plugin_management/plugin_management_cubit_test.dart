import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockPluginManagementService() extends Mock implements PluginManagementService;

class _MockUrlLauncher() extends Mock implements UrlLauncher;

const _response = PluginManagementResponse(
  snapshotToken: "snapshot-1",
  bridgeId: "bridge-1",
  defaultPluginId: "opencode",
  defaultIdleTimeoutMins: 10,
  plugins: [],
);

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late _MockPluginManagementService service;
  late BehaviorSubject<PluginManagementLoadResult> snapshots;
  late BehaviorSubject<Map<String, PluginInstallProgress>> installProgress;
  late StreamController<PluginAuthenticationTerminalUpdate> authenticationTerminal;
  late BehaviorSubject<Map<String, PluginAuthenticationChallenge>> authenticationChallenges;
  late PluginManagementCubit cubit;
  late _MockUrlLauncher urlLauncher;
  late FakeCatalogRescanService rescan;

  setUpAll(() {
    registerFallbackValue(const PluginLifecycleCommandRequest.enable());
    registerFallbackValue(const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 1));
    registerFallbackValue(Uri.parse("https://example.com"));
    registerFallbackValue(UrlLaunchMode.externalApp);
  });

  setUp(() {
    service = _MockPluginManagementService();
    urlLauncher = _MockUrlLauncher();
    snapshots = BehaviorSubject();
    installProgress = BehaviorSubject.seeded(const {});
    authenticationTerminal = StreamController.broadcast(sync: true);
    authenticationChallenges = BehaviorSubject.seeded(const {});
    when(() => service.snapshots).thenAnswer((_) => snapshots.stream);
    when(() => service.installProgress).thenAnswer((_) => installProgress.stream);
    when(() => service.authenticationTerminal).thenAnswer((_) => authenticationTerminal.stream);
    when(() => service.authenticationChallenges).thenAnswer((_) => authenticationChallenges.stream);
    when(() => service.refresh()).thenAnswer((_) async {});
    when(
      () => service.command(
        pluginId: any(named: "pluginId"),
        request: any(named: "request"),
      ),
    ).thenAnswer((_) async => const PluginManagementMutationResult.success(response: _response));
    when(
      () => service.updateIdleTimeout(request: any(named: "request")),
    ).thenAnswer((_) async => const PluginManagementMutationResult.success(response: _response));
    when(
      () => service.startAuthentication(pluginId: any(named: "pluginId")),
    ).thenAnswer(
      (_) async => const PluginAuthenticationStartResult.challenge(
        challenge: PluginAuthenticationChallengeResponse.deviceCode(
          verificationUrl: "https://auth.example/device",
          userCode: "ABCD-EFGH",
        ),
      ),
    );
    when(
      () => service.cancelAuthentication(pluginId: any(named: "pluginId")),
    ).thenAnswer((_) async => const PluginAuthenticationCancelResult.success());
    when(
      () => urlLauncher.launch(any(), mode: any(named: "mode")),
    ).thenAnswer((_) async => true);
    rescan = FakeCatalogRescanService();
    cubit = PluginManagementCubit(service: service, urlLauncher: urlLauncher, catalogRescanService: rescan);
  });

  tearDown(() async {
    await cubit.close();
    await rescan.onDispose();
    await snapshots.close();
    await installProgress.close();
    await authenticationTerminal.close();
    await authenticationChallenges.close();
  });

  test("starts loading and maps supported snapshots to idle ready state", () async {
    expect(cubit.state, const PluginManagementState.loading());

    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await _settle();

    expect(
      cubit.state,
      const PluginManagementState.ready(
        response: _response,
        refresh: PluginManagementRefreshState.idle(),
        action: PluginManagementActionState.idle(),
        authentication: PluginAuthenticationPresentationState.idle(),
        installs: {},
        scanningPluginIds: {},
        scanRejections: {},
        scanOutcome: null,
      ),
    );
  });

  test("maps unsupported and initial failure snapshots", () async {
    snapshots.add(const PluginManagementLoadResult.unsupported());
    await _settle();
    expect(cubit.state, const PluginManagementState.unsupported());

    final error = ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null);
    snapshots.add(PluginManagementLoadResult.failure(error: error));
    await _settle();
    expect(cubit.state, PluginManagementState.failure(error: error));
  });

  test("maps snapshot invalidation back to loading", () async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await _settle();
    expect(cubit.state, isA<PluginManagementReady>());

    snapshots.add(const PluginManagementLoadResult.loading());
    await _settle();

    expect(cubit.state, const PluginManagementState.loading());
  });

  test("authentication presents challenge, launches explicitly, and settles terminal progress", () async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    authenticationChallenges.add({
      "codex": PluginAuthenticationChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await _settle();

    await cubit.startAuthentication(pluginId: "codex");
    expect(
      (cubit.state as PluginManagementReady).authentication,
      isA<PluginAuthenticationPresentationChallenge>(),
    );
    verifyNever(() => urlLauncher.launch(any(), mode: any(named: "mode")));
    await cubit.launchAuthenticationBrowser();
    verify(
      () => urlLauncher.launch(Uri.parse("https://auth.example/device"), mode: UrlLaunchMode.externalApp),
    ).called(1);

    authenticationTerminal.add((pluginId: "codex", progress: const PluginAuthenticationProgress.completed()));
    await _settle();
    expect(
      (cubit.state as PluginManagementReady).authentication,
      const PluginAuthenticationPresentationState.idle(),
    );
  });

  test("authentication maps a thrown browser launch and allows retry", () async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    authenticationChallenges.add({
      "codex": PluginAuthenticationChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    when(
      () => urlLauncher.launch(any(), mode: any(named: "mode")),
    ).thenThrow(StateError("launcher unavailable"));
    await _settle();
    await cubit.startAuthentication(pluginId: "codex");

    await cubit.launchAuthenticationBrowser();

    expect(
      (cubit.state as PluginManagementReady).authentication,
      isA<PluginAuthenticationPresentationBrowserLaunchFailedState>(),
    );
  });

  test("a stale browser failure cannot overwrite terminal settlement", () async {
    final launch = Completer<bool>();
    when(
      () => urlLauncher.launch(any(), mode: any(named: "mode")),
    ).thenAnswer((_) => launch.future);
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    authenticationChallenges.add({
      "codex": PluginAuthenticationChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await _settle();
    await cubit.startAuthentication(pluginId: "codex");
    final launching = cubit.launchAuthenticationBrowser();
    authenticationTerminal.add((pluginId: "codex", progress: const PluginAuthenticationProgress.completed()));
    await _settle();
    launch.complete(false);
    await launching;

    expect(
      (cubit.state as PluginManagementReady).authentication,
      const PluginAuthenticationPresentationState.idle(),
    );
  });

  test("a browser failure cannot overwrite cancellation", () async {
    final launch = Completer<bool>();
    when(
      () => urlLauncher.launch(any(), mode: any(named: "mode")),
    ).thenAnswer((_) => launch.future);
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    authenticationChallenges.add({
      "codex": PluginAuthenticationChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await _settle();
    await cubit.startAuthentication(pluginId: "codex");
    final launching = cubit.launchAuthenticationBrowser();
    final cancelling = cubit.cancelAuthentication();
    launch.complete(false);
    await launching;

    expect(
      (cubit.state as PluginManagementReady).authentication,
      isA<PluginAuthenticationPresentationCancelling>(),
    );
    authenticationTerminal.add((pluginId: "codex", progress: const PluginAuthenticationProgress.cancelled()));
    await cancelling;
  });

  test("a stale same-plugin start response cannot overwrite a newer attempt", () async {
    final first = Completer<PluginAuthenticationStartResult>();
    var call = 0;
    when(
      () => service.startAuthentication(pluginId: "codex"),
    ).thenAnswer((_) {
      call++;
      return call == 1
          ? first.future
          : Future.value(
              PluginAuthenticationStartResult.failed(
                failure: PluginAuthenticationFailure.request(error: ApiError.generic()),
              ),
            );
    });
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await _settle();
    final firstStart = cubit.startAuthentication(pluginId: "codex");
    authenticationTerminal.add((
      pluginId: "codex",
      progress: const PluginAuthenticationProgress.failed(message: "First attempt failed."),
    ));
    await _settle();
    await cubit.startAuthentication(pluginId: "codex");
    first.complete(
      const PluginAuthenticationStartResult.challenge(
        challenge: PluginAuthenticationChallengeResponse.deviceCode(
          verificationUrl: "https://stale.example/device",
          userCode: "STALE-CODE",
        ),
      ),
    );
    await firstStart;

    expect(
      (cubit.state as PluginManagementReady).authentication,
      isA<PluginAuthenticationPresentationFailed>(),
    );
  });

  test("authentication cancellation waits for terminal progress", () async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    authenticationChallenges.add({
      "codex": PluginAuthenticationChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await _settle();
    await cubit.startAuthentication(pluginId: "codex");

    await cubit.cancelAuthentication();
    final cancelling = (cubit.state as PluginManagementReady).authentication;
    expect(
      cancelling,
      isA<PluginAuthenticationPresentationCancelling>(),
    );
    authenticationTerminal.add((pluginId: "codex", progress: const PluginAuthenticationProgress.cancelled()));
    await _settle();
    expect(
      (cubit.state as PluginManagementReady).authentication,
      const PluginAuthenticationPresentationState.idle(),
    );
  });

  test("authentication cancellation blocks re-entry and ignores a stale response", () async {
    final cancel = Completer<PluginAuthenticationCancelResult>();
    when(
      () => service.cancelAuthentication(pluginId: "codex"),
    ).thenAnswer((_) => cancel.future);
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    authenticationChallenges.add({
      "codex": PluginAuthenticationChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await _settle();
    await cubit.startAuthentication(pluginId: "codex");
    final firstCancel = cubit.cancelAuthentication();
    await cubit.cancelAuthentication();
    verify(() => service.cancelAuthentication(pluginId: "codex")).called(1);
    authenticationTerminal.add((pluginId: "codex", progress: const PluginAuthenticationProgress.cancelled()));
    await _settle();
    cancel.complete(const PluginAuthenticationCancelResult.failed(failure: PluginAuthenticationFailure.uncertain()));
    await firstCancel;

    expect(
      (cubit.state as PluginManagementReady).authentication,
      const PluginAuthenticationPresentationState.idle(),
    );
  });

  test("a cancellation response cannot resurrect state after snapshot reset", () async {
    final cancel = Completer<PluginAuthenticationCancelResult>();
    when(
      () => service.cancelAuthentication(pluginId: "codex"),
    ).thenAnswer((_) => cancel.future);
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    authenticationChallenges.add({
      "codex": PluginAuthenticationChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });
    await _settle();
    await cubit.startAuthentication(pluginId: "codex");
    final cancelling = cubit.cancelAuthentication();
    snapshots.add(const PluginManagementLoadResult.loading());
    await _settle();
    cancel.complete(const PluginAuthenticationCancelResult.failed(failure: PluginAuthenticationFailure.uncertain()));
    await cancelling;

    expect(cubit.state, const PluginManagementState.loading());
  });

  test("delegates refresh and retains a published refresh error with the ready snapshot", () async {
    final error = ApiError.dartHttpClient(Exception("offline"));
    snapshots.add(PluginManagementLoadResult.supported(response: _response, refreshError: error));
    await _settle();

    await cubit.refresh();

    verify(() => service.refresh()).called(1);
    expect((cubit.state as PluginManagementReady).response, _response);
    expect(
      (cubit.state as PluginManagementReady).refresh,
      PluginManagementRefreshState.failed(error: error),
    );
  });

  test("dismisses a ready-state refresh error without dropping the snapshot", () async {
    final error = ApiError.dartHttpClient(Exception("offline"));
    snapshots.add(PluginManagementLoadResult.supported(response: _response, refreshError: error));
    await _settle();

    cubit.dismissRefreshError();

    final state = cubit.state as PluginManagementReady;
    expect(state.response, _response);
    expect(state.refresh, const PluginManagementRefreshState.idle());
  });

  test("ignores a late refresh-error dismissal after close", () async {
    final error = ApiError.dartHttpClient(Exception("offline"));
    snapshots.add(PluginManagementLoadResult.supported(response: _response, refreshError: error));
    await _settle();
    await cubit.close();

    expect(cubit.dismissRefreshError, returnsNormally);
  });

  group("actions", () {
    setUp(() async {
      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await _settle();
    });

    test("constructs every lifecycle command exactly", () async {
      await cubit.enable(pluginId: "one");
      await cubit.disable(pluginId: "two");
      await cubit.restart(pluginId: "three");
      await cubit.refreshSetup(pluginId: "four");

      verify(
        () => service.command(
          pluginId: "one",
          request: const PluginLifecycleCommandRequest.enable(),
        ),
      ).called(1);
      verify(
        () => service.command(
          pluginId: "two",
          request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
        ),
      ).called(1);
      verify(
        () => service.command(
          pluginId: "three",
          request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe),
        ),
      ).called(1);
      verify(
        () => service.command(
          pluginId: "four",
          request: const PluginLifecycleCommandRequest.refresh(),
        ),
      ).called(1);
      expect((cubit.state as PluginManagementReady).action, const PluginManagementActionState.idle());
    });

    test("install sends the install command and surfaces streamed progress", () async {
      await cubit.install(pluginId: "one");

      verify(
        () => service.command(
          pluginId: "one",
          request: const PluginLifecycleCommandRequest.install(),
        ),
      ).called(1);

      installProgress.add(const {
        "one": PluginInstallProgress(phase: PluginInstallPhase.downloading, percent: 42),
      });
      await _settle();
      expect(
        (cubit.state as PluginManagementReady).installs,
        const {"one": PluginInstallProgress(phase: PluginInstallPhase.downloading, percent: 42)},
      );

      installProgress.add(const {});
      await _settle();
      expect((cubit.state as PluginManagementReady).installs, isEmpty);
    });

    test("a cubit created mid-install seeds progress from the service", () async {
      installProgress.add(const {
        "one": PluginInstallProgress(phase: PluginInstallPhase.verifying, percent: null),
      });
      await _settle();

      // The screen builds a fresh cubit on every visit, so reopening harness
      // settings during an install must not hide it.
      final reopened = PluginManagementCubit(service: service, urlLauncher: urlLauncher, catalogRescanService: rescan);
      addTearDown(reopened.close);
      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await _settle();

      expect(
        (reopened.state as PluginManagementReady).installs,
        const {"one": PluginInstallProgress(phase: PluginInstallPhase.verifying, percent: null)},
      );
    });

    test("a loading transition mid-install restores progress with the next snapshot", () async {
      installProgress.add(const {
        "one": PluginInstallProgress(phase: PluginInstallPhase.downloading, percent: 10),
      });
      await _settle();

      snapshots.add(const PluginManagementLoadResult.loading());
      await _settle();
      expect(cubit.state, const PluginManagementState.loading());

      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await _settle();

      expect(
        (cubit.state as PluginManagementReady).installs,
        const {"one": PluginInstallProgress(phase: PluginInstallPhase.downloading, percent: 10)},
      );
    });

    test("an equivalent progress map does not emit a new state", () async {
      installProgress.add(const {
        "one": PluginInstallProgress(phase: PluginInstallPhase.extracting, percent: null),
      });
      await _settle();
      final emitted = <PluginManagementState>[];
      final subscription = cubit.stream.listen(emitted.add);
      addTearDown(subscription.cancel);

      installProgress.add(const {
        "one": PluginInstallProgress(phase: PluginInstallPhase.extracting, percent: null),
      });
      await _settle();

      expect(emitted, isEmpty);
    });

    test("install progress survives a refreshed snapshot", () async {
      installProgress.add(const {
        "one": PluginInstallProgress(phase: PluginInstallPhase.extracting, percent: null),
      });
      await _settle();

      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await _settle();

      expect(
        (cubit.state as PluginManagementReady).installs,
        const {"one": PluginInstallProgress(phase: PluginInstallPhase.extracting, percent: null)},
      );
    });

    test("executes service-owned typed timeout plans and keeps clear override separate", () async {
      const applyInput = PluginManagementIdleTimeoutInput.noTimeout();
      const overrideInput = PluginManagementIdleTimeoutInput.custom(input: " 15 ");
      when(
        () => service.planApplyAllIdleTimeout(input: applyInput),
      ).thenReturn(
        const PluginManagementCommandPlan.request(
          request: PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 0),
        ),
      );
      when(
        () => service.planSetIdleTimeoutOverride(pluginId: "one", input: overrideInput),
      ).thenReturn(
        const PluginManagementCommandPlan.request(
          request: PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "one", idleTimeoutMins: 15),
        ),
      );
      when(
        () => service.planClearIdleTimeoutOverride(pluginId: "one"),
      ).thenReturn(
        const PluginManagementCommandPlan.request(
          request: PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "one"),
        ),
      );

      await cubit.applyIdleTimeoutToAll(input: applyInput);
      await cubit.setIdleTimeoutOverride(pluginId: "one", input: overrideInput);
      await cubit.clearIdleTimeoutOverride(pluginId: "one");

      verify(() => service.planApplyAllIdleTimeout(input: applyInput)).called(1);
      verify(() => service.planSetIdleTimeoutOverride(pluginId: "one", input: overrideInput)).called(1);
      verify(() => service.planClearIdleTimeoutOverride(pluginId: "one")).called(1);
      verify(
        () => service.updateIdleTimeout(
          request: const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 0),
        ),
      ).called(1);
      verify(
        () => service.updateIdleTimeout(
          request: const PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "one", idleTimeoutMins: 15),
        ),
      ).called(1);
      verify(
        () => service.updateIdleTimeout(
          request: const PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "one"),
        ),
      ).called(1);
    });

    test("maps invalid timeout plans without dispatching", () async {
      const input = PluginManagementIdleTimeoutInput.custom(input: "not a number");
      when(
        () => service.planApplyAllIdleTimeout(input: input),
      ).thenReturn(const PluginManagementCommandPlan.invalidInput());

      await cubit.applyIdleTimeoutToAll(input: input);

      expect(
        (cubit.state as PluginManagementReady).action,
        const PluginManagementActionState.failed(
          target: PluginManagementActionTarget.allHarnesses(),
          error: PluginManagementActionError.invalidIdleTimeout(),
        ),
      );
      verifyNever(() => service.updateIdleTimeout(request: any(named: "request")));
    });

    test("safe conflict requires one explicit force confirmation", () async {
      final conflict = _conflict(const [PluginLifecycleConflictReason.busy]);
      when(
        () => service.command(
          pluginId: "one",
          request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
        ),
      ).thenAnswer((_) async => PluginManagementMutationResult.conflict(conflict: conflict));
      when(
        () => service.assessForce(conflict: conflict, action: PluginManagementForceAction.disable),
      ).thenReturn(
        const PluginManagementForceAssessment.requiresConfirmation(
          request: PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
        ),
      );

      await cubit.disable(pluginId: "one");

      expect(
        (cubit.state as PluginManagementReady).action,
        PluginManagementActionState.forceConfirmationRequired(
          pluginId: "one",
          action: PluginManagementForceAction.disable,
          conflict: conflict,
          request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
        ),
      );
      verifyNever(
        () => service.command(
          pluginId: "one",
          request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
        ),
      );

      await cubit.confirmForce();

      verify(
        () => service.command(
          pluginId: "one",
          request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
        ),
      ).called(1);
      expect((cubit.state as PluginManagementReady).action, const PluginManagementActionState.idle());
    });

    test("dismissing force confirmation allows another action", () async {
      final conflict = _conflict(const [PluginLifecycleConflictReason.busy]);
      when(
        () => service.command(
          pluginId: "one",
          request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
        ),
      ).thenAnswer((_) async => PluginManagementMutationResult.conflict(conflict: conflict));
      when(
        () => service.assessForce(conflict: conflict, action: PluginManagementForceAction.disable),
      ).thenReturn(
        const PluginManagementForceAssessment.requiresConfirmation(
          request: PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
        ),
      );
      await cubit.disable(pluginId: "one");

      cubit.dismissForceConfirmation();
      await cubit.enable(pluginId: "two");

      expect((cubit.state as PluginManagementReady).action, const PluginManagementActionState.idle());
      verify(
        () => service.command(
          pluginId: "two",
          request: const PluginLifecycleCommandRequest.enable(),
        ),
      ).called(1);
    });

    test("maps a non-forceable conflict to an explicit action error", () async {
      final conflict = _conflict(const [PluginLifecycleConflictReason.unknown]);
      when(
        () => service.command(
          pluginId: "one",
          request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe),
        ),
      ).thenAnswer((_) async => PluginManagementMutationResult.conflict(conflict: conflict));
      when(
        () => service.assessForce(conflict: conflict, action: PluginManagementForceAction.restart),
      ).thenReturn(const PluginManagementForceAssessment.notForceable());

      await cubit.restart(pluginId: "one");

      expect(
        (cubit.state as PluginManagementReady).action,
        PluginManagementActionState.failed(
          target: const PluginManagementActionTarget.harness(pluginId: "one"),
          error: PluginManagementActionError.conflict(conflict: conflict),
        ),
      );
    });

    test("maps uncertain mutations and dismisses their explicit error", () async {
      when(
        () => service.command(
          pluginId: "one",
          request: const PluginLifecycleCommandRequest.enable(),
        ),
      ).thenAnswer((_) async => const PluginManagementMutationResult.uncertain());

      await cubit.enable(pluginId: "one");
      expect(
        (cubit.state as PluginManagementReady).action,
        const PluginManagementActionState.failed(
          target: PluginManagementActionTarget.harness(pluginId: "one"),
          error: PluginManagementActionError.uncertain(),
        ),
      );

      cubit.dismissActionError();
      expect((cubit.state as PluginManagementReady).action, const PluginManagementActionState.idle());
    });

    test("preserves an in-flight action across successful and failed refresh publications", () async {
      final command = Completer<PluginManagementMutationResult>();
      when(
        () => service.command(
          pluginId: "one",
          request: const PluginLifecycleCommandRequest.enable(),
        ),
      ).thenAnswer((_) => command.future);

      final action = cubit.enable(pluginId: "one");
      const target = PluginManagementActionTarget.harness(pluginId: "one");
      expect(
        (cubit.state as PluginManagementReady).action,
        const PluginManagementActionState.inProgress(target: target),
      );

      snapshots.add(
        PluginManagementLoadResult.supported(
          response: _response.copyWith(snapshotToken: "successful-refresh"),
          refreshError: null,
        ),
      );
      await _settle();
      expect(
        (cubit.state as PluginManagementReady).action,
        const PluginManagementActionState.inProgress(target: target),
      );

      snapshots.add(
        PluginManagementLoadResult.supported(
          response: _response.copyWith(snapshotToken: "refresh"),
          refreshError: ApiError.generic(),
        ),
      );
      await _settle();
      final refreshed = cubit.state as PluginManagementReady;
      expect(refreshed.action, const PluginManagementActionState.inProgress(target: target));
      expect(refreshed.refresh, isA<PluginManagementRefreshFailed>());

      command.complete(const PluginManagementMutationResult.success(response: _response));
      await action;
      expect((cubit.state as PluginManagementReady).action, const PluginManagementActionState.idle());
    });

    test("preserves pending force confirmation across refresh", () async {
      final conflict = _conflict(const [PluginLifecycleConflictReason.inFlight]);
      when(
        () => service.command(
          pluginId: "one",
          request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe),
        ),
      ).thenAnswer((_) async => PluginManagementMutationResult.conflict(conflict: conflict));
      when(
        () => service.assessForce(conflict: conflict, action: PluginManagementForceAction.restart),
      ).thenReturn(
        const PluginManagementForceAssessment.requiresConfirmation(
          request: PluginLifecycleCommandRequest.restart(mode: PluginStopMode.force),
        ),
      );
      await cubit.restart(pluginId: "one");
      final pending = (cubit.state as PluginManagementReady).action;

      snapshots.add(
        PluginManagementLoadResult.supported(
          response: _response.copyWith(snapshotToken: "refresh"),
          refreshError: null,
        ),
      );
      await _settle();

      expect((cubit.state as PluginManagementReady).action, pending);
    });

    test("does not emit after closing during an action", () async {
      final command = Completer<PluginManagementMutationResult>();
      when(
        () => service.command(
          pluginId: "one",
          request: const PluginLifecycleCommandRequest.enable(),
        ),
      ).thenAnswer((_) => command.future);
      final action = cubit.enable(pluginId: "one");

      await cubit.close();
      command.complete(const PluginManagementMutationResult.success(response: _response));

      await expectLater(action, completes);
    });
  });

  group("targeted catalog scan", () {
    Future<void> ready() async {
      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await _settle();
    }

    test("records nothing when the bridge accepts the scan", () async {
      await ready();

      await cubit.startCatalogScanFor(pluginId: "codex");

      expect(rescan.startedPluginIds, ["codex"]);
      expect((cubit.state as PluginManagementReady).scanRejections, isEmpty);
    });

    // The user named this harness, so a refusal has to land on its own card
    // rather than being skipped the way the fan-out skips it.
    test("keeps a rejection against the harness the user named", () async {
      await ready();
      rescan.stubStartResult(const CatalogRescanStartResult.notImportable());

      await cubit.startCatalogScanFor(pluginId: "codex");

      expect(
        (cubit.state as PluginManagementReady).scanRejections,
        {"codex": isA<CatalogRescanStartNotImportable>()},
      );
    });

    test("a retry clears the earlier rejection before the answer arrives", () async {
      await ready();
      rescan.stubStartResult(const CatalogRescanStartResult.notImportable());
      await cubit.startCatalogScanFor(pluginId: "codex");

      rescan.stubStartResult(const CatalogRescanStartResult.accepted());
      await cubit.startCatalogScanFor(pluginId: "codex");

      expect((cubit.state as PluginManagementReady).scanRejections, isEmpty);
    });

    test("names the harnesses a live scan covers, whoever started it", () async {
      await ready();

      rescan.emit(const CatalogRescanState.starting(pluginIds: {"codex", "claude"}));
      await _settle();
      expect((cubit.state as PluginManagementReady).scanningPluginIds, {"codex", "claude"});

      rescan.emit(
        const CatalogRescanState.succeeded(
          harnessCount: 2,
          counts: CatalogRescanCounts.delta(newProjects: 0, newSessions: 1),
        ),
      );
      await _settle();
      expect(
        (cubit.state as PluginManagementReady).scanningPluginIds,
        isEmpty,
        reason: "a finished scan holds no harness open",
      );
    });

    // A scan the lists started is still an attempt on this harness, so the
    // refusal it answers must not outlive it.
    test("a scan from another surface clears the refusal it answers", () async {
      await ready();
      rescan.stubStartResult(const CatalogRescanStartResult.notImportable());
      await cubit.startCatalogScanFor(pluginId: "codex");
      expect((cubit.state as PluginManagementReady).scanRejections, isNotEmpty);

      rescan.emit(const CatalogRescanState.starting(pluginIds: {"codex"}));
      await _settle();

      expect((cubit.state as PluginManagementReady).scanRejections, isEmpty);
    });

    test("an unrelated harness keeps its refusal while another one scans", () async {
      await ready();
      rescan.stubStartResult(const CatalogRescanStartResult.notImportable());
      await cubit.startCatalogScanFor(pluginId: "codex");

      rescan.emit(const CatalogRescanState.starting(pluginIds: {"claude"}));
      await _settle();

      expect(
        (cubit.state as PluginManagementReady).scanRejections,
        {"codex": isA<CatalogRescanStartNotImportable>()},
      );
    });

    // An uncertain start keeps the harness a member because the request may
    // have landed, so the card must not pair a spinner with "try again".
    test("records no refusal while the harness is still in the live operation", () async {
      await ready();
      rescan.stubStartResult(
        CatalogRescanStartResult.failed(cause: ApiError.nonSuccessCode(errorCode: 500, rawErrorString: null)),
      );
      rescan.emit(const CatalogRescanState.starting(pluginIds: {"codex"}));
      await _settle();

      await cubit.startCatalogScanFor(pluginId: "codex");

      final state = cubit.state as PluginManagementReady;
      expect(state.scanRejections, isEmpty);
      expect(state.scanningPluginIds, {"codex"});
    });

    // This screen hosts no progress row, so a scan it started has to be
    // announced here or the user never learns what it found.
    test("keeps the outcome of a scan this screen started", () async {
      await ready();
      await cubit.startCatalogScanFor(pluginId: "codex");

      rescan.emit(
        const CatalogRescanState.succeeded(
          harnessCount: 1,
          counts: CatalogRescanCounts.delta(newProjects: 2, newSessions: 5),
        ),
      );
      await _settle();

      expect(
        (cubit.state as PluginManagementReady).scanOutcome,
        isA<CatalogRescanOutcomeSucceeded>().having(
          (o) => o.counts,
          "counts",
          isA<CatalogRescanDelta>().having((c) => c.newSessions, "newSessions", 5),
        ),
      );
    });

    // The row above that list already reported it; announcing it again here
    // would report one run in two places.
    test("stays quiet about a scan this screen did not start", () async {
      await ready();

      rescan.emit(
        const CatalogRescanState.succeeded(
          harnessCount: 1,
          counts: CatalogRescanCounts.delta(newProjects: 0, newSessions: 1),
        ),
      );
      await _settle();

      expect((cubit.state as PluginManagementReady).scanOutcome, isNull);
    });

    test("carries a failure through as its own outcome", () async {
      await ready();
      await cubit.startCatalogScanFor(pluginId: "codex");

      rescan.emit(const CatalogRescanState.partlyFailed(succeededCount: 2, failedCount: 1));
      await _settle();

      expect(
        (cubit.state as PluginManagementReady).scanOutcome,
        isA<CatalogRescanOutcomePartlyFailed>().having((o) => o.failedCount, "failedCount", 1),
      );
    });

    // A refused start is already on the card; a toast would say it twice.
    test("a start the bridge refused produces no outcome", () async {
      await ready();
      rescan.stubStartResult(const CatalogRescanStartResult.notImportable());
      await cubit.startCatalogScanFor(pluginId: "codex");

      rescan.emit(const CatalogRescanState.failed(harnessCount: 1));
      await _settle();

      expect((cubit.state as PluginManagementReady).scanOutcome, isNull);
    });

    test("a run that ends without a terminal state announces nothing", () async {
      await ready();
      await cubit.startCatalogScanFor(pluginId: "codex");

      // Cancelled from a list: the operation closes straight to idle.
      rescan.emit(const CatalogRescanState.idle());
      await _settle();
      rescan.emit(
        const CatalogRescanState.succeeded(
          harnessCount: 1,
          counts: CatalogRescanCounts.delta(newProjects: 0, newSessions: 9),
        ),
      );
      await _settle();

      expect(
        (cubit.state as PluginManagementReady).scanOutcome,
        isNull,
        reason: "a dropped claim must not attach itself to the next run",
      );
    });

    // A disconnect reloads the snapshot and resets the scan, and the reload
    // reaches this cubit first — so the claim has to be dropped whether or not
    // the state is ready when the reset lands.
    test("a disconnect drops the claim rather than carrying it to the next run", () async {
      await ready();
      await cubit.startCatalogScanFor(pluginId: "codex");

      snapshots.add(const PluginManagementLoadResult.loading());
      await _settle();
      rescan.emit(const CatalogRescanState.idle());
      await _settle();
      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await _settle();

      rescan.emit(
        const CatalogRescanState.succeeded(
          harnessCount: 1,
          counts: CatalogRescanCounts.delta(newProjects: 0, newSessions: 7),
        ),
      );
      await _settle();

      expect((cubit.state as PluginManagementReady).scanOutcome, isNull);
    });

    // A definite rejection settles the operation before start() returns, so the
    // harness has left the live set by then — exactly as it would have if the
    // run had simply finished. Only the claim can tell those apart.
    test("a run that already announced its end adds no refusal to the card", () async {
      await ready();
      rescan
        ..stubStartResult(
          CatalogRescanStartResult.failed(cause: ApiError.nonSuccessCode(errorCode: 500, rawErrorString: null)),
        )
        ..stubBeforeStartAnswers(() => rescan.emit(const CatalogRescanState.failed(harnessCount: 1)));

      await cubit.startCatalogScanFor(pluginId: "codex");
      await _settle();

      final state = cubit.state as PluginManagementReady;
      expect(state.scanOutcome, isA<CatalogRescanOutcomeFailed>());
      expect(
        state.scanRejections,
        isEmpty,
        reason: "one attempt must not be reported as both a finished scan and a refused start",
      );
    });

    // Cards for harnesses outside the live operation stay enabled, so a second
    // one can be started and refused while the first is still running.
    test("a second harness being refused leaves the first one's claim alone", () async {
      await ready();
      await cubit.startCatalogScanFor(pluginId: "codex");
      rescan.emit(const CatalogRescanState.starting(pluginIds: {"codex"}));
      await _settle();

      rescan.stubStartResult(const CatalogRescanStartResult.notImportable());
      await cubit.startCatalogScanFor(pluginId: "claude");
      await _settle();

      rescan.emit(
        const CatalogRescanState.succeeded(
          harnessCount: 1,
          counts: CatalogRescanCounts.delta(newProjects: 0, newSessions: 4),
        ),
      );
      await _settle();

      final state = cubit.state as PluginManagementReady;
      expect(state.scanRejections, {"claude": isA<CatalogRescanStartNotImportable>()});
      expect(
        state.scanOutcome,
        isA<CatalogRescanOutcomeSucceeded>(),
        reason: "the run codex started still ends with an announcement",
      );
    });

    test("an announced outcome is cleared so it is reported once", () async {
      await ready();
      await cubit.startCatalogScanFor(pluginId: "codex");
      rescan.emit(const CatalogRescanState.failed(harnessCount: 1));
      await _settle();

      cubit.dismissCatalogScanOutcome();

      expect((cubit.state as PluginManagementReady).scanOutcome, isNull);
    });

    // The screen rebuilds this cubit per visit and every snapshot rebuilds the
    // ready state, so both fields have to survive a rebuild that is not theirs.
    test("a snapshot rebuild keeps the scan fields", () async {
      await ready();
      rescan.stubStartResult(const CatalogRescanStartResult.unsupported());
      await cubit.startCatalogScanFor(pluginId: "codex");
      rescan.emit(const CatalogRescanState.starting(pluginIds: {"claude"}));
      await _settle();

      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await _settle();

      final state = cubit.state as PluginManagementReady;
      expect(state.scanRejections, {"codex": isA<CatalogRescanStartUnsupported>()});
      expect(state.scanningPluginIds, {"claude"});
    });

    test("a cubit created mid-scan seeds its members from the service", () async {
      rescan.emit(const CatalogRescanState.starting(pluginIds: {"codex"}));
      await _settle();

      final reopened = PluginManagementCubit(
        service: service,
        urlLauncher: urlLauncher,
        catalogRescanService: rescan,
      );
      addTearDown(reopened.close);
      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await _settle();

      expect((reopened.state as PluginManagementReady).scanningPluginIds, {"codex"});
    });
  });

}

PluginLifecycleConflict _conflict(List<PluginLifecycleConflictReason> reasons) {
  return PluginLifecycleConflict(
    pluginId: "one",
    reasons: reasons,
    current: const PluginManagementMetadata(
      setup: PluginSetupMetadata(
        id: "one",
        displayName: "One",
        state: PluginSetupState.ready,
        runtimeVersion: null,
        actionHint: null,
      ),
      runtimeState: PluginRuntimeState.dormant,
      workState: PluginManagementWorkState.idle,
      idleTimeoutMins: 10,
      hasIdleTimeoutOverride: false,
      managementCapabilities: {
        PluginManagementCapability.lifecycle,
        PluginManagementCapability.setupRefresh,
        PluginManagementCapability.idleTimeout,
      },
      actionHint: null,
    ),
  );
}
