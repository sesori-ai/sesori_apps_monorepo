import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_event.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_preference.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:sesori_dart_core/src/services/loaded_state_analytics_reporter.dart";
import "package:sesori_dart_core/src/services/models/product_analytics_state.dart";
import "package:sesori_dart_core/src/services/product_analytics_service.dart";
import "package:test/test.dart";

class _MockProductAnalyticsService() extends Mock implements ProductAnalyticsService;

const _activeState = ProductAnalyticsState(
  preference: ProductAnalyticsPreferenceKnown(preference: ProductAnalyticsPreference.enabled),
  synchronization: ProductAnalyticsSynchronized(),
  availability: ProductAnalyticsActive(),
);

void main() {
  setUpAll(() {
    registerFallbackValue(const ProductAnalyticsEvent.analyticsSchemaReady());
    registerFallbackValue(DateTime.utc(2026));
  });

  late _MockProductAnalyticsService service;
  late BehaviorSubject<ProductAnalyticsState> states;
  late LoadedStateAnalyticsReporter reporter;

  setUp(() {
    service = _MockProductAnalyticsService();
    states = BehaviorSubject<ProductAnalyticsState>.seeded(ProductAnalyticsState.initial);
    when(() => service.state).thenAnswer((_) => states.value);
    when(() => service.stateStream).thenAnswer((_) => states.stream);
    reporter = LoadedStateAnalyticsReporter(
      productAnalyticsService: service,
      eventForClassification: ({required classification}) => ProductAnalyticsEvent.projectInventoryLoaded(
        inventoryState: classification == LoadedStateAnalyticsClassification.empty
            ? AnalyticsInventoryState.empty
            : AnalyticsInventoryState.nonEmpty,
      ),
      eventDescription: "project inventory",
    );
  });

  tearDown(() async {
    await reporter.close();
    await states.close();
  });

  void stubResult(AnalyticsDeliveryResult result) {
    when(
      () => service.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).thenAnswer((_) async => result);
  }

  test("accepted consumes independent empty and non-empty guards", () async {
    stubResult(AnalyticsDeliveryResult.acceptedBySdk);
    final emptyTime = DateTime.utc(2026, 1, 1);
    final nonEmptyTime = DateTime.utc(2026, 1, 2);

    reporter
      ..reportLoaded(isEmpty: true, occurredAtUtc: emptyTime)
      ..reportLoaded(isEmpty: true, occurredAtUtc: DateTime.utc(2026, 1, 3));
    await Future<void>.delayed(Duration.zero);
    reporter
      ..reportLoaded(isEmpty: false, occurredAtUtc: nonEmptyTime)
      ..reportLoaded(isEmpty: false, occurredAtUtc: DateTime.utc(2026, 1, 4));
    await Future<void>.delayed(Duration.zero);

    final captured = verify(
      () => service.logEvent(
        event: captureAny(named: "event"),
        occurredAtUtc: captureAny(named: "occurredAtUtc"),
      ),
    ).captured;
    expect(captured, [
      const ProductAnalyticsEvent.projectInventoryLoaded(inventoryState: AnalyticsInventoryState.empty),
      emptyTime,
      const ProductAnalyticsEvent.projectInventoryLoaded(inventoryState: AnalyticsInventoryState.nonEmpty),
      nonEmptyTime,
    ]);
  });

  test("deferred consumes only non-empty", () async {
    stubResult(AnalyticsDeliveryResult.deferredUntilPreference);
    final emptyTime = DateTime.utc(2026, 2, 1);
    final nonEmptyTime = DateTime.utc(2026, 2, 2);

    reporter.reportLoaded(isEmpty: true, occurredAtUtc: emptyTime);
    await Future<void>.delayed(Duration.zero);
    reporter.reportLoaded(isEmpty: true, occurredAtUtc: emptyTime);
    await Future<void>.delayed(Duration.zero);
    reporter.reportLoaded(isEmpty: false, occurredAtUtc: nonEmptyTime);
    await Future<void>.delayed(Duration.zero);
    reporter.reportLoaded(isEmpty: false, occurredAtUtc: nonEmptyTime);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => service.logEvent(
        event: const ProductAnalyticsEvent.projectInventoryLoaded(inventoryState: AnalyticsInventoryState.empty),
        occurredAtUtc: emptyTime,
      ),
    ).called(2);
    verify(
      () => service.logEvent(
        event: const ProductAnalyticsEvent.projectInventoryLoaded(inventoryState: AnalyticsInventoryState.nonEmpty),
        occurredAtUtc: nonEmptyTime,
      ),
    ).called(1);
  });

  test("activation retries current empty without changing occurrence time", () async {
    stubResult(AnalyticsDeliveryResult.failed);
    final occurredAtUtc = DateTime.utc(2026, 3, 1);
    reporter.reportLoaded(isEmpty: true, occurredAtUtc: occurredAtUtc);
    await Future<void>.delayed(Duration.zero);

    when(
      () => service.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).thenAnswer((_) async => AnalyticsDeliveryResult.acceptedBySdk);
    states.add(_activeState);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => service.logEvent(
        event: const ProductAnalyticsEvent.projectInventoryLoaded(inventoryState: AnalyticsInventoryState.empty),
        occurredAtUtc: occurredAtUtc,
      ),
    ).called(2);
  });

  test("missed activation race retries after failed future with same time", () async {
    final first = Completer<AnalyticsDeliveryResult>();
    var attempts = 0;
    when(
      () => service.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).thenAnswer((_) => ++attempts == 1 ? first.future : Future.value(AnalyticsDeliveryResult.acceptedBySdk));
    final occurredAtUtc = DateTime.utc(2026, 4, 1);
    reporter.reportLoaded(isEmpty: true, occurredAtUtc: occurredAtUtc);
    states.add(_activeState);
    first.complete(AnalyticsDeliveryResult.failed);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => service.logEvent(
        event: any(named: "event"),
        occurredAtUtc: occurredAtUtc,
      ),
    ).called(2);
  });

  test("throw is isolated and missed activation retries current classification", () async {
    var attempts = 0;
    when(
      () => service.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).thenAnswer(
      (_) => ++attempts == 1 ? Future.error(StateError("sdk")) : Future.value(AnalyticsDeliveryResult.acceptedBySdk),
    );
    final occurredAtUtc = DateTime.utc(2026, 5, 1);
    reporter.reportLoaded(isEmpty: true, occurredAtUtc: occurredAtUtc);
    states.add(_activeState);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(attempts, 2);
  });

  test("activation retries only current loaded classification", () async {
    stubResult(AnalyticsDeliveryResult.failed);
    reporter.reportLoaded(isEmpty: true, occurredAtUtc: DateTime.utc(2026, 6, 1));
    await Future<void>.delayed(Duration.zero);
    reporter.reportLoaded(isEmpty: false, occurredAtUtc: DateTime.utc(2026, 6, 2));
    await Future<void>.delayed(Duration.zero);
    clearInteractions(service);

    states.add(_activeState);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => service.logEvent(
        event: const ProductAnalyticsEvent.projectInventoryLoaded(inventoryState: AnalyticsInventoryState.nonEmpty),
        occurredAtUtc: DateTime.utc(2026, 6, 2),
      ),
    ).called(1);
    verifyNever(
      () => service.logEvent(
        event: const ProductAnalyticsEvent.projectInventoryLoaded(inventoryState: AnalyticsInventoryState.empty),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    );
  });

  test("close cancels activation retry", () async {
    stubResult(AnalyticsDeliveryResult.failed);
    reporter.reportLoaded(isEmpty: true, occurredAtUtc: DateTime.utc(2026, 7, 1));
    await Future<void>.delayed(Duration.zero);
    clearInteractions(service);

    await reporter.close();
    states.add(_activeState);
    await Future<void>.delayed(Duration.zero);

    verifyNever(
      () => service.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    );
  });
}
