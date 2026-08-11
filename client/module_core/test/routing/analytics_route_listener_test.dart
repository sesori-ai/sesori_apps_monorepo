import "dart:async";
import "dart:collection";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _FakeRouteSource implements RouteSource {
  final BehaviorSubject<AppRouteDef?> routes;

  _FakeRouteSource({required AppRouteDef? initialRoute}) : routes = BehaviorSubject.seeded(initialRoute);

  @override
  ValueStream<AppRouteDef?> get currentRouteStream => routes.stream;

  @override
  String? currentLocation;

  void emit({required AppRouteDef? route}) => routes.add(route);

  Future<void> dispose() => routes.close();
}

class _FakeProductAnalyticsService extends Mock implements ProductAnalyticsService {
  final BehaviorSubject<ProductAnalyticsState> states;
  final events = <ProductAnalyticsEvent>[];
  final occurredAtUtc = <DateTime>[];
  int readinessCalls = 0;
  Queue<Future<void>> readinessResults = Queue<Future<void>>();
  Completer<AnalyticsDeliveryResult>? deliveryCompleter;
  AnalyticsDeliveryResult deliveryResult = AnalyticsDeliveryResult.acceptedBySdk;

  _FakeProductAnalyticsService({required ProductAnalyticsState initialState})
    : states = BehaviorSubject.seeded(initialState);

  @override
  ValueStream<ProductAnalyticsState> get stateStream => states.stream;

  @override
  ProductAnalyticsState get state => states.value;

  @override
  Future<void> markPostSplashReady() {
    readinessCalls += 1;
    return readinessResults.isEmpty ? Future.value() : readinessResults.removeFirst();
  }

  @override
  Future<AnalyticsDeliveryResult> logEvent({
    required ProductAnalyticsEvent event,
    required DateTime occurredAtUtc,
  }) async {
    events.add(event);
    this.occurredAtUtc.add(occurredAtUtc);
    final completer = deliveryCompleter;
    if (completer != null) return completer.future;
    return deliveryResult;
  }

  void emit({required ProductAnalyticsState state}) => states.add(state);

  Future<void> disposeFake() => states.close();
}

ProductAnalyticsState _activeState() => const ProductAnalyticsState(
  preference: ProductAnalyticsPreferenceUnknown(),
  synchronization: ProductAnalyticsSynchronized(),
  availability: ProductAnalyticsActive(),
);

ProductAnalyticsState _inactiveState() => const ProductAnalyticsState(
  preference: ProductAnalyticsPreferenceUnknown(),
  synchronization: ProductAnalyticsNotSynchronized(),
  availability: ProductAnalyticsInactive(reason: ProductAnalyticsInactiveReason.preferenceUnknown),
);

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late _FakeRouteSource routeSource;
  late _FakeProductAnalyticsService service;
  late AnalyticsRouteListener listener;

  tearDown(() async {
    await listener.dispose();
    await routeSource.dispose();
    await service.disposeFake();
  });

  test("maps every non-splash route to a pinned screen and deduplicates unchanged screen groups", () async {
    routeSource = _FakeRouteSource(initialRoute: AppRouteDef.splash);
    service = _FakeProductAnalyticsService(initialState: _activeState());
    listener = AnalyticsRouteListener(routeSource: routeSource, analyticsService: service);
    await listener.start();
    await _flush();

    expect(service.readinessCalls, 0);
    expect(service.events, isEmpty);

    const sequence = [
      AppRouteDef.login,
      AppRouteDef.projects,
      AppRouteDef.settings,
      AppRouteDef.settingsNotifications,
      AppRouteDef.settingsHarnesses,
      AppRouteDef.settingsDefaultInput,
      AppRouteDef.settingsProfile,
      AppRouteDef.sessions,
      AppRouteDef.newSession,
      AppRouteDef.sessionDetail,
      AppRouteDef.sessionDiffs,
    ];
    for (final route in sequence) {
      routeSource.emit(route: route);
      await _flush();
    }

    expect(service.readinessCalls, sequence.length);
    expect(
      service.events.whereType<ProductScreenViewedEvent>().map((event) => event.screen),
      [
        AnalyticsScreen.login,
        AnalyticsScreen.projects,
        AnalyticsScreen.settings,
        AnalyticsScreen.settingsNotifications,
        AnalyticsScreen.settings,
        AnalyticsScreen.settingsProfile,
        AnalyticsScreen.sessions,
        AnalyticsScreen.newSession,
        AnalyticsScreen.sessionDetail,
        AnalyticsScreen.sessionDiffs,
      ],
    );
    expect(AppRouteDef.values, hasLength(sequence.length + 1));
  });

  test("retains the latest inactive screen without duplicating a reported route", () async {
    routeSource = _FakeRouteSource(initialRoute: AppRouteDef.splash);
    service = _FakeProductAnalyticsService(initialState: _inactiveState());
    listener = AnalyticsRouteListener(routeSource: routeSource, analyticsService: service);
    await listener.start();

    routeSource
      ..emit(route: AppRouteDef.projects)
      ..emit(route: AppRouteDef.sessionDetail);
    await _flush();
    expect(service.events, isEmpty);

    service.emit(state: _activeState());
    await _flush();
    expect(service.events.whereType<ProductScreenViewedEvent>().single.screen, AnalyticsScreen.sessionDetail);

    service.emit(state: _activeState());
    await _flush();
    expect(service.events, hasLength(1));

    service.emit(state: _inactiveState());
    service.emit(state: _activeState());
    await _flush();
    expect(service.events, hasLength(1));
  });

  test("captures the screen occurrence time before readiness completes", () async {
    routeSource = _FakeRouteSource(initialRoute: AppRouteDef.splash);
    service = _FakeProductAnalyticsService(initialState: _activeState());
    final readiness = Completer<void>();
    service.readinessResults.add(readiness.future);
    listener = AnalyticsRouteListener(routeSource: routeSource, analyticsService: service);
    await listener.start();

    routeSource.emit(route: AppRouteDef.projects);
    await Future<void>.delayed(Duration.zero);
    final afterObservation = DateTime.now().toUtc();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    readiness.complete();
    await _flush();

    expect(service.occurredAtUtc.single.isAfter(afterObservation), isFalse);
  });

  test("a failed intervening screen does not suppress a later return", () async {
    routeSource = _FakeRouteSource(initialRoute: AppRouteDef.splash);
    service = _FakeProductAnalyticsService(initialState: _activeState());
    listener = AnalyticsRouteListener(routeSource: routeSource, analyticsService: service);
    await listener.start();

    routeSource.emit(route: AppRouteDef.settings);
    await _flush();
    service.deliveryResult = AnalyticsDeliveryResult.failed;
    routeSource.emit(route: AppRouteDef.settingsNotifications);
    await _flush();
    service.deliveryResult = AnalyticsDeliveryResult.acceptedBySdk;
    routeSource.emit(route: AppRouteDef.settings);
    await _flush();

    expect(service.events.whereType<ProductScreenViewedEvent>().map((event) => event.screen), [
      AnalyticsScreen.settings,
      AnalyticsScreen.settingsNotifications,
      AnalyticsScreen.settings,
    ]);
  });

  test("a delayed first readiness call cannot overwrite a newer route", () async {
    routeSource = _FakeRouteSource(initialRoute: AppRouteDef.splash);
    service = _FakeProductAnalyticsService(initialState: _activeState());
    final firstReadiness = Completer<void>();
    service.readinessResults
      ..add(firstReadiness.future)
      ..add(Future.value());
    listener = AnalyticsRouteListener(routeSource: routeSource, analyticsService: service);
    await listener.start();

    routeSource.emit(route: AppRouteDef.projects);
    await Future<void>.delayed(Duration.zero);
    routeSource.emit(route: AppRouteDef.sessionDetail);
    await _flush();
    firstReadiness.complete();
    await _flush();

    expect(service.events.whereType<ProductScreenViewedEvent>().map((event) => event.screen), [
      AnalyticsScreen.sessionDetail,
    ]);
  });

  test("activation and route completion racing for one screen emit only once", () async {
    routeSource = _FakeRouteSource(initialRoute: AppRouteDef.splash);
    service = _FakeProductAnalyticsService(initialState: _inactiveState());
    final readiness = Completer<void>();
    final delivery = Completer<AnalyticsDeliveryResult>();
    service.readinessResults.add(readiness.future);
    service.deliveryCompleter = delivery;
    listener = AnalyticsRouteListener(routeSource: routeSource, analyticsService: service);
    await listener.start();

    routeSource.emit(route: AppRouteDef.projects);
    await Future<void>.delayed(Duration.zero);
    service.emit(state: _activeState());
    await Future<void>.delayed(Duration.zero);
    readiness.complete();
    await Future<void>.delayed(Duration.zero);
    delivery.complete(AnalyticsDeliveryResult.acceptedBySdk);
    await _flush();

    expect(service.events.whereType<ProductScreenViewedEvent>().map((event) => event.screen), [
      AnalyticsScreen.projects,
    ]);
  });

  test("an accepted in-flight delivery remains deduplicated after temporary inactivity", () async {
    routeSource = _FakeRouteSource(initialRoute: AppRouteDef.splash);
    service = _FakeProductAnalyticsService(initialState: _activeState());
    final delivery = Completer<AnalyticsDeliveryResult>();
    service.deliveryCompleter = delivery;
    listener = AnalyticsRouteListener(routeSource: routeSource, analyticsService: service);
    await listener.start();

    routeSource.emit(route: AppRouteDef.projects);
    await Future<void>.delayed(Duration.zero);
    service.emit(state: _inactiveState());
    delivery.complete(AnalyticsDeliveryResult.acceptedBySdk);
    await _flush();
    service.deliveryCompleter = null;
    service.emit(state: _activeState());
    await _flush();

    expect(service.events.whereType<ProductScreenViewedEvent>(), hasLength(1));
  });

  test("a timed-out screen delivery clears the in-flight guard for a later retry", () async {
    routeSource = _FakeRouteSource(initialRoute: AppRouteDef.splash);
    service = _FakeProductAnalyticsService(initialState: _activeState());
    service.deliveryCompleter = Completer<AnalyticsDeliveryResult>();
    listener = AnalyticsRouteListener.withDeliveryDeadline(
      routeSource: routeSource,
      analyticsService: service,
      deliveryDeadline: const Duration(milliseconds: 1),
    );
    await listener.start();

    routeSource.emit(route: AppRouteDef.projects);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    service.deliveryCompleter = null;
    service.emit(state: _inactiveState());
    service.emit(state: _activeState());
    await _flush();

    expect(service.events.whereType<ProductScreenViewedEvent>().map((event) => event.screen), [
      AnalyticsScreen.projects,
      AnalyticsScreen.projects,
    ]);
  });

  test("null and splash routes clear the current screen before later activation", () async {
    routeSource = _FakeRouteSource(initialRoute: AppRouteDef.splash);
    service = _FakeProductAnalyticsService(initialState: _inactiveState());
    listener = AnalyticsRouteListener(routeSource: routeSource, analyticsService: service);
    await listener.start();

    routeSource.emit(route: AppRouteDef.projects);
    await _flush();
    routeSource.emit(route: null);
    service.emit(state: _activeState());
    await _flush();
    expect(service.events, isEmpty);

    service.emit(state: _inactiveState());
    routeSource.emit(route: AppRouteDef.settings);
    await _flush();
    routeSource.emit(route: AppRouteDef.splash);
    service.emit(state: _activeState());
    await _flush();
    expect(service.events, isEmpty);
  });
}
