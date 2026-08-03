import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/cubits/pull_request_refresh_settings/pull_request_refresh_settings_cubit.dart";
import "package:sesori_dart_core/src/cubits/pull_request_refresh_settings/pull_request_refresh_settings_state.dart";
import "package:sesori_dart_core/src/repositories/models/pull_request_refresh_settings_result.dart";
import "package:sesori_dart_core/src/services/pull_request_refresh_settings_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockPullRequestRefreshSettingsService extends Mock implements PullRequestRefreshSettingsService {}

void main() {
  late _MockPullRequestRefreshSettingsService service;

  setUpAll(() {
    registerFallbackValue(const PullRequestRefreshSettingsRequest(intervalSeconds: 30));
  });

  setUp(() {
    service = _MockPullRequestRefreshSettingsService();
  });

  test("loads the committed bridge value", () async {
    _stubLoad(service, intervalSeconds: 30);
    final cubit = PullRequestRefreshSettingsCubit(service: service);
    addTearDown(cubit.close);

    await _waitForState<PullRequestRefreshSettingsReady>(cubit);

    expect((cubit.state as PullRequestRefreshSettingsReady).intervalSeconds, 30);
  });

  test("surfaces unsupported old bridges and retryable load failures", () async {
    when(service.load).thenAnswer((_) async => const PullRequestRefreshSettingsLoadUnsupported());
    final unsupported = PullRequestRefreshSettingsCubit(service: service);
    addTearDown(unsupported.close);
    await _waitForState<PullRequestRefreshSettingsUnsupported>(unsupported);

    when(service.load).thenAnswer(
      (_) async => PullRequestRefreshSettingsLoadFailure(error: ApiError.generic()),
    );
    final failed = PullRequestRefreshSettingsCubit(service: service);
    addTearDown(failed.close);
    await _waitForState<PullRequestRefreshSettingsFailure>(failed);

    _stubLoad(service, intervalSeconds: 30);
    await failed.refresh();
    expect(failed.state, isA<PullRequestRefreshSettingsReady>());
  });

  test("invalid input dispatches no mutation", () async {
    _stubLoad(service, intervalSeconds: 30);
    when(() => service.planUpdate(input: "bad")).thenReturn(const PullRequestRefreshSettingsUpdateInvalid());
    final cubit = PullRequestRefreshSettingsCubit(service: service);
    addTearDown(cubit.close);
    await _waitForState<PullRequestRefreshSettingsReady>(cubit);

    await cubit.update(input: "bad");

    expect((cubit.state as PullRequestRefreshSettingsReady).mutation, isA<PullRequestRefreshSettingsMutationFailed>());
    verifyNever(() => service.update(request: any(named: "request")));
  });

  test("delegates input validation to the service plan", () async {
    _stubLoad(service, intervalSeconds: 30);
    when(() => service.planUpdate(input: "14")).thenReturn(const PullRequestRefreshSettingsUpdateInvalid());
    _stubPlan(service, input: "45", intervalSeconds: 45);
    final cubit = PullRequestRefreshSettingsCubit(service: service);
    addTearDown(cubit.close);
    await _waitForState<PullRequestRefreshSettingsReady>(cubit);

    expect(
      cubit.validateUpdateInput(input: "14"),
      PullRequestRefreshSettingsInputValidation.invalid,
    );
    expect(
      cubit.validateUpdateInput(input: "45"),
      PullRequestRefreshSettingsInputValidation.valid,
    );
    verify(() => service.planUpdate(input: "14")).called(1);
    verify(() => service.planUpdate(input: "45")).called(1);
  });

  test("successful update publishes the bridge-committed value", () async {
    _stubLoad(service, intervalSeconds: 30);
    _stubPlan(service, input: "45", intervalSeconds: 45);
    when(
      () => service.update(request: any(named: "request")),
    ).thenAnswer(
      (_) async => const PullRequestRefreshSettingsMutationCommitted(
        response: PullRequestRefreshSettingsResponse(intervalSeconds: 46),
      ),
    );
    final cubit = PullRequestRefreshSettingsCubit(service: service);
    addTearDown(cubit.close);
    await _waitForState<PullRequestRefreshSettingsReady>(cubit);

    await cubit.update(input: "45");

    final state = cubit.state as PullRequestRefreshSettingsReady;
    expect(state.intervalSeconds, 46);
    expect(state.mutation, isA<PullRequestRefreshSettingsMutationIdle>());
  });

  test("uncertain mutation refreshes before another update can be sent", () async {
    final reconciliation = Completer<PullRequestRefreshSettingsLoadResult>();
    var loadCalls = 0;
    when(service.load).thenAnswer((_) {
      loadCalls++;
      return loadCalls == 1
          ? Future.value(
              const PullRequestRefreshSettingsLoadSupported(
                response: PullRequestRefreshSettingsResponse(intervalSeconds: 30),
              ),
            )
          : reconciliation.future;
    });
    _stubPlan(service, input: "45", intervalSeconds: 45);
    _stubPlan(service, input: "60", intervalSeconds: 60);
    var updateCalls = 0;
    when(
      () => service.update(request: any(named: "request")),
    ).thenAnswer((_) async {
      updateCalls++;
      return updateCalls == 1
          ? const PullRequestRefreshSettingsMutationUncertain()
          : const PullRequestRefreshSettingsMutationCommitted(
              response: PullRequestRefreshSettingsResponse(intervalSeconds: 60),
            );
    });
    final cubit = PullRequestRefreshSettingsCubit(service: service);
    addTearDown(cubit.close);
    await _waitForState<PullRequestRefreshSettingsReady>(cubit);

    final firstUpdate = cubit.update(input: "45");
    await _waitUntil(() => loadCalls == 2);
    await cubit.update(input: "60");
    expect(updateCalls, 1);

    reconciliation.complete(
      PullRequestRefreshSettingsLoadFailure(error: ApiError.generic()),
    );
    await firstUpdate;
    expect(cubit.state, isA<PullRequestRefreshSettingsUncertain>());

    _stubLoad(service, intervalSeconds: 45);
    await cubit.refresh();
    await cubit.update(input: "60");
    expect(updateCalls, 2);
    expect((cubit.state as PullRequestRefreshSettingsReady).intervalSeconds, 60);
  });
}

void _stubLoad(_MockPullRequestRefreshSettingsService service, {required int intervalSeconds}) {
  when(service.load).thenAnswer(
    (_) async => PullRequestRefreshSettingsLoadSupported(
      response: PullRequestRefreshSettingsResponse(intervalSeconds: intervalSeconds),
    ),
  );
}

void _stubPlan(
  _MockPullRequestRefreshSettingsService service, {
  required String input,
  required int intervalSeconds,
}) {
  when(
    () => service.planUpdate(input: input),
  ).thenReturn(
    PullRequestRefreshSettingsUpdateRequest(
      request: PullRequestRefreshSettingsRequest(intervalSeconds: intervalSeconds),
    ),
  );
}

Future<void> _waitForState<T extends PullRequestRefreshSettingsState>(PullRequestRefreshSettingsCubit cubit) async {
  if (cubit.state is T) return;
  await cubit.stream.firstWhere((state) => state is T);
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail("Condition was not reached");
}
