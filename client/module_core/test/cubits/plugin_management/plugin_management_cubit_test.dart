import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockPluginManagementService extends Mock implements PluginManagementService {}

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
  late PluginManagementCubit cubit;

  setUpAll(() {
    registerFallbackValue(const PluginLifecycleCommandRequest.enable());
    registerFallbackValue(const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 1));
  });

  setUp(() {
    service = _MockPluginManagementService();
    snapshots = BehaviorSubject();
    when(() => service.snapshots).thenAnswer((_) => snapshots.stream);
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
    cubit = PluginManagementCubit(service: service);
  });

  tearDown(() async {
    await cubit.close();
    await snapshots.close();
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

    test("executes service-owned timeout plans including zero and negative values", () async {
      when(
        () => service.planApplyAllIdleTimeout(input: " -5 "),
      ).thenReturn(
        const PluginManagementCommandPlan.request(
          request: PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: -5),
        ),
      );
      when(
        () => service.planSetIdleTimeoutOverride(pluginId: "one", input: "0"),
      ).thenReturn(
        const PluginManagementCommandPlan.request(
          request: PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "one", idleTimeoutMins: 0),
        ),
      );
      when(
        () => service.planClearIdleTimeoutOverride(pluginId: "one"),
      ).thenReturn(
        const PluginManagementCommandPlan.request(
          request: PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "one"),
        ),
      );

      await cubit.applyIdleTimeoutToAll(input: " -5 ");
      await cubit.setIdleTimeoutOverride(pluginId: "one", input: "0");
      await cubit.clearIdleTimeoutOverride(pluginId: "one");

      verify(
        () => service.updateIdleTimeout(
          request: const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: -5),
        ),
      ).called(1);
      verify(
        () => service.updateIdleTimeout(
          request: const PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "one", idleTimeoutMins: 0),
        ),
      ).called(1);
      verify(
        () => service.updateIdleTimeout(
          request: const PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "one"),
        ),
      ).called(1);
    });

    test("maps invalid timeout plans without dispatching", () async {
      when(
        () => service.planApplyAllIdleTimeout(input: "not a number"),
      ).thenReturn(const PluginManagementCommandPlan.invalidInput());

      await cubit.applyIdleTimeoutToAll(input: "not a number");

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
        actionHint: null,
      ),
      runtimeState: PluginRuntimeState.dormant,
      workState: PluginManagementWorkState.idle,
      idleTimeoutMins: 10,
      hasIdleTimeoutOverride: false,
      actionHint: null,
    ),
  );
}
