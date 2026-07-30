import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/src/consumers/analytics/session_activity_analytics_consumer.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_event.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_preference.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:sesori_dart_core/src/routing/app_routes.dart";
import "package:sesori_dart_core/src/services/models/product_analytics_state.dart";
import "package:sesori_dart_core/src/services/product_analytics_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class _MockSessionDetailCubit extends Mock implements SessionDetailCubit {}

class _MockProductAnalyticsService extends Mock implements ProductAnalyticsService {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AnalyticsSchemaReadyEvent());
  });

  late _MockSessionDetailCubit cubit;
  late BehaviorSubject<SessionDetailState> states;
  late MockRouteSource routeSource;
  late FakeLifecycleSource lifecycleSource;
  late _MockProductAnalyticsService analyticsService;
  late BehaviorSubject<ProductAnalyticsState> analyticsStates;
  late List<ProductAnalyticsEvent> events;
  late List<DateTime> occurrenceTimes;
  late List<AnalyticsDeliveryResult> results;
  late DateTime now;
  late SessionActivityAnalyticsConsumer consumer;

  setUp(() {
    cubit = _MockSessionDetailCubit();
    states = BehaviorSubject.seeded(const SessionDetailState.loading());
    routeSource = MockRouteSource(initialRoute: AppRouteDef.sessionDetail);
    lifecycleSource = FakeLifecycleSource();
    analyticsService = _MockProductAnalyticsService();
    analyticsStates = BehaviorSubject.seeded(_inactiveAnalyticsState);
    events = [];
    occurrenceTimes = [];
    results = [AnalyticsDeliveryResult.acceptedBySdk];
    now = DateTime.utc(2026, 7, 30, 12);

    when(() => cubit.state).thenAnswer((_) => states.value);
    when(() => cubit.stream).thenAnswer((_) => states.stream);
    when(() => analyticsService.stateStream).thenAnswer((_) => analyticsStates.stream);
    when(() => analyticsService.state).thenAnswer((_) => analyticsStates.value);
    when(
      () => analyticsService.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).thenAnswer((invocation) async {
      events.add(invocation.namedArguments[#event] as ProductAnalyticsEvent);
      occurrenceTimes.add(invocation.namedArguments[#occurredAtUtc] as DateTime);
      return results.length == 1 ? results.single : results.removeAt(0);
    });
  });

  tearDown(() async {
    await consumer.dispose();
    await states.close();
    await analyticsStates.close();
    lifecycleSource.close();
  });

  void createConsumer() {
    consumer = SessionActivityAnalyticsConsumer.withClock(
      sessionDetailCubit: cubit,
      routeSource: routeSource,
      lifecycleSource: lifecycleSource,
      productAnalyticsService: analyticsService,
      routeVisible: true,
      now: () => now,
    );
  }

  test("reports the first visible foreground empty snapshot only once", () async {
    createConsumer();

    states.add(_loaded());
    await _settle();
    states.add(_loaded());
    lifecycleSource.emitState(LifecycleState.inactive);
    lifecycleSource.emitState(LifecycleState.resumed);
    await _settle();

    expect(events, hasLength(1));
    expect(
      events.single,
      isA<SessionActivityViewedEvent>().having(
        (event) => event.activityState,
        "activityState",
        AnalyticsActivityState.empty,
      ),
    );
    expect(occurrenceTimes, [now]);
  });

  test("waits for topmost route and resumed lifecycle before reporting activity", () async {
    routeSource.emitRoute(AppRouteDef.sessionDiffs);
    lifecycleSource.emitState(LifecycleState.paused);
    states.add(_loaded(status: const SessionStatus.busy()));
    createConsumer();
    await _settle();

    routeSource.emitRoute(AppRouteDef.sessionDetail);
    await _settle();
    expect(events, isEmpty);

    lifecycleSource.emitState(LifecycleState.resumed);
    await _settle();

    expect(events, hasLength(1));
    expect(
      events.single,
      isA<SessionActivityViewedEvent>().having(
        (event) => event.activityState,
        "activityState",
        AnalyticsActivityState.nonEmpty,
      ),
    );
  });

  test("reports non-empty activity at most once per UTC date and again after a later resume", () async {
    states.add(_loaded(status: const SessionStatus.retry(attempt: 1, message: "private", next: 2)));
    createConsumer();
    await _settle();

    states.add(_loaded(status: const SessionStatus.busy()));
    routeSource.emitRoute(AppRouteDef.sessionDiffs);
    routeSource.emitRoute(AppRouteDef.sessionDetail);
    await _settle();
    expect(events, hasLength(1));

    now = DateTime.utc(2026, 7, 31, 1);
    lifecycleSource.emitState(LifecycleState.paused);
    lifecycleSource.emitState(LifecycleState.resumed);
    await _settle();

    expect(events, hasLength(2));
    expect(occurrenceTimes, [DateTime.utc(2026, 7, 30, 12), DateTime.utc(2026, 7, 31, 1)]);
  });

  test("accepted and deferred deliveries consume the matching guards", () async {
    results = [AnalyticsDeliveryResult.deferredUntilPreference];
    states.add(_loaded(messages: [_message()]));
    createConsumer();
    await _settle();

    states.add(_loaded(messages: [_message()]));
    lifecycleSource.emitState(LifecycleState.inactive);
    lifecycleSource.emitState(LifecycleState.resumed);
    await _settle();

    expect(events, hasLength(1));
  });

  test("failed delivery leaves the guard available for a later state evaluation", () async {
    results = [AnalyticsDeliveryResult.failed, AnalyticsDeliveryResult.acceptedBySdk];
    states.add(_loaded(pendingPermissions: [_permission]));
    createConsumer();
    await _settle();

    states.add(_loaded(pendingPermissions: [_permission]));
    await _settle();
    states.add(_loaded(pendingPermissions: [_permission]));
    await _settle();

    expect(events, hasLength(2));
  });

  test("active failed delivery remains operationally observable", () async {
    results = [AnalyticsDeliveryResult.failed];
    analyticsStates.add(_activeAnalyticsState);
    states.add(_loaded());
    final logLines = <String>[];

    await runZoned(
      () async {
        createConsumer();
        await _settle();
      },
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logLines.add(line)),
    );

    expect(logLines, contains("Failed to deliver session activity analytics event"));
  });

  test("retries an empty snapshot when analytics becomes active", () async {
    results = [AnalyticsDeliveryResult.failed, AnalyticsDeliveryResult.acceptedBySdk];
    states.add(_loaded());
    createConsumer();
    await _settle();

    analyticsStates.add(_activeAnalyticsState);
    await _settle();

    expect(events, hasLength(2));
  });

  test("waits until the owning route instance is visible", () async {
    states.add(_loaded(status: const SessionStatus.busy()));
    consumer = SessionActivityAnalyticsConsumer.withClock(
      sessionDetailCubit: cubit,
      routeSource: routeSource,
      lifecycleSource: lifecycleSource,
      productAnalyticsService: analyticsService,
      routeVisible: false,
      now: () => now,
    );
    await _settle();
    expect(events, isEmpty);

    consumer.setRouteVisible(isVisible: true);
    await _settle();

    expect(events, hasLength(1));
  });

  test("pending questions are classified as non-empty activity", () async {
    states.add(_loaded(pendingQuestions: [_question]));
    createConsumer();
    await _settle();

    expect(
      events.single,
      isA<SessionActivityViewedEvent>().having(
        (event) => event.activityState,
        "activityState",
        AnalyticsActivityState.nonEmpty,
      ),
    );
  });
}

SessionDetailState _loaded({
  List<MessageWithParts> messages = const [],
  SessionStatus status = const SessionStatus.idle(),
  List<SesoriQuestionAsked> pendingQuestions = const [],
  List<SesoriPermissionAsked> pendingPermissions = const [],
}) => SessionDetailState.loaded(
  messages: messages,
  streamingText: const {},
  sessionStatus: status,
  pendingQuestions: pendingQuestions,
  pendingPermissions: pendingPermissions,
  sessionTitle: null,
  agent: null,
  assistantAgentModel: null,
  children: const [],
  childStatuses: const {},
  isRootSession: true,
  isArchived: false,
  queuedMessages: const [],
  availableAgents: const [],
  availableProviders: const [],
  availableCommands: const [],
  selectedAgent: "agent",
  selectedAgentModel: null,
  stagedCommand: null,
  isRefreshing: false,
  retryErrorMessage: null,
);

const _question = SesoriQuestionAsked(
  id: "question",
  sessionID: "session",
  displaySessionId: null,
  questions: [],
);

const _permission = SesoriPermissionAsked(
  requestID: "permission",
  sessionID: "session",
  displaySessionId: null,
  tool: "private-tool-name",
  description: "private description",
);

MessageWithParts _message() => const MessageWithParts(
  info: Message.assistant(
    id: "message",
    sessionID: "session",
    agent: null,
    modelID: null,
    providerID: null,
    time: null,
  ),
  parts: [],
);

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

const _inactiveAnalyticsState = ProductAnalyticsState(
  preference: ProductAnalyticsPreferenceUnknown(),
  synchronization: ProductAnalyticsNotSynchronized(),
  availability: ProductAnalyticsInactive(reason: ProductAnalyticsInactiveReason.preferenceUnknown),
);

const _activeAnalyticsState = ProductAnalyticsState(
  preference: ProductAnalyticsPreferenceKnown(preference: ProductAnalyticsPreference.enabled),
  synchronization: ProductAnalyticsSynchronized(),
  availability: ProductAnalyticsActive(),
);
