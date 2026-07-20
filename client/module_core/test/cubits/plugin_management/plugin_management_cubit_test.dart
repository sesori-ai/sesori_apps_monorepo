import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/cubits/plugin_management/plugin_management_cubit.dart";
import "package:sesori_dart_core/src/cubits/plugin_management/plugin_management_state.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_management_result.dart";
import "package:sesori_dart_core/src/services/plugin_management_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/plugin_management_test_data.dart";

class MockPluginManagementService extends Mock implements PluginManagementService {}

Future<void> settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late MockPluginManagementService service;
  late BehaviorSubject<PluginManagementLoadResult> snapshots;
  late PluginManagementCubit cubit;

  setUp(() async {
    service = MockPluginManagementService();
    snapshots = BehaviorSubject.seeded(
      const PluginManagementLoadResult.supported(response: testPluginManagementResponse),
    );
    when(() => service.snapshots).thenAnswer((_) => snapshots.stream);
    cubit = PluginManagementCubit(service: service);
    await settle();
  });

  tearDown(() async {
    await cubit.close();
    await snapshots.close();
  });

  test("maps loading, unsupported, failure, and ready snapshots", () async {
    snapshots.add(const PluginManagementLoadResult.unsupported());
    await settle();
    expect(cubit.state, const PluginManagementState.unsupported());

    final error = ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null);
    snapshots.add(PluginManagementLoadResult.failure(error: error));
    await settle();
    expect(cubit.state, PluginManagementState.failure(error: error));

    final updated = testPluginManagementResponseAt(revision: 2);
    snapshots.add(PluginManagementLoadResult.supported(response: updated));
    await settle();
    expect(
      cubit.state,
      PluginManagementState.ready(
        response: updated,
        actionStatus: PluginManagementActionStatus.idle,
        actingPluginId: null,
        pendingForceAction: null,
        actionError: null,
      ),
    );
  });

  test("exposes action progress and clears it on success", () async {
    final completer = Completer<PluginManagementMutationResult>();
    when(
      () => service.command(
        pluginId: "plugin-a",
        request: const PluginLifecycleCommandRequest.enable(),
      ),
    ).thenAnswer((_) => completer.future);

    final action = cubit.enable(pluginId: "plugin-a");
    expect(
      cubit.state,
      const PluginManagementState.ready(
        response: testPluginManagementResponse,
        actionStatus: PluginManagementActionStatus.inProgress,
        actingPluginId: "plugin-a",
        pendingForceAction: null,
        actionError: null,
      ),
    );

    final updated = testPluginManagementResponseAt(revision: 2);
    completer.complete(PluginManagementMutationResult.success(response: updated));
    await action;
    expect((cubit.state as PluginManagementReady).response, updated);
    expect((cubit.state as PluginManagementReady).actionStatus, PluginManagementActionStatus.idle);
  });

  test("sends safe disable first and force only after explicit confirmation", () async {
    const safeRequest = PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe);
    const forceRequest = PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force);
    const conflict = PluginLifecycleConflict(
      pluginId: "plugin-a",
      reasons: [PluginLifecycleConflictReason.busy],
      current: testPluginA,
    );
    when(() => service.command(pluginId: "plugin-a", request: safeRequest)).thenAnswer(
      (_) async => const PluginManagementMutationResult.conflict(conflict: conflict),
    );

    await cubit.disable(pluginId: "plugin-a");

    final conflicted = cubit.state as PluginManagementReady;
    expect(conflicted.actionStatus, PluginManagementActionStatus.failure);
    expect(conflicted.actionError, const PluginManagementActionError.conflict(conflict: conflict));
    expect(conflicted.pendingForceAction, PluginManagementForceAction.disable);
    verify(() => service.command(pluginId: "plugin-a", request: safeRequest)).called(1);
    verifyNever(() => service.command(pluginId: "plugin-a", request: forceRequest));

    when(() => service.command(pluginId: "plugin-a", request: forceRequest)).thenAnswer(
      (_) async => const PluginManagementMutationResult.success(response: testPluginManagementResponse),
    );
    await cubit.confirmForce();

    verify(() => service.command(pluginId: "plugin-a", request: forceRequest)).called(1);
    expect((cubit.state as PluginManagementReady).pendingForceAction, isNull);
    expect((cubit.state as PluginManagementReady).actionError, isNull);
  });

  test("surfaces non-forceable restart conflicts without inferring force", () async {
    const safeRequest = PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe);
    const forceRequest = PluginLifecycleCommandRequest.restart(mode: PluginStopMode.force);
    const conflict = PluginLifecycleConflict(
      pluginId: "plugin-a",
      reasons: [PluginLifecycleConflictReason.notEnabled],
      current: testPluginA,
    );
    when(() => service.command(pluginId: "plugin-a", request: safeRequest)).thenAnswer(
      (_) async => const PluginManagementMutationResult.conflict(conflict: conflict),
    );

    await cubit.restart(pluginId: "plugin-a");
    await cubit.confirmForce();

    final current = cubit.state as PluginManagementReady;
    expect(current.actionError, const PluginManagementActionError.conflict(conflict: conflict));
    expect(current.pendingForceAction, isNull);
    verify(() => service.command(pluginId: "plugin-a", request: safeRequest)).called(1);
    verifyNever(() => service.command(pluginId: "plugin-a", request: forceRequest));
  });

  test("validates integer timeout input before sending typed mutations", () async {
    await cubit.applyIdleTimeoutToAll(input: "1.5");
    expect(
      (cubit.state as PluginManagementReady).actionError,
      const PluginManagementActionError.invalidIdleTimeout(),
    );
    verifyNever(
      () => service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 1),
      ),
    );

    const applyAll = PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: -1);
    when(() => service.updateIdleTimeout(request: applyAll)).thenAnswer(
      (_) async => const PluginManagementMutationResult.success(response: testPluginManagementResponse),
    );
    await cubit.applyIdleTimeoutToAll(input: " -1 ");
    verify(() => service.updateIdleTimeout(request: applyAll)).called(1);

    const setOverride = PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "plugin-a", idleTimeoutMins: 15);
    when(() => service.updateIdleTimeout(request: setOverride)).thenAnswer(
      (_) async => const PluginManagementMutationResult.success(response: testPluginManagementResponse),
    );
    await cubit.setIdleTimeoutOverride(pluginId: "plugin-a", input: "15");
    verify(() => service.updateIdleTimeout(request: setOverride)).called(1);

    const clearOverride = PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "plugin-a");
    when(() => service.updateIdleTimeout(request: clearOverride)).thenAnswer(
      (_) async => const PluginManagementMutationResult.success(response: testPluginManagementResponse),
    );
    await cubit.clearIdleTimeoutOverride(pluginId: "plugin-a");
    verify(() => service.updateIdleTimeout(request: clearOverride)).called(1);
  });

  test("surfaces typed not-found and request action errors", () async {
    const request = PluginLifecycleCommandRequest.refresh();
    when(() => service.command(pluginId: "missing", request: request)).thenAnswer(
      (_) async => const PluginManagementMutationResult.notFound(),
    );
    await cubit.refreshPlugin(pluginId: "missing");
    expect((cubit.state as PluginManagementReady).actionError, const PluginManagementActionError.notFound());

    final error = ApiError.nonSuccessCode(errorCode: 500, rawErrorString: null);
    when(() => service.command(pluginId: "plugin-a", request: request)).thenAnswer(
      (_) async => PluginManagementMutationResult.failure(error: error),
    );
    await cubit.refreshPlugin(pluginId: "plugin-a");
    expect((cubit.state as PluginManagementReady).actionError, PluginManagementActionError.request(error: error));
  });
}
