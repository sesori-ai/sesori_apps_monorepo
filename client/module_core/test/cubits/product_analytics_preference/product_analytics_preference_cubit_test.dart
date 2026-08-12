import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _MockProductAnalyticsService extends Mock implements ProductAnalyticsService;

void main() {
  late _MockProductAnalyticsService service;
  late BehaviorSubject<ProductAnalyticsState> states;
  late ProductAnalyticsPreferenceCubit cubit;

  setUpAll(() {
    registerFallbackValue(ProductAnalyticsPreference.disabled);
  });

  setUp(() {
    service = _MockProductAnalyticsService();
    states = BehaviorSubject.seeded(ProductAnalyticsState.initial);
    when(() => service.state).thenAnswer((_) => states.value);
    when(() => service.stateStream).thenAnswer((_) => states.stream);
    when(
      () => service.setPreference(preference: any(named: "preference")),
    ).thenAnswer((_) async {});
    when(service.refreshPreference).thenAnswer((_) async {});
    when(service.retryPendingDisable).thenAnswer((_) async {});
    cubit = ProductAnalyticsPreferenceCubit(service: service);
  });

  tearDown(() async {
    await cubit.close();
    await states.close();
  });

  test("replays service state changes", () async {
    const nextState = ProductAnalyticsState(
      preference: ProductAnalyticsPreferenceUnknown(),
      synchronization: ProductAnalyticsSynchronizationFailed(),
      availability: ProductAnalyticsInactive(reason: ProductAnalyticsInactiveReason.requestFailure),
    );

    final emitted = cubit.stream.first;
    states.add(nextState);

    expect(await emitted, same(nextState));
  });

  test("delegates closed toggle and retry intents", () async {
    await cubit.setEnabled(enabled: false);
    await cubit.setEnabled(enabled: true);
    await cubit.refresh();
    await cubit.retryPendingDisable();

    verify(
      () => service.setPreference(preference: ProductAnalyticsPreference.disabled),
    ).called(1);
    verify(
      () => service.setPreference(preference: ProductAnalyticsPreference.enabled),
    ).called(1);
    verify(service.refreshPreference).called(1);
    verify(service.retryPendingDisable).called(1);
  });
}
