import "dart:async";

import "package:bloc/bloc.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:sesori_dart_core/testing.dart";
import "package:test/test.dart";

export "package:sesori_dart_core/testing.dart";

MockProductAnalyticsService stubbedProductAnalyticsService() {
  final mock = MockProductAnalyticsService();
  final states = BehaviorSubject<ProductAnalyticsState>.seeded(ProductAnalyticsState.initial);
  addTearDown(states.close);
  when(
    () => mock.logEvent(
      event: any(named: "event"),
      occurredAtUtc: any(named: "occurredAtUtc"),
    ),
  ).thenAnswer((_) async => AnalyticsDeliveryResult.acceptedBySdk);
  when(() => mock.state).thenAnswer((_) => states.value);
  when(() => mock.stateStream).thenAnswer((_) => states.stream);
  return mock;
}

void stubProductAnalyticsService({required MockProductAnalyticsService service}) {
  final states = BehaviorSubject<ProductAnalyticsState>.seeded(ProductAnalyticsState.initial);
  addTearDown(states.close);
  when(
    () => service.logEvent(
      event: any(named: "event"),
      occurredAtUtc: any(named: "occurredAtUtc"),
    ),
  ).thenAnswer((_) async => AnalyticsDeliveryResult.acceptedBySdk);
  when(() => service.state).thenAnswer((_) => states.value);
  when(() => service.stateStream).thenAnswer((_) => states.stream);
}

void registerAllFallbackValues() => registerCoreFallbackValues();

Future<State> awaitState<State>({
  required BlocBase<State> cubit,
  required bool Function(State state) predicate,
  required String description,
}) async {
  if (predicate(cubit.state)) return cubit.state;
  try {
    return await cubit.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  } on TimeoutException {
    throw StateError("Timed out waiting for $description; current state: ${cubit.state}");
  }
}
