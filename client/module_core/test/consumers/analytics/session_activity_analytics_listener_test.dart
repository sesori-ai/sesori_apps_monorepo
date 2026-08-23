import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/src/consumers/analytics/session_activity_analytics_listener.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_event.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_preference.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:sesori_dart_core/src/services/models/product_analytics_state.dart";
import "package:sesori_dart_core/src/services/product_analytics_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockSessionDetailCubit() extends Mock implements SessionDetailCubit;

class _MockProductAnalyticsService() extends Mock implements ProductAnalyticsService;

class _FakeLifecycleSource({required LifecycleState initialState}) implements LifecycleSource {
  final BehaviorSubject<LifecycleState> states = BehaviorSubject.seeded(initialState);

  @override
  ValueStream<LifecycleState> get lifecycleStateStream => states.stream;

  Future<void> dispose() => states.close();
}

const _activeAnalyticsState = ProductAnalyticsState(
  preference: ProductAnalyticsPreferenceKnown(preference: ProductAnalyticsPreference.enabled),
  synchronization: ProductAnalyticsSynchronized(),
  availability: ProductAnalyticsActive(),
);

const _emptyState = SessionDetailState.loaded(
  messages: [
    MessageWithParts(
      info: Message.user(
        promptId: null,
        id: "empty-user-envelope",
        sessionID: "session-1",
        agent: null,
        time: null,
      ),
      parts: [],
    ),
  ],
  olderMessagesCursor: null,
  streamingText: {},
  sessionStatus: SessionStatus.idle(),
  pendingQuestions: [],
  pendingPermissions: [],
  sessionTitle: null,
  pluginId: "opencode",
  supportsPromptAttachments: false,
  agent: null,
  assistantAgentModel: null,
  children: [],
  childStatuses: {},
  isRootSession: true,
  isArchived: false,
  queuedMessages: [],
  sendingSubmission: null,
  availableAgents: [],
  availableProviders: [],
  availableCommands: [],
  selectedAgent: "build",
  selectedAgentModel: null,
  stagedCommand: null,
  isRefreshing: false,
);

const _nonEmptyState = SessionDetailState.loaded(
  messages: [],
  olderMessagesCursor: null,
  streamingText: {},
  sessionStatus: SessionStatus.busy(),
  pendingQuestions: [],
  pendingPermissions: [],
  sessionTitle: null,
  pluginId: "opencode",
  supportsPromptAttachments: false,
  agent: null,
  assistantAgentModel: null,
  children: [],
  childStatuses: {},
  isRootSession: true,
  isArchived: false,
  queuedMessages: [],
  sendingSubmission: null,
  availableAgents: [],
  availableProviders: [],
  availableCommands: [],
  selectedAgent: "build",
  selectedAgentModel: null,
  stagedCommand: null,
  isRefreshing: false,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const ProductAnalyticsEvent.analyticsSchemaReady());
    registerFallbackValue(DateTime.utc(2026));
  });

  late _MockSessionDetailCubit cubit;
  late _MockProductAnalyticsService analyticsService;
  late _FakeLifecycleSource lifecycleSource;
  late StreamController<SessionDetailState> sessionStates;
  late BehaviorSubject<ProductAnalyticsState> analyticsStates;
  late SessionDetailState currentSessionState;
  late ProductAnalyticsState currentAnalyticsState;
  late DateTime nowUtc;
  SessionActivityAnalyticsListener? listener;

  setUp(() {
    cubit = _MockSessionDetailCubit();
    analyticsService = _MockProductAnalyticsService();
    lifecycleSource = _FakeLifecycleSource(initialState: LifecycleState.resumed);
    sessionStates = StreamController<SessionDetailState>.broadcast();
    analyticsStates = BehaviorSubject.seeded(_activeAnalyticsState);
    currentSessionState = _emptyState;
    currentAnalyticsState = _activeAnalyticsState;
    nowUtc = DateTime.utc(2026, 7, 30, 10);

    when(() => cubit.state).thenAnswer((_) => currentSessionState);
    when(() => cubit.stream).thenAnswer((_) => sessionStates.stream);
    when(() => analyticsService.state).thenAnswer((_) => currentAnalyticsState);
    when(() => analyticsService.stateStream).thenAnswer((_) => analyticsStates.stream);
    when(
      () => analyticsService.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).thenAnswer((_) async => AnalyticsDeliveryResult.acceptedBySdk);
  });

  tearDown(() async {
    await listener?.dispose();
    await Future.wait([
      lifecycleSource.dispose(),
      sessionStates.close(),
      analyticsStates.close(),
    ]);
  });

  SessionActivityAnalyticsListener buildListener({required bool initialRouteVisible}) =>
      SessionActivityAnalyticsListener.withClock(
        sessionDetailCubit: cubit,
        lifecycleSource: lifecycleSource,
        productAnalyticsService: analyticsService,
        initialRouteVisible: initialRouteVisible,
        nowUtc: () => nowUtc,
      );

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test("reports only after the owning route is visible and the app is resumed", () async {
    currentSessionState = _nonEmptyState;
    lifecycleSource.states.add(LifecycleState.paused);
    listener = buildListener(initialRouteVisible: false);
    await settle();
    verifyNever(
      () => analyticsService.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    );

    listener!.setRouteVisible(isVisible: true);
    await settle();
    verifyNever(
      () => analyticsService.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    );

    lifecycleSource.states.add(LifecycleState.resumed);
    await settle();

    final event = verify(
      () => analyticsService.logEvent(
        event: captureAny(named: "event"),
        occurredAtUtc: nowUtc,
      ),
    ).captured.single;
    expect(
      event,
      const ProductAnalyticsEvent.sessionActivityViewed(
        activityState: AnalyticsActivityState.nonEmpty,
      ),
    );

    clearInteractions(analyticsService);
    sessionStates.add(currentSessionState);
    await settle();
    verifyNever(
      () => analyticsService.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    );
  });

  test("reports non-empty activity again after a resumed edge on a later UTC date", () async {
    currentSessionState = _nonEmptyState;
    listener = buildListener(initialRouteVisible: true);
    await settle();

    lifecycleSource.states.add(LifecycleState.paused);
    nowUtc = DateTime.utc(2026, 7, 31, 8);
    lifecycleSource.states.add(LifecycleState.resumed);
    await settle();

    final capturedDates = verify(
      () => analyticsService.logEvent(
        event: const ProductAnalyticsEvent.sessionActivityViewed(
          activityState: AnalyticsActivityState.nonEmpty,
        ),
        occurredAtUtc: captureAny(named: "occurredAtUtc"),
      ),
    ).captured.cast<DateTime>();
    expect(capturedDates, [DateTime.utc(2026, 7, 30, 10), DateTime.utc(2026, 7, 31, 8)]);
  });

  test("consumes empty only after acceptance and non-empty after bounded deferral", () async {
    var result = AnalyticsDeliveryResult.failed;
    when(
      () => analyticsService.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).thenAnswer((_) async => result);
    currentAnalyticsState = ProductAnalyticsState.initial;
    analyticsStates.add(currentAnalyticsState);
    listener = buildListener(initialRouteVisible: true);
    await settle();

    result = AnalyticsDeliveryResult.acceptedBySdk;
    currentAnalyticsState = _activeAnalyticsState;
    analyticsStates.add(currentAnalyticsState);
    await settle();

    currentSessionState = _nonEmptyState;
    result = AnalyticsDeliveryResult.deferredUntilPreference;
    sessionStates.add(currentSessionState);
    await settle();
    sessionStates.add(currentSessionState);
    listener!.setRouteVisible(isVisible: false);
    listener!.setRouteVisible(isVisible: true);
    await settle();

    final events = verify(
      () => analyticsService.logEvent(
        event: captureAny(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).captured.cast<ProductAnalyticsEvent>();
    expect(events, [
      const ProductAnalyticsEvent.sessionActivityViewed(
        activityState: AnalyticsActivityState.empty,
      ),
      const ProductAnalyticsEvent.sessionActivityViewed(
        activityState: AnalyticsActivityState.empty,
      ),
      const ProductAnalyticsEvent.sessionActivityViewed(
        activityState: AnalyticsActivityState.nonEmpty,
      ),
    ]);
  });

  test("empty activity retries when its pre-activation delivery settles after the active edge", () async {
    final firstDelivery = Completer<AnalyticsDeliveryResult>();
    var deliveryCount = 0;
    when(
      () => analyticsService.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).thenAnswer((_) {
      deliveryCount++;
      return deliveryCount == 1 ? firstDelivery.future : Future.value(AnalyticsDeliveryResult.acceptedBySdk);
    });
    currentAnalyticsState = ProductAnalyticsState.initial;
    analyticsStates.add(currentAnalyticsState);
    listener = buildListener(initialRouteVisible: true);
    await untilCalled(
      () => analyticsService.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    );

    currentAnalyticsState = _activeAnalyticsState;
    analyticsStates.add(currentAnalyticsState);
    firstDelivery.complete(AnalyticsDeliveryResult.failed);
    await settle();

    verify(
      () => analyticsService.logEvent(
        event: const ProductAnalyticsEvent.sessionActivityViewed(
          activityState: AnalyticsActivityState.empty,
        ),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).called(2);
  });

  test("empty activity retries when its pre-activation delivery throws after the active edge", () async {
    final firstDelivery = Completer<AnalyticsDeliveryResult>();
    var deliveryCount = 0;
    when(
      () => analyticsService.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).thenAnswer((_) {
      deliveryCount++;
      return deliveryCount == 1 ? firstDelivery.future : Future.value(AnalyticsDeliveryResult.acceptedBySdk);
    });
    currentAnalyticsState = ProductAnalyticsState.initial;
    analyticsStates.add(currentAnalyticsState);
    listener = buildListener(initialRouteVisible: true);
    await untilCalled(
      () => analyticsService.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    );

    currentAnalyticsState = _activeAnalyticsState;
    analyticsStates.add(currentAnalyticsState);
    firstDelivery.completeError(StateError("delivery failed"));
    await settle();

    verify(
      () => analyticsService.logEvent(
        event: const ProductAnalyticsEvent.sessionActivityViewed(
          activityState: AnalyticsActivityState.empty,
        ),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).called(2);
  });
}
