import "dart:async";
import "dart:collection";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/services/product_analytics_preference_service.dart";
import "package:test/test.dart";

const _userKeyA = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const _userKeyB = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
const _operationId = "123e4567-e89b-42d3-a456-426614174000";

const _userA = AuthUser(
  id: "user-a",
  provider: AuthProvider.github,
  providerUserId: "github-a",
  providerUsername: "alpha",
);
const _userB = AuthUser(
  id: "user-b",
  provider: AuthProvider.google,
  providerUserId: "google-b",
  providerUsername: "beta",
);

ProductAnalyticsPreferenceRecord _record({
  required String userId,
  required String userKey,
  required ProductAnalyticsPreference preference,
}) => ProductAnalyticsPreferenceRecord(
  userId: userId,
  preference: preference,
  revision: 1,
  userKey: userKey,
);

ProductAnalyticsPreferenceRecord _recordWithRevision({
  required String userId,
  required String userKey,
  required ProductAnalyticsPreference preference,
  required int revision,
}) => ProductAnalyticsPreferenceRecord(
  userId: userId,
  preference: preference,
  revision: revision,
  userKey: userKey,
);

class _FakeAuthSession extends Mock implements AuthSession {
  final BehaviorSubject<AuthState> states;

  _FakeAuthSession({required AuthState initialState}) : states = BehaviorSubject.seeded(initialState);

  @override
  ValueStream<AuthState> get authStateStream => states.stream;

  @override
  AuthState get currentState => states.value;

  void emit({required AuthState state}) => states.add(state);

  Future<void> dispose() => states.close();
}

class _FakePreferenceRepository extends Mock implements ProductAnalyticsPreferenceRepository {
  final localByUser = <String, LocalProductAnalyticsPreference?>{};
  final loadHandlers = <String, Future<LocalProductAnalyticsPreference?> Function()>{};
  final loadCalls = <String>[];
  bool throwOnLoad = false;
  final reconcileHandlers =
      Queue<
        Future<ProductAnalyticsPreferenceRepositoryResult> Function(
          String userId,
          LocalProductAnalyticsPreference? local,
        )
      >();
  final setHandlers =
      Queue<
        Future<ProductAnalyticsPreferenceRepositoryResult> Function(
          String userId,
          ProductAnalyticsPreferenceRecord current,
          ProductAnalyticsPreference preference,
        )
      >();
  final reconcileCalls = <({String userId, LocalProductAnalyticsPreference? local})>[];
  final setCalls =
      <({String userId, ProductAnalyticsPreferenceRecord current, ProductAnalyticsPreference preference})>[];

  @override
  Future<LocalProductAnalyticsPreference?> loadLocal({required String userId}) async {
    loadCalls.add(userId);
    if (throwOnLoad) throw StateError("storage unavailable");
    final handler = loadHandlers[userId];
    if (handler != null) return handler();
    return localByUser[userId];
  }

  @override
  Future<ProductAnalyticsPreferenceRepositoryResult> reconcile({
    required String userId,
    required LocalProductAnalyticsPreference? local,
  }) {
    reconcileCalls.add((userId: userId, local: local));
    return reconcileHandlers.removeFirst()(userId, local);
  }

  @override
  Future<ProductAnalyticsPreferenceRepositoryResult> setPreference({
    required String userId,
    required ProductAnalyticsPreferenceRecord current,
    required ProductAnalyticsPreference preference,
  }) {
    setCalls.add((userId: userId, current: current, preference: preference));
    return setHandlers.removeFirst()(userId, current, preference);
  }
}

class _RecordingAnalyticsRepository extends Mock implements AnalyticsRepository {
  final calls = <({ProductAnalyticsEnvelope envelope, String userKey})>[];
  AnalyticsDeliveryResult result = AnalyticsDeliveryResult.acceptedBySdk;
  Queue<AnalyticsDeliveryResult>? results;
  final deliveryFutures = Queue<Future<AnalyticsDeliveryResult>>();
  Completer<AnalyticsDeliveryResult>? deliveryCompleter;

  @override
  Future<AnalyticsDeliveryResult> logProductEvent({
    required ProductAnalyticsEnvelope envelope,
    required String userKey,
  }) async {
    calls.add((envelope: envelope, userKey: userKey));
    if (deliveryFutures.isNotEmpty) return deliveryFutures.removeFirst();
    final completer = deliveryCompleter;
    if (completer != null) return completer.future;
    final queuedResults = results;
    return queuedResults == null || queuedResults.isEmpty ? result : queuedResults.removeFirst();
  }
}

void main() {
  late _FakeAuthSession authSession;
  late _FakePreferenceRepository preferenceRepository;
  late _RecordingAnalyticsRepository analyticsRepository;
  late ProductAnalyticsPreferenceService preferenceService;
  late ProductAnalyticsService service;

  void createService() {
    authSession = _FakeAuthSession(initialState: const AuthState.authenticated(user: _userA));
    preferenceRepository = _FakePreferenceRepository();
    analyticsRepository = _RecordingAnalyticsRepository();
    preferenceService = ProductAnalyticsPreferenceService(
      capability: const AnalyticsRuntimeCapability.enabled(),
      authSession: authSession,
      preferenceRepository: preferenceRepository,
    );
    service = ProductAnalyticsService(
      analyticsRepository: analyticsRepository,
      preferenceService: preferenceService,
    );
  }

  void createServiceWithCapability({required AnalyticsRuntimeCapability capability}) {
    authSession = _FakeAuthSession(initialState: const AuthState.authenticated(user: _userA));
    preferenceRepository = _FakePreferenceRepository();
    analyticsRepository = _RecordingAnalyticsRepository();
    preferenceService = ProductAnalyticsPreferenceService(
      capability: capability,
      authSession: authSession,
      preferenceRepository: preferenceRepository,
    );
    service = ProductAnalyticsService(
      analyticsRepository: analyticsRepository,
      preferenceService: preferenceService,
    );
  }

  Future<void> waitForAnalyticsCalls({required int count}) async {
    for (var i = 0; i < 20 && analyticsRepository.calls.length < count; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(analyticsRepository.calls.length, greaterThanOrEqualTo(count));
  }

  tearDown(() async {
    await service.dispose();
    await authSession.dispose();
  });

  test("disposed preference lifecycle ignores later work", () async {
    createService();

    final firstDisposal = preferenceService.dispose();
    final secondDisposal = preferenceService.dispose();
    expect(secondDisposal, same(firstDisposal));
    await Future.wait([firstDisposal, secondDisposal]);
    await preferenceService.start().timeout(const Duration(milliseconds: 100));
    await preferenceService.markPostSplashReady();
    await preferenceService.refreshPreference();
    await preferenceService.setPreference(preference: ProductAnalyticsPreference.disabled);
    await preferenceService.prepareForLogout();
    await preferenceService.resumeAfterFailedLogout();

    expect(preferenceRepository.loadCalls, isEmpty);
    expect(preferenceRepository.reconcileCalls, isEmpty);
    expect(preferenceRepository.setCalls, isEmpty);
  });

  test("facade disposal callers share terminal cleanup", () async {
    createService();

    final firstDisposal = service.dispose();
    final secondDisposal = service.dispose();

    expect(secondDisposal, same(firstDisposal));
    await Future.wait([firstDisposal, secondDisposal]);
  });

  test("subscribes before an awaited startup load so an account switch cannot be lost", () async {
    createService();
    final loadA = Completer<LocalProductAnalyticsPreference?>();
    final loadB = Completer<LocalProductAnalyticsPreference?>();
    preferenceRepository.loadHandlers[_userA.id] = () => loadA.future;
    preferenceRepository.loadHandlers[_userB.id] = () => loadB.future;
    final serverB = _record(
      userId: _userB.id,
      userKey: _userKeyB,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: serverB),
    );

    final startFuture = service.start();
    var startCompleted = false;
    final startCompletion = startFuture.then<void>((_) => startCompleted = true);
    for (var i = 0; i < 5 && preferenceRepository.loadCalls.isEmpty; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(preferenceRepository.loadCalls, [_userA.id]);

    authSession.emit(state: const AuthState.authenticated(user: _userB));
    for (var i = 0; i < 5 && preferenceRepository.loadCalls.length < 2; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(preferenceRepository.loadCalls, [_userA.id, _userB.id]);

    loadA.complete(
      LocalProductAnalyticsSynced(
        record: _record(
          userId: _userA.id,
          userKey: _userKeyA,
          preference: ProductAnalyticsPreference.enabled,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(startCompleted, isFalse);

    final readinessFuture = service.markPostSplashReady();
    await Future<void>.delayed(Duration.zero);
    expect(preferenceRepository.reconcileCalls, isEmpty);

    loadB.complete(
      LocalProductAnalyticsSynced(
        record: _record(
          userId: _userB.id,
          userKey: _userKeyB,
          preference: ProductAnalyticsPreference.disabled,
        ),
      ),
    );
    await Future.wait([startCompletion, readinessFuture]);

    expect(preferenceRepository.reconcileCalls.single.userId, _userB.id);
    expect(service.state.displayedPreference, ProductAnalyticsPreference.enabled);
    expect(service.state.isActive, isTrue);
  });

  test("stays local-only and fail-closed until a non-splash readiness signal", () async {
    createService();
    final record = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.localByUser[_userA.id] = LocalProductAnalyticsSynced(record: record);
    final reconciliation = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.reconcileHandlers.add((_, _) => reconciliation.future);

    await service.start();

    expect(preferenceRepository.reconcileCalls, isEmpty);
    expect(service.state.isActive, isFalse);
    expect(
      await service.logEvent(
        event: const ProductAnalyticsEvent.needHelpMenuOpened(surface: OnboardingSurface.connectSetup),
        occurredAtUtc: DateTime.utc(2026, 7, 29),
      ),
      AnalyticsDeliveryResult.failed,
    );
    expect(analyticsRepository.calls, isEmpty);

    final readinessFuture = service.markPostSplashReady();
    while (preferenceRepository.reconcileCalls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(service.state.isActive, isFalse);
    expect(analyticsRepository.calls, isEmpty);

    reconciliation.complete(ProductAnalyticsPreferenceSynchronized(record: record));
    await readinessFuture;
    await waitForAnalyticsCalls(count: 2);

    expect(preferenceRepository.reconcileCalls, hasLength(1));
    expect(service.state.isActive, isTrue);
    expect(
      analyticsRepository.calls.map((call) => call.envelope.event),
      [
        const ProductAnalyticsEvent.analyticsSchemaReady(),
        const ProductAnalyticsEvent.analyticsActivationReady(),
      ],
    );
    expect(analyticsRepository.calls.map((call) => call.userKey), everyElement(_userKeyA));

    await service.markPostSplashReady();
    expect(preferenceRepository.reconcileCalls, hasLength(1));
  });

  test("schema readiness precedes a deferred first-message outcome and preserves occurrence time", () async {
    createService();
    final occurredAt = DateTime.utc(2026, 7, 30, 10, 15);
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    await service.start();

    expect(
      await service.logEvent(
        event: const ProductAnalyticsEvent.sessionMessageSent(
          submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
        ),
        occurredAtUtc: occurredAt,
      ),
      AnalyticsDeliveryResult.deferredUntilPreference,
    );
    expect(analyticsRepository.calls, isEmpty);

    await service.markPostSplashReady();
    await Future<void>.delayed(Duration.zero);

    expect(
      analyticsRepository.calls.map((call) => call.envelope.event),
      [
        const ProductAnalyticsEvent.analyticsSchemaReady(),
        const ProductAnalyticsEvent.analyticsActivationReady(),
        const ProductAnalyticsEvent.sessionMessageSent(
          submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
        ),
      ],
    );
    expect(analyticsRepository.calls.last.envelope.occurredAtUtc, occurredAt);
  });

  test("retains deferred outcomes until schema readiness is accepted", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers
      ..add((_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled))
      ..add((_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled));
    analyticsRepository.results = Queue.of([AnalyticsDeliveryResult.failed]);
    await service.start();
    expect(
      await service.logEvent(
        event: const ProductAnalyticsEvent.sessionMessageSent(
          submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
        ),
        occurredAtUtc: DateTime.utc(2026, 7, 30),
      ),
      AnalyticsDeliveryResult.deferredUntilPreference,
    );

    await service.markPostSplashReady();
    await waitForAnalyticsCalls(count: 1);
    expect(analyticsRepository.calls, hasLength(1));

    analyticsRepository.result = AnalyticsDeliveryResult.acceptedBySdk;
    await service.refreshPreference();
    await waitForAnalyticsCalls(count: 4);

    expect(
      analyticsRepository.calls.map((call) => call.envelope.event),
      [
        const ProductAnalyticsEvent.analyticsSchemaReady(),
        const ProductAnalyticsEvent.analyticsSchemaReady(),
        const ProductAnalyticsEvent.analyticsActivationReady(),
        const ProductAnalyticsEvent.sessionMessageSent(
          submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
        ),
      ],
    );
  });

  test("failed deferred outcome delivery remains operationally observable", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    analyticsRepository.results = Queue.of([
      AnalyticsDeliveryResult.acceptedBySdk,
      AnalyticsDeliveryResult.acceptedBySdk,
      AnalyticsDeliveryResult.failed,
    ]);
    final logLines = <String>[];

    await runZoned(
      () async {
        await service.start();
        await service.logEvent(
          event: const ProductAnalyticsEvent.sessionMessageSent(
            submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
          ),
          occurredAtUtc: DateTime.utc(2026, 7, 30),
        );
        await service.markPostSplashReady();
        await waitForAnalyticsCalls(count: 3);
      },
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logLines.add(line)),
    );

    expect(logLines, contains("Failed to deliver deferred product analytics event"));
  });

  test("retains unattempted fixed slots across a same-generation inactive refresh", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    final refreshResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.reconcileHandlers
      ..add((_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled))
      ..add((_, _) => refreshResult.future);
    final firstCandidateResult = Completer<AnalyticsDeliveryResult>();
    analyticsRepository.deliveryFutures
      ..add(Future.value(AnalyticsDeliveryResult.acceptedBySdk))
      ..add(Future.value(AnalyticsDeliveryResult.acceptedBySdk))
      ..add(firstCandidateResult.future);

    await service.start();
    expect(
      await service.logEvent(
        event: const ProductAnalyticsEvent.sessionMessageSent(
          submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
        ),
        occurredAtUtc: DateTime.utc(2026, 7, 30, 10),
      ),
      AnalyticsDeliveryResult.deferredUntilPreference,
    );
    expect(
      await service.logEvent(
        event: const ProductAnalyticsEvent.projectInventoryLoaded(
          inventoryState: AnalyticsInventoryState.nonEmpty,
        ),
        occurredAtUtc: DateTime.utc(2026, 7, 30, 11),
      ),
      AnalyticsDeliveryResult.deferredUntilPreference,
    );

    await service.markPostSplashReady();
    await waitForAnalyticsCalls(count: 3);
    final refreshFuture = service.refreshPreference();
    while (preferenceRepository.reconcileCalls.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(service.state.isActive, isFalse);

    firstCandidateResult.complete(AnalyticsDeliveryResult.acceptedBySdk);
    await Future<void>.delayed(Duration.zero);
    expect(analyticsRepository.calls, hasLength(3));

    refreshResult.complete(ProductAnalyticsPreferenceSynchronized(record: enabled));
    await refreshFuture;
    await waitForAnalyticsCalls(count: 4);

    expect(
      analyticsRepository.calls.map((call) => call.envelope.event),
      [
        const ProductAnalyticsEvent.analyticsSchemaReady(),
        const ProductAnalyticsEvent.analyticsActivationReady(),
        const ProductAnalyticsEvent.sessionMessageSent(
          submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
        ),
        const ProductAnalyticsEvent.projectInventoryLoaded(
          inventoryState: AnalyticsInventoryState.nonEmpty,
        ),
      ],
    );
  });

  test("disabled runtime retains preference truth but never emits custom events", () async {
    createServiceWithCapability(
      capability: const AnalyticsRuntimeCapability.disabled(
        reason: AnalyticsRuntimeDisabledReason.debugOrProfile,
      ),
    );
    final record = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: record),
    );

    await service.start();
    await service.markPostSplashReady();

    expect(service.state.displayedPreference, ProductAnalyticsPreference.enabled);
    expect(service.state.availability, isA<ProductAnalyticsInactive>());
    expect(analyticsRepository.calls, isEmpty);
  });

  test("readiness events retry after SDK rejection in the same auth generation", () async {
    createService();
    final record = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers
      ..add((_, _) async => ProductAnalyticsPreferenceSynchronized(record: record))
      ..add((_, _) async => ProductAnalyticsPreferenceSynchronized(record: record));
    analyticsRepository.result = AnalyticsDeliveryResult.failed;

    await service.start();
    await service.markPostSplashReady();
    await waitForAnalyticsCalls(count: 1);

    analyticsRepository.result = AnalyticsDeliveryResult.acceptedBySdk;
    await service.refreshPreference();
    await waitForAnalyticsCalls(count: 3);

    expect(
      analyticsRepository.calls.map((call) => call.envelope.event),
      [
        const ProductAnalyticsEvent.analyticsSchemaReady(),
        const ProductAnalyticsEvent.analyticsSchemaReady(),
        const ProductAnalyticsEvent.analyticsActivationReady(),
      ],
    );
  });

  test("activation readiness gates deferred candidates and retries without repeating schema readiness", () async {
    createService();
    final record = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers
      ..add((_, _) async => ProductAnalyticsPreferenceSynchronized(record: record))
      ..add((_, _) async => ProductAnalyticsPreferenceSynchronized(record: record));
    analyticsRepository.results = Queue.of([
      AnalyticsDeliveryResult.acceptedBySdk,
      AnalyticsDeliveryResult.failed,
    ]);

    await service.start();
    expect(
      await service.logEvent(
        event: const ProductAnalyticsEvent.sessionDiffViewed(
          changeState: AnalyticsChangeState.nonEmpty,
        ),
        occurredAtUtc: DateTime.utc(2026, 7, 30),
      ),
      AnalyticsDeliveryResult.deferredUntilPreference,
    );
    await service.markPostSplashReady();
    await waitForAnalyticsCalls(count: 2);
    expect(
      analyticsRepository.calls.map((call) => call.envelope.event),
      [
        const ProductAnalyticsEvent.analyticsSchemaReady(),
        const ProductAnalyticsEvent.analyticsActivationReady(),
      ],
    );

    analyticsRepository.result = AnalyticsDeliveryResult.acceptedBySdk;
    await service.refreshPreference();
    await waitForAnalyticsCalls(count: 4);

    expect(
      analyticsRepository.calls.map((call) => call.envelope.event),
      [
        const ProductAnalyticsEvent.analyticsSchemaReady(),
        const ProductAnalyticsEvent.analyticsActivationReady(),
        const ProductAnalyticsEvent.analyticsActivationReady(),
        const ProductAnalyticsEvent.sessionDiffViewed(
          changeState: AnalyticsChangeState.nonEmpty,
        ),
      ],
    );
  });

  test("local read failure blocks automatic activation until an explicit successful retry", () async {
    createService();
    preferenceRepository.throwOnLoad = true;
    final record = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: record),
    );

    await service.start();
    await service.markPostSplashReady();

    expect(preferenceRepository.reconcileCalls, isEmpty);
    expect(service.state.availability, isA<ProductAnalyticsInactive>());
    expect(analyticsRepository.calls, isEmpty);
    expect(
      await service.logEvent(
        event: const ProductAnalyticsEvent.sessionMessageSent(
          submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
        ),
        occurredAtUtc: DateTime.utc(2026, 7, 30),
      ),
      AnalyticsDeliveryResult.failed,
    );

    preferenceRepository.throwOnLoad = false;
    await service.refreshPreference();
    await waitForAnalyticsCalls(count: 2);

    expect(preferenceRepository.reconcileCalls, hasLength(1));
    expect(service.state.isActive, isTrue);
    expect(
      analyticsRepository.calls.map((call) => call.envelope.event),
      [
        const ProductAnalyticsEvent.analyticsSchemaReady(),
        const ProductAnalyticsEvent.analyticsActivationReady(),
      ],
    );
  });

  test("a retried local read cannot overwrite a newer preference request", () async {
    createService();
    preferenceRepository.throwOnLoad = true;
    await service.start();
    await service.markPostSplashReady();

    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    final disabled = _recordWithRevision(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.disabled,
      revision: 2,
    );
    final staleLocal = LocalProductAnalyticsPendingEnable(
      userId: enabled.userId,
      revision: enabled.revision,
      userKey: enabled.userKey,
      operationId: _operationId,
    );
    final retryLoad = Completer<LocalProductAnalyticsPreference?>();
    preferenceRepository.throwOnLoad = false;
    preferenceRepository.loadHandlers[_userA.id] = () => retryLoad.future;
    preferenceRepository.reconcileHandlers
      ..add((_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled))
      ..add((_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled));
    preferenceRepository.setHandlers.add(
      (_, _, _) async => ProductAnalyticsPreferenceSynchronized(record: disabled),
    );

    final refreshFuture = service.refreshPreference();
    while (preferenceRepository.loadCalls.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    await service.setPreference(preference: ProductAnalyticsPreference.disabled);
    retryLoad.complete(staleLocal);
    await refreshFuture;

    expect(service.state.displayedPreference, ProductAnalyticsPreference.disabled);
    expect(service.state.isActive, isFalse);
    expect(preferenceRepository.reconcileCalls, hasLength(1));
  });

  test("disable suppresses synchronously and remains pending after server failure", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    await service.start();
    await service.markPostSplashReady();
    await waitForAnalyticsCalls(count: 1);
    analyticsRepository.calls.clear();

    final pendingCompleter = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.setHandlers.add((_, _, _) => pendingCompleter.future);
    final disableFuture = service.setPreference(preference: ProductAnalyticsPreference.disabled);

    expect(service.state.isActive, isFalse);
    expect(service.state.synchronization, isA<ProductAnalyticsDisableRequestInProgress>());
    expect(
      await service.logEvent(
        event: const ProductAnalyticsEvent.whyBridgeOpened(surface: OnboardingSurface.connectSetup),
        occurredAtUtc: DateTime.utc(2026, 7, 29),
      ),
      AnalyticsDeliveryResult.failed,
    );
    expect(analyticsRepository.calls, isEmpty);

    final pending = LocalProductAnalyticsPendingDisable(
      userId: enabled.userId,
      revision: enabled.revision,
      userKey: enabled.userKey,
      operationId: _operationId,
    );
    pendingCompleter.complete(ProductAnalyticsPreferencePendingSync(pending: pending));
    await disableFuture;

    expect(service.state.displayedPreference, ProductAnalyticsPreference.disabled);
    expect(service.state.synchronization, isA<ProductAnalyticsDisablePending>());
    expect(service.state.isActive, isFalse);
  });

  test("refresh waits for an in-flight disable before reconciling", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    final disabled = _recordWithRevision(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.disabled,
      revision: 2,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    await service.start();
    await service.markPostSplashReady();

    var disableCompleted = false;
    final disableResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.setHandlers.add((_, _, _) => disableResult.future);
    preferenceRepository.reconcileHandlers.add((_, _) async {
      expect(disableCompleted, isTrue);
      return ProductAnalyticsPreferenceSynchronized(record: disabled);
    });

    final disableFuture = service.setPreference(preference: ProductAnalyticsPreference.disabled);
    final refreshFuture = service.refreshPreference();
    await Future<void>.delayed(Duration.zero);

    expect(preferenceRepository.reconcileCalls, hasLength(1));
    disableCompleted = true;
    disableResult.complete(ProductAnalyticsPreferenceSynchronized(record: disabled));
    await Future.wait([disableFuture, refreshFuture]);

    expect(preferenceRepository.reconcileCalls, hasLength(2));
    expect(service.state.displayedPreference, ProductAnalyticsPreference.disabled);
    expect(service.state.isActive, isFalse);
  });

  test("rapid preference changes are applied in invocation order", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    final disabled = _recordWithRevision(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.disabled,
      revision: 2,
    );
    final reEnabled = _recordWithRevision(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
      revision: 3,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    await service.start();
    await service.markPostSplashReady();

    final disableResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.setHandlers
      ..add((_, _, _) => disableResult.future)
      ..add((_, current, preference) async {
        expect(current, same(disabled));
        expect(preference, ProductAnalyticsPreference.enabled);
        return ProductAnalyticsPreferenceSynchronized(record: reEnabled);
      });

    final disableFuture = service.setPreference(preference: ProductAnalyticsPreference.disabled);
    final enableFuture = service.setPreference(preference: ProductAnalyticsPreference.enabled);
    await Future<void>.delayed(Duration.zero);
    expect(preferenceRepository.setCalls, hasLength(1));

    disableResult.complete(ProductAnalyticsPreferenceSynchronized(record: disabled));
    await Future.wait([disableFuture, enableFuture]);

    expect(preferenceRepository.setCalls, hasLength(2));
    expect(service.state.displayedPreference, ProductAnalyticsPreference.enabled);
    expect(service.state.isActive, isTrue);
  });

  test("an older middle toggle keeps the newest queued preference visible", () async {
    createService();
    final disabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.disabled,
    );
    final enabled = _recordWithRevision(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
      revision: 2,
    );
    final reDisabled = _recordWithRevision(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.disabled,
      revision: 3,
    );
    final reEnabled = _recordWithRevision(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
      revision: 4,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: disabled),
    );
    await service.start();
    await service.markPostSplashReady();

    final firstResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    final secondResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.setHandlers
      ..add((_, _, _) => firstResult.future)
      ..add((_, _, _) => secondResult.future)
      ..add((_, _, _) async => ProductAnalyticsPreferenceSynchronized(record: reEnabled));

    final firstFuture = service.setPreference(preference: ProductAnalyticsPreference.enabled);
    final secondFuture = service.setPreference(preference: ProductAnalyticsPreference.disabled);
    final thirdFuture = service.setPreference(preference: ProductAnalyticsPreference.enabled);
    firstResult.complete(ProductAnalyticsPreferenceSynchronized(record: enabled));
    while (preferenceRepository.setCalls.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(service.state.displayedPreference, ProductAnalyticsPreference.enabled);
    expect(service.state.synchronization, isA<ProductAnalyticsEnableRequestInProgress>());

    secondResult.complete(ProductAnalyticsPreferenceSynchronized(record: reDisabled));
    await Future.wait([firstFuture, secondFuture, thirdFuture]);

    expect(
      preferenceRepository.setCalls.map((call) => call.preference),
      [
        ProductAnalyticsPreference.enabled,
        ProductAnalyticsPreference.disabled,
        ProductAnalyticsPreference.enabled,
      ],
    );
    expect(service.state.isActive, isTrue);
  });

  test("an obsolete volatile disable cannot override a queued enable during refresh", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    await service.start();
    await service.markPostSplashReady();

    final disableResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    final enableResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    final volatileDisable = LocalProductAnalyticsPendingDisable(
      userId: enabled.userId,
      revision: enabled.revision,
      userKey: enabled.userKey,
      operationId: _operationId,
    );
    preferenceRepository.setHandlers
      ..add((_, _, _) => disableResult.future)
      ..add((_, _, _) => enableResult.future)
      ..add((_, _, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled));
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );

    final disableFuture = service.setPreference(preference: ProductAnalyticsPreference.disabled);
    final enableFuture = service.setPreference(preference: ProductAnalyticsPreference.enabled);
    disableResult.complete(ProductAnalyticsPreferenceVolatileDisablePending(pending: volatileDisable));
    while (preferenceRepository.setCalls.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    final refreshFuture = service.refreshPreference();
    enableResult.complete(ProductAnalyticsPreferenceSynchronized(record: enabled));
    await Future.wait([disableFuture, enableFuture, refreshFuture]);

    expect(preferenceRepository.setCalls, hasLength(2));
    expect(service.state.displayedPreference, ProductAnalyticsPreference.enabled);
    expect(service.state.isActive, isTrue);
  });

  test("a failed enable does not restore an obsolete volatile disable retry", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    final volatileDisable = LocalProductAnalyticsPendingDisable(
      userId: enabled.userId,
      revision: enabled.revision,
      userKey: enabled.userKey,
      operationId: _operationId,
    );
    preferenceRepository.reconcileHandlers
      ..add((_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled))
      ..add((_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled));
    preferenceRepository.setHandlers
      ..add((_, _, _) async => ProductAnalyticsPreferenceVolatileDisablePending(pending: volatileDisable))
      ..add((_, _, _) async => const ProductAnalyticsPreferenceTimedOut())
      ..add((_, _, _) async => ProductAnalyticsPreferenceSynchronized(record: volatileDisable.record));
    await service.start();
    await service.markPostSplashReady();
    await service.setPreference(preference: ProductAnalyticsPreference.disabled);

    await service.setPreference(preference: ProductAnalyticsPreference.enabled);
    await service.refreshPreference();

    expect(
      preferenceRepository.setCalls.map((call) => call.preference),
      [ProductAnalyticsPreference.disabled, ProductAnalyticsPreference.enabled],
    );
    expect(preferenceRepository.reconcileCalls, hasLength(2));
    expect(service.state.isActive, isTrue);
  });

  test("a queued refresh cannot reactivate after a repeated volatile disable failure", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    final volatileDisable = LocalProductAnalyticsPendingDisable(
      userId: enabled.userId,
      revision: enabled.revision,
      userKey: enabled.userKey,
      operationId: _operationId,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    preferenceRepository.setHandlers.add(
      (_, _, _) async => ProductAnalyticsPreferenceVolatileDisablePending(pending: volatileDisable),
    );
    await service.start();
    await service.markPostSplashReady();
    await service.setPreference(preference: ProductAnalyticsPreference.disabled);

    final retryResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.setHandlers.add((_, _, _) => retryResult.future);
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );

    final retryFuture = service.refreshPreference();
    while (preferenceRepository.setCalls.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    final queuedRefreshFuture = service.refreshPreference();
    retryResult.complete(ProductAnalyticsPreferenceVolatileDisablePending(pending: volatileDisable));
    await Future.wait([retryFuture, queuedRefreshFuture]);

    expect(preferenceRepository.reconcileCalls, hasLength(1));
    expect(service.state.synchronization, isA<ProductAnalyticsDisableRetryRequired>());
    expect(service.state.isActive, isFalse);
  });

  test("a queued disable reasserts suppression after an earlier refresh completes", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    final disabled = _recordWithRevision(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.disabled,
      revision: 2,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    await service.start();
    await service.markPostSplashReady();

    final refreshResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    final disableResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.reconcileHandlers.add((_, _) => refreshResult.future);
    preferenceRepository.setHandlers.add((_, _, _) => disableResult.future);

    final refreshFuture = service.refreshPreference();
    while (preferenceRepository.reconcileCalls.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    final disableFuture = service.setPreference(preference: ProductAnalyticsPreference.disabled);
    refreshResult.complete(ProductAnalyticsPreferenceSynchronized(record: enabled));
    while (preferenceRepository.setCalls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(service.state.isActive, isFalse);
    expect(service.state.displayedPreference, ProductAnalyticsPreference.disabled);

    disableResult.complete(ProductAnalyticsPreferenceSynchronized(record: disabled));
    await Future.wait([refreshFuture, disableFuture]);
  });

  test("a hanging schema report does not hold the preference operation queue", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    final disabled = _recordWithRevision(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.disabled,
      revision: 2,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    preferenceRepository.setHandlers.add(
      (_, _, _) async => ProductAnalyticsPreferenceSynchronized(record: disabled),
    );
    final schemaDelivery = Completer<AnalyticsDeliveryResult>();
    analyticsRepository.deliveryCompleter = schemaDelivery;
    await service.start();

    final readyFuture = service.markPostSplashReady();
    while (analyticsRepository.calls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    final disableFuture = service.setPreference(preference: ProductAnalyticsPreference.disabled);
    await Future<void>.delayed(Duration.zero);

    try {
      expect(preferenceRepository.setCalls, hasLength(1));
    } finally {
      schemaDelivery.complete(AnalyticsDeliveryResult.acceptedBySdk);
      await Future.wait([readyFuture, disableFuture]);
    }
  });

  test("a preference request made during hydration is applied after reconciliation", () async {
    createService();
    final localLoad = Completer<LocalProductAnalyticsPreference?>();
    preferenceRepository.loadHandlers[_userA.id] = () => localLoad.future;
    final disabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.disabled,
    );
    final enabled = _recordWithRevision(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
      revision: 2,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: disabled),
    );
    preferenceRepository.setHandlers.add(
      (_, current, preference) async {
        expect(current, same(disabled));
        expect(preference, ProductAnalyticsPreference.enabled);
        return ProductAnalyticsPreferenceSynchronized(record: enabled);
      },
    );

    final startFuture = service.start();
    while (preferenceRepository.loadCalls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    final readyFuture = service.markPostSplashReady();
    final preferenceFuture = service.setPreference(preference: ProductAnalyticsPreference.enabled);
    localLoad.complete(null);
    await Future.wait([startFuture, readyFuture, preferenceFuture]);

    expect(preferenceRepository.setCalls, hasLength(1));
    expect(service.state.displayedPreference, ProductAnalyticsPreference.enabled);
    expect(service.state.isActive, isTrue);
  });

  test("a repeated authenticated emission preserves a queued disable for the same account", () async {
    createService();
    final localLoad = Completer<LocalProductAnalyticsPreference?>();
    preferenceRepository.loadHandlers[_userA.id] = () => localLoad.future;
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    final disabled = _recordWithRevision(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.disabled,
      revision: 2,
    );
    preferenceRepository.setHandlers.add(
      (_, _, _) async => ProductAnalyticsPreferenceSynchronized(record: disabled),
    );

    final startFuture = service.start();
    while (preferenceRepository.loadCalls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    final disableFuture = service.setPreference(preference: ProductAnalyticsPreference.disabled);
    authSession.emit(state: const AuthState.authenticated(user: _userA));
    localLoad.complete(LocalProductAnalyticsSynced(record: enabled));
    await Future.wait([startFuture, disableFuture]);

    expect(preferenceRepository.loadCalls, [_userA.id]);
    expect(preferenceRepository.setCalls, hasLength(1));
    expect(service.state.displayedPreference, ProductAnalyticsPreference.disabled);
  });

  test("disable stays suppressed while obtaining a missing current record", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    final disabled = _recordWithRevision(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.disabled,
      revision: 2,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    final disableResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.setHandlers.add((_, _, _) => disableResult.future);
    await service.start();

    final disableFuture = service.setPreference(preference: ProductAnalyticsPreference.disabled);
    while (preferenceRepository.setCalls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(service.state.isActive, isFalse);
    expect(service.state.displayedPreference, ProductAnalyticsPreference.disabled);
    expect(analyticsRepository.calls, isEmpty);

    disableResult.complete(ProductAnalyticsPreferenceSynchronized(record: disabled));
    await disableFuture;
  });

  test("failed enable finalization remains pending and inactive", () async {
    createService();
    final disabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.disabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: disabled),
    );
    await service.start();
    await service.markPostSplashReady();

    final pending = LocalProductAnalyticsPendingEnable(
      userId: disabled.userId,
      revision: disabled.revision,
      userKey: disabled.userKey,
      operationId: _operationId,
    );
    preferenceRepository.setHandlers.add(
      (_, _, _) async => ProductAnalyticsPreferencePendingSync(pending: pending),
    );

    await service.setPreference(preference: ProductAnalyticsPreference.enabled);

    expect(service.state.displayedPreference, ProductAnalyticsPreference.enabled);
    expect(service.state.synchronization, isA<ProductAnalyticsEnablePending>());
    expect(service.state.isActive, isFalse);
    expect(analyticsRepository.calls, isEmpty);
  });

  test("volatile disable is not mistaken for durable success and refresh retries it", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    await service.start();
    await service.markPostSplashReady();

    final volatile = LocalProductAnalyticsPendingDisable(
      userId: enabled.userId,
      revision: enabled.revision,
      userKey: enabled.userKey,
      operationId: _operationId,
    );
    preferenceRepository.setHandlers
      ..add((_, _, _) async => ProductAnalyticsPreferenceVolatileDisablePending(pending: volatile))
      ..add(
        (_, _, _) async => ProductAnalyticsPreferenceSynchronized(
          record: _recordWithRevision(
            userId: _userA.id,
            userKey: _userKeyA,
            preference: ProductAnalyticsPreference.disabled,
            revision: 2,
          ),
        ),
      );

    await service.setPreference(preference: ProductAnalyticsPreference.disabled);
    expect(service.state.synchronization, isA<ProductAnalyticsDisableRetryRequired>());
    expect(service.state.isActive, isFalse);

    await service.refreshPreference();
    expect(preferenceRepository.setCalls, hasLength(2));
    expect(service.state.synchronization, isA<ProductAnalyticsSynchronized>());
    expect(service.state.displayedPreference, ProductAnalyticsPreference.disabled);
  });

  test("overlapping prepareForLogout calls share one pending-disable retry", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    await service.start();
    await service.markPostSplashReady();

    final pending = LocalProductAnalyticsPendingDisable(
      userId: enabled.userId,
      revision: enabled.revision,
      userKey: enabled.userKey,
      operationId: _operationId,
    );
    preferenceRepository.setHandlers.add(
      (_, _, _) async => ProductAnalyticsPreferencePendingSync(pending: pending),
    );
    await service.setPreference(preference: ProductAnalyticsPreference.disabled);
    final logoutReconciliation = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.reconcileHandlers
      ..add((_, local) {
        expect(service.state.isActive, isFalse);
        expect(local, same(pending));
        return logoutReconciliation.future;
      })
      ..add(
        (_, _) async => ProductAnalyticsPreferenceSynchronized(
          record: _recordWithRevision(
            userId: _userA.id,
            userKey: _userKeyA,
            preference: ProductAnalyticsPreference.disabled,
            revision: 2,
          ),
        ),
      );

    final firstPreparation = service.prepareForLogout();
    final secondPreparation = service.prepareForLogout();
    while (preferenceRepository.reconcileCalls.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    logoutReconciliation.complete(
      ProductAnalyticsPreferenceSynchronized(
        record: _recordWithRevision(
          userId: _userA.id,
          userKey: _userKeyA,
          preference: ProductAnalyticsPreference.disabled,
          revision: 2,
        ),
      ),
    );
    await Future.wait([firstPreparation, secondPreparation]);

    expect(preferenceRepository.reconcileCalls, hasLength(2));
    expect(service.state.isActive, isFalse);
    expect(service.state.displayedPreference, ProductAnalyticsPreference.disabled);
  });

  test("prepareForLogout awaits an active disable before releasing logout", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    await service.start();
    await service.markPostSplashReady();

    final disableResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.setHandlers.add((_, _, _) => disableResult.future);
    final disableFuture = service.setPreference(preference: ProductAnalyticsPreference.disabled);
    await Future<void>.delayed(Duration.zero);

    var preparationCompleted = false;
    final preparationFuture = service.prepareForLogout().then((_) => preparationCompleted = true);
    await Future<void>.delayed(Duration.zero);

    expect(preparationCompleted, isFalse);

    disableResult.complete(
      ProductAnalyticsPreferenceSynchronized(
        record: _recordWithRevision(
          userId: _userA.id,
          userKey: _userKeyA,
          preference: ProductAnalyticsPreference.disabled,
          revision: 2,
        ),
      ),
    );
    await Future.wait([disableFuture, preparationFuture]);

    expect(preparationCompleted, isTrue);
    expect(service.state.displayedPreference, ProductAnalyticsPreference.disabled);
  });

  test("prepareForLogout awaits local hydration before retrying a pending disable", () async {
    createService();
    final localLoad = Completer<LocalProductAnalyticsPreference?>();
    preferenceRepository.loadHandlers[_userA.id] = () => localLoad.future;
    final pending = LocalProductAnalyticsPendingDisable(
      userId: _userA.id,
      revision: 1,
      userKey: _userKeyA,
      operationId: _operationId,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, local) async {
        expect(local, same(pending));
        return ProductAnalyticsPreferenceSynchronized(
          record: _recordWithRevision(
            userId: _userA.id,
            userKey: _userKeyA,
            preference: ProductAnalyticsPreference.disabled,
            revision: 2,
          ),
        );
      },
    );

    final startFuture = service.start();
    while (preferenceRepository.loadCalls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    final readyFuture = service.markPostSplashReady();
    var preparationCompleted = false;
    final preparationFuture = service.prepareForLogout().then((_) => preparationCompleted = true);
    await Future<void>.delayed(Duration.zero);

    expect(preparationCompleted, isFalse);

    localLoad.complete(pending);
    await Future.wait([startFuture, readyFuture, preparationFuture]);

    expect(preferenceRepository.reconcileCalls, hasLength(1));
    expect(service.state.displayedPreference, ProductAnalyticsPreference.disabled);
  });

  test("prepareForLogout retries a failed local read before pending-disable reconciliation", () async {
    createService();
    preferenceRepository.throwOnLoad = true;
    await service.start();
    await service.markPostSplashReady();
    final pending = LocalProductAnalyticsPendingDisable(
      userId: _userA.id,
      revision: 1,
      userKey: _userKeyA,
      operationId: _operationId,
    );
    preferenceRepository
      ..throwOnLoad = false
      ..localByUser[_userA.id] = pending
      ..reconcileHandlers.add(
        (_, local) async {
          expect(local, same(pending));
          return ProductAnalyticsPreferenceSynchronized(
            record: _recordWithRevision(
              userId: _userA.id,
              userKey: _userKeyA,
              preference: ProductAnalyticsPreference.disabled,
              revision: 2,
            ),
          );
        },
      );

    await service.prepareForLogout();

    expect(preferenceRepository.loadCalls, [_userA.id, _userA.id]);
    expect(preferenceRepository.reconcileCalls, hasLength(1));
    expect(service.state.displayedPreference, ProductAnalyticsPreference.disabled);
  });

  test("prepareForLogout awaits a disable queued while its local-read retry fails", () async {
    createService();
    preferenceRepository.throwOnLoad = true;
    await service.start();
    await service.markPostSplashReady();
    final retryLoad = Completer<LocalProductAnalyticsPreference?>();
    preferenceRepository
      ..throwOnLoad = false
      ..loadHandlers[_userA.id] = () => retryLoad.future;
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    final disableResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.setHandlers.add((_, _, _) => disableResult.future);

    var preparationCompleted = false;
    final preparationFuture = service.prepareForLogout().then((_) => preparationCompleted = true);
    while (preferenceRepository.loadCalls.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    final disableFuture = service.setPreference(preference: ProductAnalyticsPreference.disabled);
    while (preferenceRepository.setCalls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    retryLoad.completeError(StateError("storage unavailable"), StackTrace.empty);
    await Future<void>.delayed(Duration.zero);

    expect(preparationCompleted, isFalse);

    disableResult.complete(
      ProductAnalyticsPreferenceSynchronized(
        record: _recordWithRevision(
          userId: _userA.id,
          userKey: _userKeyA,
          preference: ProductAnalyticsPreference.disabled,
          revision: 2,
        ),
      ),
    );
    await Future.wait([preparationFuture, disableFuture]);

    expect(preparationCompleted, isTrue);
    expect(service.state.displayedPreference, ProductAnalyticsPreference.disabled);
  });

  test("logout retains an in-flight enable instead of retrying a stale pending disable", () async {
    createService();
    final pendingDisable = LocalProductAnalyticsPendingDisable(
      userId: _userA.id,
      revision: 1,
      userKey: _userKeyA,
      operationId: _operationId,
    );
    final enabled = _recordWithRevision(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
      revision: 2,
    );
    preferenceRepository.localByUser[_userA.id] = pendingDisable;
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferencePendingSync(pending: pendingDisable),
    );
    await service.start();
    await service.markPostSplashReady();

    final enableResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.setHandlers.add((_, _, _) => enableResult.future);
    final enableFuture = service.setPreference(preference: ProductAnalyticsPreference.enabled);
    while (preferenceRepository.setCalls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    final preparationFuture = service.prepareForLogout();
    preferenceRepository.reconcileHandlers.add(
      (_, local) async {
        expect(local, isA<LocalProductAnalyticsSynced>());
        expect(local?.record.preference, ProductAnalyticsPreference.enabled);
        return ProductAnalyticsPreferenceSynchronized(record: enabled);
      },
    );
    enableResult.complete(ProductAnalyticsPreferenceSynchronized(record: enabled));
    await Future.wait([enableFuture, preparationFuture]);

    expect(preferenceRepository.reconcileCalls, hasLength(1));
    expect(service.state.isActive, isFalse);

    await service.resumeAfterFailedLogout();

    expect(preferenceRepository.reconcileCalls, hasLength(2));
    expect(service.state.isActive, isTrue);
  });

  test("prepareForLogout awaits a disable queued behind the captured operation", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    await service.start();
    await service.markPostSplashReady();

    final refreshResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.reconcileHandlers.add((_, _) => refreshResult.future);
    final refreshFuture = service.refreshPreference();
    await Future<void>.delayed(Duration.zero);

    var preparationCompleted = false;
    final preparationFuture = service.prepareForLogout().then((_) => preparationCompleted = true);
    await Future<void>.delayed(Duration.zero);

    final disableResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.setHandlers.add((_, _, _) => disableResult.future);
    final disableFuture = service.setPreference(preference: ProductAnalyticsPreference.disabled);

    refreshResult.complete(ProductAnalyticsPreferenceSynchronized(record: enabled));
    await refreshFuture;
    while (preferenceRepository.setCalls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(preparationCompleted, isFalse);

    disableResult.complete(
      ProductAnalyticsPreferenceSynchronized(
        record: _recordWithRevision(
          userId: _userA.id,
          userKey: _userKeyA,
          preference: ProductAnalyticsPreference.disabled,
          revision: 2,
        ),
      ),
    );
    await Future.wait([disableFuture, preparationFuture]);

    expect(preparationCompleted, isTrue);
    expect(service.state.displayedPreference, ProductAnalyticsPreference.disabled);
  });

  test("failed logout recovery restores an active synchronized account", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    await service.start();
    await service.markPostSplashReady();

    await service.prepareForLogout();
    expect(service.state.isActive, isFalse);

    await service.resumeAfterFailedLogout();

    expect(service.state.isActive, isTrue);
    expect(service.state.availability, isA<ProductAnalyticsActive>());
  });

  test("failed logout retries a volatile disable instead of restoring active analytics", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    final volatileDisable = LocalProductAnalyticsPendingDisable(
      userId: enabled.userId,
      revision: enabled.revision,
      userKey: enabled.userKey,
      operationId: _operationId,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    for (var i = 0; i < 3; i++) {
      preferenceRepository.setHandlers.add(
        (_, _, _) async => ProductAnalyticsPreferenceVolatileDisablePending(pending: volatileDisable),
      );
    }
    await service.start();
    await service.markPostSplashReady();
    await service.setPreference(preference: ProductAnalyticsPreference.disabled);

    await service.prepareForLogout();
    expect(preferenceRepository.setCalls, hasLength(2));

    await service.resumeAfterFailedLogout();

    expect(preferenceRepository.setCalls, hasLength(3));
    expect(service.state.synchronization, isA<ProductAnalyticsDisableRetryRequired>());
    expect(service.state.isActive, isFalse);
  });

  test("failed logout stays inactive while required reconciliation is in flight", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    final disabled = _recordWithRevision(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.disabled,
      revision: 2,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    await service.start();
    await service.markPostSplashReady();
    await waitForAnalyticsCalls(count: 1);
    analyticsRepository.calls.clear();

    final refreshResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.reconcileHandlers.add((_, _) => refreshResult.future);
    final refreshFuture = service.refreshPreference();
    while (preferenceRepository.reconcileCalls.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    final preparationFuture = service.prepareForLogout();
    final disableResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.setHandlers.add((_, _, _) => disableResult.future);
    final disableFuture = service.setPreference(preference: ProductAnalyticsPreference.disabled);
    refreshResult.complete(ProductAnalyticsPreferenceSynchronized(record: enabled));
    await refreshFuture;
    while (preferenceRepository.setCalls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    disableResult.complete(ProductAnalyticsPreferenceSynchronized(record: disabled));
    await Future.wait([disableFuture, preparationFuture]);

    final recoveryResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.reconcileHandlers.add((_, _) => recoveryResult.future);
    final recoveryFuture = service.resumeAfterFailedLogout();

    expect(service.state.isActive, isFalse);
    expect(
      (service.state.availability as ProductAnalyticsInactive).reason,
      ProductAnalyticsInactiveReason.unauthenticated,
    );
    expect(
      await service.logEvent(
        event: const ProductAnalyticsEvent.whyBridgeOpened(surface: OnboardingSurface.connectSetup),
        occurredAtUtc: DateTime.utc(2026, 7, 30),
      ),
      AnalyticsDeliveryResult.failed,
    );
    expect(analyticsRepository.calls, isEmpty);

    while (preferenceRepository.reconcileCalls.length < 3) {
      await Future<void>.delayed(Duration.zero);
    }
    recoveryResult.complete(ProductAnalyticsPreferenceSynchronized(record: disabled));
    await recoveryFuture;

    expect(service.state.displayedPreference, ProductAnalyticsPreference.disabled);
    expect(service.state.isActive, isFalse);
  });

  test("failed logout recovery restores an unknown preference with no local record", () async {
    createService();
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => const ProductAnalyticsPreferenceFailed(),
    );
    await service.start();
    await service.markPostSplashReady();
    final stateBeforeLogout = service.state;
    expect(stateBeforeLogout.availability, isA<ProductAnalyticsInactive>());
    expect(
      (stateBeforeLogout.availability as ProductAnalyticsInactive).reason,
      ProductAnalyticsInactiveReason.requestFailure,
    );

    await service.prepareForLogout();
    expect(
      (service.state.availability as ProductAnalyticsInactive).reason,
      ProductAnalyticsInactiveReason.unauthenticated,
    );

    await service.resumeAfterFailedLogout();

    expect(service.state, same(stateBeforeLogout));
  });

  test("failed logout reconciles local hydration that completed while suppressed", () async {
    createService();
    final localLoad = Completer<LocalProductAnalyticsPreference?>();
    preferenceRepository.loadHandlers[_userA.id] = () => localLoad.future;
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, local) async {
        expect(local, isA<LocalProductAnalyticsSynced>());
        return ProductAnalyticsPreferenceSynchronized(record: enabled);
      },
    );

    final startFuture = service.start();
    while (preferenceRepository.loadCalls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    final readyFuture = service.markPostSplashReady();
    final preparationFuture = service.prepareForLogout();
    await Future<void>.delayed(Duration.zero);
    localLoad.complete(LocalProductAnalyticsSynced(record: enabled));
    await Future.wait([startFuture, readyFuture, preparationFuture]);

    expect(service.state.isActive, isFalse);
    expect(
      (service.state.availability as ProductAnalyticsInactive).reason,
      ProductAnalyticsInactiveReason.unauthenticated,
    );

    await service.resumeAfterFailedLogout();

    expect(service.state.isActive, isTrue);
    expect(preferenceRepository.reconcileCalls, hasLength(1));
  });

  test("logout suppression survives an in-flight refresh and reconciles after recovery", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    await service.start();
    await service.markPostSplashReady();

    final refreshResult = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.reconcileHandlers
      ..add((_, _) => refreshResult.future)
      ..add((_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled));
    final refreshFuture = service.refreshPreference();
    await Future<void>.delayed(Duration.zero);
    final preparationFuture = service.prepareForLogout();
    expect(service.state.isActive, isFalse);

    refreshResult.complete(ProductAnalyticsPreferenceSynchronized(record: enabled));
    await Future.wait([refreshFuture, preparationFuture]);
    expect(service.state.isActive, isFalse);

    await service.resumeAfterFailedLogout();
    expect(service.state.isActive, isTrue);
    expect(preferenceRepository.reconcileCalls, hasLength(3));
  });

  test("prepareForLogout releases after ten seconds when a pending retry hangs", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    await service.start();
    await service.markPostSplashReady();

    final pending = LocalProductAnalyticsPendingDisable(
      userId: enabled.userId,
      revision: enabled.revision,
      userKey: enabled.userKey,
      operationId: _operationId,
    );
    preferenceRepository.setHandlers.add(
      (_, _, _) async => ProductAnalyticsPreferencePendingSync(pending: pending),
    );
    await service.setPreference(preference: ProductAnalyticsPreference.disabled);

    final hangingRetry = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.reconcileHandlers.add((_, _) => hangingRetry.future);
    fakeAsync((async) {
      var completed = false;
      service.prepareForLogout().then((_) => completed = true);
      async.flushMicrotasks();

      expect(
        (service.state.availability as ProductAnalyticsInactive).reason,
        ProductAnalyticsInactiveReason.unauthenticated,
      );

      async.elapse(const Duration(seconds: 10));
      async.flushMicrotasks();

      expect(completed, isTrue);
      expect(service.state.isActive, isFalse);
      expect(
        (service.state.availability as ProductAnalyticsInactive).reason,
        ProductAnalyticsInactiveReason.unauthenticated,
      );

      var resumed = false;
      service.resumeAfterFailedLogout().then((_) => resumed = true);
      async.flushMicrotasks();
      expect(resumed, isTrue);
      expect(service.state.synchronization, isA<ProductAnalyticsDisablePending>());
    });

    hangingRetry.complete(ProductAnalyticsPreferencePendingSync(pending: pending));
    await Future<void>.delayed(Duration.zero);
  });

  test("stale account reconciliation cannot activate a later account generation", () async {
    createService();
    final reconcileA = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    final reconcileB = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.reconcileHandlers
      ..add((_, _) => reconcileA.future)
      ..add((_, _) => reconcileB.future);

    await service.start();
    final readyFuture = service.markPostSplashReady();
    for (var i = 0; i < 5 && preferenceRepository.reconcileCalls.isEmpty; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(preferenceRepository.reconcileCalls.single.userId, _userA.id);

    authSession.emit(state: const AuthState.authenticated(user: _userB));
    for (var i = 0; i < 5 && preferenceRepository.reconcileCalls.length < 2; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(preferenceRepository.reconcileCalls.last.userId, _userB.id);

    reconcileB.complete(
      ProductAnalyticsPreferenceSynchronized(
        record: _record(
          userId: _userB.id,
          userKey: _userKeyB,
          preference: ProductAnalyticsPreference.disabled,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    reconcileA.complete(
      ProductAnalyticsPreferenceSynchronized(
        record: _record(
          userId: _userA.id,
          userKey: _userKeyA,
          preference: ProductAnalyticsPreference.enabled,
        ),
      ),
    );
    await readyFuture;
    await Future<void>.delayed(Duration.zero);

    expect(service.state.displayedPreference, ProductAnalyticsPreference.disabled);
    expect(service.state.isActive, isFalse);
    expect(analyticsRepository.calls, isEmpty);
  });

  test("a synchronous auth change rejects events before the stream listener runs", () async {
    createService();
    final enabled = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabled),
    );
    await service.start();
    await service.markPostSplashReady();
    await waitForAnalyticsCalls(count: 1);
    analyticsRepository.calls.clear();

    authSession.emit(state: const AuthState.authenticated(user: _userB));
    final result = await service.logEvent(
      event: const ProductAnalyticsEvent.whyBridgeOpened(surface: OnboardingSurface.connectSetup),
      occurredAtUtc: DateTime.utc(2026, 7, 29),
    );

    expect(result, AnalyticsDeliveryResult.failed);
    expect(analyticsRepository.calls, isEmpty);
  });

  test("account switch suppresses the previous user key before the new local read completes", () async {
    createService();
    final enabledA = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.enabled,
    );
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: enabledA),
    );
    await service.start();
    await service.markPostSplashReady();
    await waitForAnalyticsCalls(count: 1);
    analyticsRepository.calls.clear();

    final loadB = Completer<LocalProductAnalyticsPreference?>();
    preferenceRepository.loadHandlers[_userB.id] = () => loadB.future;
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(
        record: _record(
          userId: _userB.id,
          userKey: _userKeyB,
          preference: ProductAnalyticsPreference.disabled,
        ),
      ),
    );

    authSession.emit(state: const AuthState.authenticated(user: _userB));
    await Future<void>.delayed(Duration.zero);

    expect(service.state.isActive, isFalse);
    expect(
      await service.logEvent(
        event: const ProductAnalyticsEvent.whyBridgeOpened(surface: OnboardingSurface.connectSetup),
        occurredAtUtc: DateTime.utc(2026, 7, 29),
      ),
      AnalyticsDeliveryResult.failed,
    );
    expect(analyticsRepository.calls, isEmpty);

    loadB.complete(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  });

  test("same-account auth emissions do not reload while explicit refresh still reads again", () async {
    createService();
    final record = _record(
      userId: _userA.id,
      userKey: _userKeyA,
      preference: ProductAnalyticsPreference.disabled,
    );
    for (var i = 0; i < 3; i++) {
      preferenceRepository.reconcileHandlers.add(
        (_, _) async => ProductAnalyticsPreferenceSynchronized(record: record),
      );
    }

    await service.start();
    await service.markPostSplashReady();
    await service.markPostSplashReady();
    expect(preferenceRepository.reconcileCalls, hasLength(1));

    await service.refreshPreference();
    expect(preferenceRepository.reconcileCalls, hasLength(2));

    authSession.emit(state: const AuthState.authenticated(user: _userA));
    await Future<void>.delayed(Duration.zero);
    expect(preferenceRepository.reconcileCalls, hasLength(2));
  });
}
