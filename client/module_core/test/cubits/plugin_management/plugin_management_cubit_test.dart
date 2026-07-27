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

  setUp(() {
    service = _MockPluginManagementService();
    snapshots = BehaviorSubject();
    when(() => service.snapshots).thenAnswer((_) => snapshots.stream);
    when(() => service.refresh()).thenAnswer((_) async {});
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
}
