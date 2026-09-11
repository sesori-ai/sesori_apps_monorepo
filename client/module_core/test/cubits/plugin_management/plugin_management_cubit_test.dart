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
  late BehaviorSubject<Map<String, PluginInstallState>> installStates;
  late StreamController<PluginAuthenticationTerminalUpdate> authenticationTerminal;
  late BehaviorSubject<Map<String, PluginAuthenticationBrowserState>> authenticationBrowserStates;
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
    installStates = BehaviorSubject.seeded(const {});
    authenticationTerminal = StreamController.broadcast(sync: true);
    authenticationBrowserStates = BehaviorSubject.seeded(const {}, sync: true);
    authenticationChallenges = BehaviorSubject.seeded(const {});
    when(() => service.snapshots).thenAnswer((_) => snapshots.stream);
    when(() => service.installStates).thenAnswer((_) => installStates.stream);
    when(() => service.authenticationTerminal).thenAnswer((_) => authenticationTerminal.stream);
    when(() => service.authenticationBrowserStates).thenAnswer((_) => authenticationBrowserStates.stream);
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
      (_) async => PluginAuthenticationStartResult.challenge(
        challenge: PluginAuthenticationDeviceCodeChallenge(
          verificationUri: Uri.parse("https://auth.example/device"),
          userCode: "ABCD-EFGH",
        ),
      ),
    );
    when(
      () => service.retryBrowserAuthentication(pluginId: any(named: "pluginId")),
    ).thenAnswer((_) async {});
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
    await installStates.close();
    await authenticationTerminal.close();
    await authenticationBrowserStates.close();
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
        globalAction: PluginManagementActionState.idle(),
        harnessActions: {},
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

  test("browser authentication maps service-owned retained phases", () async {
    final browserChallenge = PluginAuthenticationBrowserChallenge(
      authorizationUri: Uri.parse("https://accounts.example/authorize"),
      expectedCallbackUri: Uri.parse("http://127.0.0.1/callback"),
    );
    when(
      () => service.startAuthentication(pluginId: "codex"),
    ).thenAnswer((_) async => PluginAuthenticationStartResult.challenge(challenge: browserChallenge));
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await _settle();
    authenticationChallenges.add({"codex": browserChallenge});
    authenticationBrowserStates.add({"codex": const PluginAuthenticationBrowserOpening()});

    await cubit.startAuthentication(pluginId: "codex");
    verifyNever(() => service.retryBrowserAuthentication(pluginId: "codex"));
    expect(
      (cubit.state as PluginManagementReady).authentication,
      PluginAuthenticationPresentationState.browserOpening(pluginId: "codex", challenge: browserChallenge),
    );
    authenticationBrowserStates.add({"codex": const PluginAuthenticationBrowserWaiting()});
    expect(
      (cubit.state as PluginManagementReady).authentication,
      PluginAuthenticationPresentationState.browserWaiting(pluginId: "codex", challenge: browserChallenge),
    );
    authenticationBrowserStates.add({"codex": const PluginAuthenticationBrowserFinalizing()});
    expect(
      (cubit.state as PluginManagementReady).authentication,
      PluginAuthenticationPresentationState.browserFinalizing(pluginId: "codex", challenge: browserChallenge),
    );

    final launchFailure = PluginAuthenticationBrowserFlowFailed(
      innerError: StateError("synthetic launch failure"),
      stackTrace: StackTrace.current,
      retryableWithActiveListener: true,
    );
    authenticationBrowserStates.add({
      "codex": PluginAuthenticationBrowserRetryableFailure(failure: launchFailure),
    });
    expect(
      (cubit.state as PluginManagementReady).authentication,
      PluginAuthenticationPresentationState.browserLaunchFailed(pluginId: "codex", challenge: browserChallenge),
    );
    await cubit.launchAuthenticationBrowser();
    verify(() => service.retryBrowserAuthentication(pluginId: "codex")).called(1);

    authenticationBrowserStates.add({
      "codex": PluginAuthenticationBrowserFatalFailure(
        failure: PluginAuthenticationBrowserFlowFailed(
          innerError: TimeoutException("synthetic timeout"),
          stackTrace: StackTrace.current,
          retryableWithActiveListener: false,
        ),
      ),
    });
    expect(
      (cubit.state as PluginManagementReady).authentication,
      PluginAuthenticationPresentationState.cancelling(pluginId: "codex", challenge: browserChallenge),
    );

    authenticationTerminal.add((pluginId: "codex", progress: const PluginAuthenticationProgress.completed()));
    await _settle();
    expect(
      (cubit.state as PluginManagementReady).authentication,
      const PluginAuthenticationPresentationState.succeeded(pluginId: "codex"),
    );
  });

  for (final progress in [
    const PluginAuthenticationProgress.completed(),
    const PluginAuthenticationProgress.cancelled(),
    const PluginAuthenticationProgress.failed(message: "Provider rejected authentication"),
  ]) {
    test("active browser login preserves terminal $progress across failed reconnect refresh", () async {
      final browserChallenge = PluginAuthenticationBrowserChallenge(
        authorizationUri: Uri.parse("https://accounts.example/authorize"),
        expectedCallbackUri: Uri.parse("http://127.0.0.1/callback"),
      );
      when(
        () => service.startAuthentication(pluginId: "codex"),
      ).thenAnswer((_) async => PluginAuthenticationStartResult.challenge(challenge: browserChallenge));
      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await _settle();
      authenticationChallenges.add({"codex": browserChallenge});
      authenticationBrowserStates.add({"codex": const PluginAuthenticationBrowserWaiting()});
      await cubit.startAuthentication(pluginId: "codex");

      final refreshError = ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null);
      snapshots.add(PluginManagementLoadResult.failure(error: refreshError));
      await _settle();

      final failedRefresh = cubit.state as PluginManagementReady;
      expect(failedRefresh.refresh, PluginManagementRefreshState.failed(error: refreshError));
      expect(failedRefresh.authentication, isA<PluginAuthenticationPresentationBrowserWaiting>());

      authenticationTerminal.add((pluginId: "codex", progress: progress));
      snapshots.add(
        PluginManagementLoadResult.supported(
          response: _response.copyWith(snapshotToken: "recovered"),
          refreshError: null,
        ),
      );
      await _settle();

      final recovered = cubit.state as PluginManagementReady;
      expect(recovered.response.snapshotToken, "recovered");
      expect(
        recovered.authentication,
        switch (progress) {
          PluginAuthenticationCompletedProgress() => isA<PluginAuthenticationPresentationSucceeded>(),
          PluginAuthenticationCancelledProgress() => isA<PluginAuthenticationPresentationCancelled>(),
          PluginAuthenticationFailedProgress() => isA<PluginAuthenticationPresentationFailed>(),
          PluginAuthenticationUnknownProgress() => throw StateError("Unexpected test progress"),
        },
      );
    });
  }

  for (final progress in [
    const PluginAuthenticationProgress.completed(),
    const PluginAuthenticationProgress.cancelled(),
  ]) {
    test("terminal $progress can start another login without pressing its sheet action", () async {
      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await _settle();
      authenticationChallenges.add({
        "one": PluginAuthenticationDeviceCodeChallenge(
          verificationUri: Uri.parse("https://auth.example/device"),
          userCode: "ABCD-EFGH",
        ),
      });

      await cubit.startAuthentication(pluginId: "one");
      authenticationTerminal.add((pluginId: "one", progress: progress));
      await _settle();
      await cubit.startAuthentication(pluginId: "one");

      verify(() => service.startAuthentication(pluginId: "one")).called(2);
    });
  }

  test("terminal success after sheet dismissal leaves the next login available", () async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    await _settle();
    authenticationChallenges.add({
      "one": PluginAuthenticationDeviceCodeChallenge(
        verificationUri: Uri.parse("https://auth.example/device"),
        userCode: "ABCD-EFGH",
      ),
    });

    await cubit.startAuthentication(pluginId: "one");
    cubit.dismissAuthentication();
    authenticationTerminal.add((pluginId: "one", progress: const PluginAuthenticationProgress.completed()));
    await cubit.startAuthentication(pluginId: "one");

    verify(() => service.startAuthentication(pluginId: "one")).called(2);
  });

  for (final progress in [
    const PluginAuthenticationProgress.completed(),
    const PluginAuthenticationProgress.cancelled(),
    const PluginAuthenticationProgress.failed(message: "Login failed"),
  ]) {
    test("terminal $progress releases retry despite stale metadata and failed refresh", () async {
      final plugin = _conflict([]).current;
      final initial = _response.copyWith(plugins: [plugin]);
      snapshots.add(PluginManagementLoadResult.supported(response: initial, refreshError: null));
      await _settle();
      authenticationChallenges.add({
        "one": PluginAuthenticationDeviceCodeChallenge(
          verificationUri: Uri.parse("https://auth.example/device"),
          userCode: "ABCD-EFGH",
        ),
      });
      await cubit.startAuthentication(pluginId: "one");
      final stale = initial.copyWith(
        plugins: [plugin.copyWith(authenticationState: PluginAuthenticationState.inProgress)],
      );
      snapshots.add(PluginManagementLoadResult.supported(response: stale, refreshError: null));
      await _settle();
      expect((cubit.state as PluginManagementReady).harnessControlsBlocked(pluginId: "one"), isTrue);
      authenticationTerminal.add((pluginId: "one", progress: progress));
      final refreshError = ApiError.generic();
      snapshots.add(PluginManagementLoadResult.supported(response: stale, refreshError: refreshError));
      await _settle();
      final ready = cubit.state as PluginManagementReady;
      expect(ready.response, same(stale));
      expect(ready.refresh, PluginManagementRefreshState.failed(error: refreshError));
      expect(ready.harnessControlsBlocked(pluginId: "one"), isFalse);
      if (progress is PluginAuthenticationFailedProgress) {
        expect(ready.authentication, isA<PluginAuthenticationPresentationFailed>());
      } else if (progress is PluginAuthenticationCompletedProgress) {
        expect(ready.authentication, isA<PluginAuthenticationPresentationSucceeded>());
      } else {
        expect(ready.authentication, isA<PluginAuthenticationPresentationCancelled>());
      }
      cubit.dismissAuthentication();
      // Admission is not success: a still-busy bridge can reject the retry.
      final conflict = PluginAuthenticationConflict(
        pluginId: "one",
        reasons: const [PluginAuthenticationConflictReason.inFlight],
        current: stale.plugins.single,
      );
      when(() => service.startAuthentication(pluginId: "one")).thenAnswer(
        (_) async => PluginAuthenticationStartResult.failed(
          failure: PluginAuthenticationFailure.conflict(conflict: conflict),
        ),
      );
      await cubit.startAuthentication(pluginId: "one");
      verify(() => service.startAuthentication(pluginId: "one")).called(2);
      expect(
        (cubit.state as PluginManagementReady).authentication,
        PluginAuthenticationPresentationState.failed(
          pluginId: "one",
          error: PluginAuthenticationPresentationError.conflict(conflict: conflict),
        ),
      );
      when(() => service.startAuthentication(pluginId: "one")).thenAnswer(
        (_) async => const PluginAuthenticationStartResult.failed(failure: PluginAuthenticationFailure.uncertain()),
      );
      await cubit.startAuthentication(pluginId: "one");
      expect(
        (cubit.state as PluginManagementReady).authentication,
        const PluginAuthenticationPresentationState.failed(
          pluginId: "one",
          error: PluginAuthenticationPresentationError.uncertain(),
        ),
      );
    });
  }

  test("authentication maps a thrown browser launch and allows retry", () async {
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    authenticationChallenges.add({
      "codex": PluginAuthenticationDeviceCodeChallenge(
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
      "codex": PluginAuthenticationDeviceCodeChallenge(
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
      const PluginAuthenticationPresentationState.succeeded(pluginId: "codex"),
    );
  });

  test("a browser failure cannot overwrite cancellation", () async {
    final launch = Completer<bool>();
    when(
      () => urlLauncher.launch(any(), mode: any(named: "mode")),
    ).thenAnswer((_) => launch.future);
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    authenticationChallenges.add({
      "codex": PluginAuthenticationDeviceCodeChallenge(
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
      PluginAuthenticationStartResult.challenge(
        challenge: PluginAuthenticationDeviceCodeChallenge(
          verificationUri: Uri.parse("https://stale.example/device"),
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
      "codex": PluginAuthenticationDeviceCodeChallenge(
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
      const PluginAuthenticationPresentationState.cancelled(pluginId: "codex"),
    );
  });

  test("authentication cancellation blocks re-entry and ignores a stale response", () async {
    final cancel = Completer<PluginAuthenticationCancelResult>();
    when(
      () => service.cancelAuthentication(pluginId: "codex"),
    ).thenAnswer((_) => cancel.future);
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    authenticationChallenges.add({
      "codex": PluginAuthenticationDeviceCodeChallenge(
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
      const PluginAuthenticationPresentationState.cancelled(pluginId: "codex"),
    );
  });

  test("a cancellation response cannot resurrect state after snapshot reset", () async {
    final cancel = Completer<PluginAuthenticationCancelResult>();
    when(
      () => service.cancelAuthentication(pluginId: "codex"),
    ).thenAnswer((_) => cancel.future);
    snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
    authenticationChallenges.add({
      "codex": PluginAuthenticationDeviceCodeChallenge(
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
      expect(
        (cubit.state as PluginManagementReady).actionFor(
          target: const PluginManagementActionTarget.harness(pluginId: "one"),
        ),
        const PluginManagementActionState.idle(),
      );
    });

    test("install sends the install command and surfaces streamed progress", () async {
      await cubit.install(pluginId: "one");

      verify(
        () => service.command(
          pluginId: "one",
          request: const PluginLifecycleCommandRequest.install(),
        ),
      ).called(1);

      installStates.add(const {
        "one": PluginInstallState.inProgress(
          progress: PluginInstallProgress(phase: PluginInstallPhase.downloading, percent: 42),
        ),
      });
      await _settle();
      expect(
        (cubit.state as PluginManagementReady).installs,
        const {
          "one": PluginInstallState.inProgress(
            progress: PluginInstallProgress(phase: PluginInstallPhase.downloading, percent: 42),
          ),
        },
      );

      installStates.add(const {});
      await _settle();
      expect((cubit.state as PluginManagementReady).installs, isEmpty);
    });

    test("a cubit created mid-install seeds progress from the service", () async {
      installStates.add(const {
        "one": PluginInstallState.inProgress(
          progress: PluginInstallProgress(phase: PluginInstallPhase.verifying, percent: null),
        ),
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
        const {
          "one": PluginInstallState.inProgress(
            progress: PluginInstallProgress(phase: PluginInstallPhase.verifying, percent: null),
          ),
        },
      );
    });

    test("a recreated flow reattaches to the retained browser listener without restarting it", () async {
      final challenge = PluginAuthenticationBrowserChallenge(
        authorizationUri: Uri.parse("https://accounts.example/authorize"),
        expectedCallbackUri: Uri.parse("http://127.0.0.1/callback"),
      );
      authenticationChallenges.add({"one": challenge});
      authenticationBrowserStates.add({"one": const PluginAuthenticationBrowserFinalizing()});
      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await _settle();

      final reopened = PluginManagementCubit(service: service, urlLauncher: urlLauncher, catalogRescanService: rescan);
      addTearDown(reopened.close);
      await _settle();

      expect(
        (reopened.state as PluginManagementReady).authentication,
        PluginAuthenticationPresentationState.browserFinalizing(pluginId: "one", challenge: challenge),
      );
      verifyNever(() => service.retryBrowserAuthentication(pluginId: "one"));
    });

    test("retained install failure replays into a recreated flow cubit", () async {
      installStates.add(const {"one": PluginInstallState.failed()});
      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await _settle();
      final reopened = PluginManagementCubit(service: service, urlLauncher: urlLauncher, catalogRescanService: rescan);
      addTearDown(reopened.close);
      await _settle();
      expect((reopened.state as PluginManagementReady).installs["one"], const PluginInstallState.failed());
      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await _settle();
      expect((reopened.state as PluginManagementReady).installs["one"], const PluginInstallState.failed());
      await reopened.enable(pluginId: "two");
      expect((reopened.state as PluginManagementReady).installs["one"], const PluginInstallState.failed());
    });

    test("a loading transition mid-install restores progress with the next snapshot", () async {
      installStates.add(const {
        "one": PluginInstallState.inProgress(
          progress: PluginInstallProgress(phase: PluginInstallPhase.downloading, percent: 10),
        ),
      });
      await _settle();

      snapshots.add(const PluginManagementLoadResult.loading());
      await _settle();
      expect(cubit.state, const PluginManagementState.loading());

      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await _settle();

      expect(
        (cubit.state as PluginManagementReady).installs,
        const {
          "one": PluginInstallState.inProgress(
            progress: PluginInstallProgress(phase: PluginInstallPhase.downloading, percent: 10),
          ),
        },
      );
    });

    test("an equivalent progress map does not emit a new state", () async {
      installStates.add(const {
        "one": PluginInstallState.inProgress(
          progress: PluginInstallProgress(phase: PluginInstallPhase.extracting, percent: null),
        ),
      });
      await _settle();
      final emitted = <PluginManagementState>[];
      final subscription = cubit.stream.listen(emitted.add);
      addTearDown(subscription.cancel);

      installStates.add(const {
        "one": PluginInstallState.inProgress(
          progress: PluginInstallProgress(phase: PluginInstallPhase.extracting, percent: null),
        ),
      });
      await _settle();

      expect(emitted, isEmpty);
    });

    test("install progress survives a refreshed snapshot", () async {
      installStates.add(const {
        "one": PluginInstallState.inProgress(
          progress: PluginInstallProgress(phase: PluginInstallPhase.extracting, percent: null),
        ),
      });
      await _settle();

      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await _settle();

      expect(
        (cubit.state as PluginManagementReady).installs,
        const {
          "one": PluginInstallState.inProgress(
            progress: PluginInstallProgress(phase: PluginInstallPhase.extracting, percent: null),
          ),
        },
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
        (cubit.state as PluginManagementReady).globalAction,
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
        (cubit.state as PluginManagementReady).actionFor(
          target: const PluginManagementActionTarget.harness(pluginId: "one"),
        ),
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

      await cubit.confirmForce(
        confirmation:
            (cubit.state as PluginManagementReady).harnessActions["one"]!
                as PluginManagementActionForceConfirmationRequired,
      );

      verify(
        () => service.command(
          pluginId: "one",
          request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
        ),
      ).called(1);
      expect(
        (cubit.state as PluginManagementReady).actionFor(
          target: const PluginManagementActionTarget.harness(pluginId: "one"),
        ),
        const PluginManagementActionState.idle(),
      );
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

      cubit.dismissForceConfirmation(
        confirmation:
            (cubit.state as PluginManagementReady).harnessActions["one"]!
                as PluginManagementActionForceConfirmationRequired,
      );
      await cubit.enable(pluginId: "two");

      expect(
        (cubit.state as PluginManagementReady).actionFor(
          target: const PluginManagementActionTarget.harness(pluginId: "one"),
        ),
        const PluginManagementActionState.idle(),
      );
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
        (cubit.state as PluginManagementReady).actionFor(
          target: const PluginManagementActionTarget.harness(pluginId: "one"),
        ),
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
        (cubit.state as PluginManagementReady).actionFor(
          target: const PluginManagementActionTarget.harness(pluginId: "one"),
        ),
        const PluginManagementActionState.failed(
          target: PluginManagementActionTarget.harness(pluginId: "one"),
          error: PluginManagementActionError.uncertain(),
        ),
      );

      cubit.dismissActionError(
        failure: (cubit.state as PluginManagementReady).harnessActions["one"]! as PluginManagementActionFailed,
      );
      expect(
        (cubit.state as PluginManagementReady).actionFor(
          target: const PluginManagementActionTarget.harness(pluginId: "one"),
        ),
        const PluginManagementActionState.idle(),
      );
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
        (cubit.state as PluginManagementReady).actionFor(
          target: const PluginManagementActionTarget.harness(pluginId: "one"),
        ),
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
        (cubit.state as PluginManagementReady).actionFor(
          target: const PluginManagementActionTarget.harness(pluginId: "one"),
        ),
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
      expect(refreshed.actionFor(target: target), const PluginManagementActionState.inProgress(target: target));
      expect(refreshed.refresh, isA<PluginManagementRefreshFailed>());

      command.complete(const PluginManagementMutationResult.success(response: _response));
      await action;
      expect(
        (cubit.state as PluginManagementReady).actionFor(
          target: const PluginManagementActionTarget.harness(pluginId: "one"),
        ),
        const PluginManagementActionState.idle(),
      );
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
      final pending = (cubit.state as PluginManagementReady).actionFor(
        target: const PluginManagementActionTarget.harness(pluginId: "one"),
      );

      snapshots.add(
        PluginManagementLoadResult.supported(
          response: _response.copyWith(snapshotToken: "refresh"),
          refreshError: null,
        ),
      );
      await _settle();

      expect(
        (cubit.state as PluginManagementReady).actionFor(
          target: const PluginManagementActionTarget.harness(pluginId: "one"),
        ),
        pending,
      );
    });

    for (final reverse in [false, true]) {
      test("independent harness outcomes and duplicate exclusion reversed=$reverse", () async {
        final one = Completer<PluginManagementMutationResult>();
        final two = Completer<PluginManagementMutationResult>();
        when(
          () => service.command(
            pluginId: "one",
            request: any(named: "request"),
          ),
        ).thenAnswer((_) => one.future);
        when(
          () => service.command(
            pluginId: "two",
            request: any(named: "request"),
          ),
        ).thenAnswer((_) => two.future);
        when(() => service.planClearIdleTimeoutOverride(pluginId: "one")).thenReturn(
          const PluginManagementCommandPlan.request(
            request: PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "one"),
          ),
        );
        const input = PluginManagementIdleTimeoutInput.noTimeout();
        when(() => service.planApplyAllIdleTimeout(input: input)).thenReturn(
          const PluginManagementCommandPlan.request(
            request: PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 0),
          ),
        );
        final first = cubit.enable(pluginId: "one");
        final second = cubit.disable(pluginId: "two");
        expect((cubit.state as PluginManagementReady).harnessActions.keys, ["one", "two"]);
        for (final duplicate in [
          cubit.enable(pluginId: "one"),
          cubit.disable(pluginId: "one"),
          cubit.restart(pluginId: "one"),
          cubit.install(pluginId: "one"),
          cubit.refreshSetup(pluginId: "one"),
          cubit.clearIdleTimeoutOverride(pluginId: "one"),
          cubit.applyIdleTimeoutToAll(input: input),
          cubit.startAuthentication(pluginId: "one"),
        ]) {
          await duplicate;
        }
        verify(
          () => service.command(
            pluginId: "one",
            request: any(named: "request"),
          ),
        ).called(1);
        verify(
          () => service.command(
            pluginId: "two",
            request: any(named: "request"),
          ),
        ).called(1);
        verifyNever(() => service.updateIdleTimeout(request: any(named: "request")));
        verifyNever(() => service.startAuthentication(pluginId: "one"));
        final error = ApiError.generic();
        if (reverse) {
          two.complete(PluginManagementMutationResult.failure(error: error));
          await second;
          one.complete(const PluginManagementMutationResult.success(response: _response));
          await first;
        } else {
          one.complete(const PluginManagementMutationResult.success(response: _response));
          await first;
          two.complete(PluginManagementMutationResult.failure(error: error));
          await second;
        }
        final ready = cubit.state as PluginManagementReady;
        expect(ready.harnessActions.keys, ["two"]);
        final failure = ready.harnessActions["two"]! as PluginManagementActionFailed;
        expect((failure.error as PluginManagementActionRequestError).error, same(error));
        cubit.dismissActionError(failure: failure);
        expect((cubit.state as PluginManagementReady).harnessActions, isEmpty);
      });
    }

    test("global timeout excludes harness commands and overrides until settlement", () async {
      final pending = Completer<PluginManagementMutationResult>();
      const input = PluginManagementIdleTimeoutInput.noTimeout();
      when(() => service.planApplyAllIdleTimeout(input: input)).thenReturn(
        const PluginManagementCommandPlan.request(request: PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 0)),
      );
      when(() => service.planClearIdleTimeoutOverride(pluginId: "two")).thenReturn(
        const PluginManagementCommandPlan.request(
          request: PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "two"),
        ),
      );
      when(() => service.updateIdleTimeout(request: any(named: "request"))).thenAnswer((_) => pending.future);
      final global = cubit.applyIdleTimeoutToAll(input: input);
      await cubit.enable(pluginId: "one");
      await cubit.clearIdleTimeoutOverride(pluginId: "two");
      await cubit.applyIdleTimeoutToAll(input: input);
      verifyNever(
        () => service.command(
          pluginId: any(named: "pluginId"),
          request: any(named: "request"),
        ),
      );
      verify(() => service.updateIdleTimeout(request: any(named: "request"))).called(1);
      pending.complete(const PluginManagementMutationResult.uncertain());
      await global;
      final failure = (cubit.state as PluginManagementReady).globalAction as PluginManagementActionFailed;
      await cubit.enable(pluginId: "one");
      expect((cubit.state as PluginManagementReady).globalAction, same(failure));
      cubit.dismissActionError(failure: failure);
      expect((cubit.state as PluginManagementReady).globalAction, isA<PluginManagementActionIdle>());
    });

    test("two confirmations retain independent authority and stale callbacks cannot authorize a retry", () async {
      for (final pluginId in ["one", "two"]) {
        final base = _conflict(const [PluginLifecycleConflictReason.busy]);
        final conflict = base.copyWith(
          pluginId: pluginId,
          current: base.current.copyWith(
            setup: base.current.setup.copyWith(id: pluginId, displayName: pluginId),
          ),
        );
        when(
          () => service.command(
            pluginId: pluginId,
            request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
          ),
        ).thenAnswer((_) async => PluginManagementMutationResult.conflict(conflict: conflict));
        when(() => service.assessForce(conflict: conflict, action: PluginManagementForceAction.disable)).thenReturn(
          const PluginManagementForceAssessment.requiresConfirmation(
            request: PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
          ),
        );
      }
      const input = PluginManagementIdleTimeoutInput.noTimeout();
      when(() => service.planApplyAllIdleTimeout(input: input))
          .thenReturn(const PluginManagementCommandPlan.invalidInput());
      await cubit.disable(pluginId: "one");
      final first =
          (cubit.state as PluginManagementReady).harnessActions["one"]!
              as PluginManagementActionForceConfirmationRequired;
      await cubit.disable(pluginId: "two");
      final second =
          (cubit.state as PluginManagementReady).harnessActions["two"]!
              as PluginManagementActionForceConfirmationRequired;
      await cubit.applyIdleTimeoutToAll(input: input);
      expect((cubit.state as PluginManagementReady).globalAction, isA<PluginManagementActionIdle>());
      await cubit.enable(pluginId: "one");
      verifyNever(() => service.command(pluginId: "one", request: const PluginLifecycleCommandRequest.enable()));
      cubit.dismissForceConfirmation(confirmation: first);
      await cubit.disable(pluginId: "one");
      final replacement = (cubit.state as PluginManagementReady).harnessActions["one"]!;
      await cubit.confirmForce(confirmation: first);
      cubit.dismissForceConfirmation(confirmation: first);
      expect((cubit.state as PluginManagementReady).harnessActions["one"], same(replacement));
      await cubit.confirmForce(confirmation: second);
      await cubit.confirmForce(confirmation: second);
      verify(
        () => service.command(
          pluginId: "two",
          request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
        ),
      ).called(1);
      verifyNever(
        () => service.command(
          pluginId: "one",
          request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
        ),
      );
    });

    for (final reset in [
      const PluginManagementLoadResult.loading(),
      const PluginManagementLoadResult.unsupported(),
      PluginManagementLoadResult.failure(error: ApiError.generic()),
      PluginManagementLoadResult.supported(response: _response.copyWith(bridgeId: "replacement"), refreshError: null),
    ]) {
      test("reset ${reset.runtimeType} fences both pending targets and admits fresh attempts", () async {
        final one = Completer<PluginManagementMutationResult>();
        final two = Completer<PluginManagementMutationResult>();
        when(
          () => service.command(
            pluginId: "one",
            request: any(named: "request"),
          ),
        ).thenAnswer((_) => one.future);
        when(
          () => service.command(
            pluginId: "two",
            request: any(named: "request"),
          ),
        ).thenAnswer((_) => two.future);
        final first = cubit.enable(pluginId: "one");
        final second = cubit.enable(pluginId: "two");
        snapshots.add(reset);
        await _settle();
        snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
        await _settle();
        final retry = Completer<PluginManagementMutationResult>();
        when(
          () => service.command(
            pluginId: "one",
            request: any(named: "request"),
          ),
        ).thenAnswer((_) => retry.future);
        final newAttempt = cubit.enable(pluginId: "one");
        final entry = (cubit.state as PluginManagementReady).harnessActions["one"];
        one.complete(const PluginManagementMutationResult.success(response: _response));
        two.complete(const PluginManagementMutationResult.uncertain());
        await Future.wait([first, second]);
        expect((cubit.state as PluginManagementReady).harnessActions.keys, ["one"]);
        expect((cubit.state as PluginManagementReady).harnessActions["one"], same(entry));
        retry.complete(const PluginManagementMutationResult.success(response: _response));
        await newAttempt;
        expect((cubit.state as PluginManagementReady).harnessActions, isEmpty);
      });
    }

    test("active authentication and install reserve only their named harness", () async {
      final auth = Completer<PluginAuthenticationStartResult>();
      when(() => service.startAuthentication(pluginId: "one")).thenAnswer((_) => auth.future);
      final starting = cubit.startAuthentication(pluginId: "one");
      await cubit.enable(pluginId: "one");
      await cubit.enable(pluginId: "two");
      verifyNever(
        () => service.command(
          pluginId: "one",
          request: any(named: "request"),
        ),
      );
      verify(
        () => service.command(
          pluginId: "two",
          request: any(named: "request"),
        ),
      ).called(1);
      auth.complete(const PluginAuthenticationStartResult.failed(failure: PluginAuthenticationFailure.uncertain()));
      await starting;
      installStates.add(const {
        "one": PluginInstallState.inProgress(
          progress: PluginInstallProgress(phase: PluginInstallPhase.unknown, percent: null),
        ),
      });
      await _settle();
      await cubit.install(pluginId: "one");
      await cubit.enable(pluginId: "one");
      await cubit.enable(pluginId: "two");
      verifyNever(
        () => service.command(
          pluginId: "one",
          request: any(named: "request"),
        ),
      );
      verify(
        () => service.command(
          pluginId: "two",
          request: any(named: "request"),
        ),
      ).called(1);
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

      rescan.emit(
        const CatalogRescanState.preparingOne(
          pendingPluginName: "Codex",
          finishedHarnessCount: 0,
          pluginIds: {"codex", "claude"},
        ),
      );
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

      rescan.emit(
        const CatalogRescanState.preparingOne(
          pendingPluginName: "Codex",
          finishedHarnessCount: 0,
          pluginIds: {"codex"},
        ),
      );
      await _settle();

      expect((cubit.state as PluginManagementReady).scanRejections, isEmpty);
    });

    test("an unrelated harness keeps its refusal while another one scans", () async {
      await ready();
      rescan.stubStartResult(const CatalogRescanStartResult.notImportable());
      await cubit.startCatalogScanFor(pluginId: "codex");

      rescan.emit(
        const CatalogRescanState.preparingOne(
          pendingPluginName: "Claude",
          finishedHarnessCount: 0,
          pluginIds: {"claude"},
        ),
      );
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
      rescan.emit(
        const CatalogRescanState.preparingOne(
          pendingPluginName: "Codex",
          finishedHarnessCount: 0,
          pluginIds: {"codex"},
        ),
      );
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
      rescan.emit(
        const CatalogRescanState.preparingOne(
          pendingPluginName: "Codex",
          finishedHarnessCount: 0,
          pluginIds: {"codex"},
        ),
      );
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
      rescan.emit(
        const CatalogRescanState.preparingOne(
          pendingPluginName: "Claude",
          finishedHarnessCount: 0,
          pluginIds: {"claude"},
        ),
      );
      await _settle();

      snapshots.add(const PluginManagementLoadResult.supported(response: _response, refreshError: null));
      await _settle();

      final state = cubit.state as PluginManagementReady;
      expect(state.scanRejections, {"codex": isA<CatalogRescanStartUnsupported>()});
      expect(state.scanningPluginIds, {"claude"});
    });

    test("a cubit created mid-scan seeds its members from the service", () async {
      rescan.emit(
        const CatalogRescanState.preparingOne(
          pendingPluginName: "Codex",
          finishedHarnessCount: 0,
          pluginIds: {"codex"},
        ),
      );
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
