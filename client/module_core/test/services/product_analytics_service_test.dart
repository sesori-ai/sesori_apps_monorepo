import "dart:async";
import "dart:collection";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
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

class _RecordingProductAnalyticsRepository extends Mock implements ProductAnalyticsRepository {
  final calls = <({ProductAnalyticsEnvelope envelope, String userKey})>[];
  AnalyticsDeliveryResult result = AnalyticsDeliveryResult.acceptedBySdk;
  Completer<AnalyticsDeliveryResult>? deliveryCompleter;

  @override
  Future<AnalyticsDeliveryResult> logEvent({
    required ProductAnalyticsEnvelope envelope,
    required String userKey,
  }) async {
    calls.add((envelope: envelope, userKey: userKey));
    final completer = deliveryCompleter;
    if (completer != null) return completer.future;
    return result;
  }
}

void main() {
  late _FakeAuthSession authSession;
  late _FakePreferenceRepository preferenceRepository;
  late _RecordingProductAnalyticsRepository analyticsRepository;
  late ProductAnalyticsService service;

  void createService() {
    authSession = _FakeAuthSession(initialState: const AuthState.authenticated(user: _userA));
    preferenceRepository = _FakePreferenceRepository();
    analyticsRepository = _RecordingProductAnalyticsRepository();
    service = ProductAnalyticsService(
      capability: const AnalyticsRuntimeCapability.enabled(),
      authSession: authSession,
      analyticsRepository: analyticsRepository,
      preferenceRepository: preferenceRepository,
    );
  }

  void createServiceWithCapability({required AnalyticsRuntimeCapability capability}) {
    authSession = _FakeAuthSession(initialState: const AuthState.authenticated(user: _userA));
    preferenceRepository = _FakePreferenceRepository();
    analyticsRepository = _RecordingProductAnalyticsRepository();
    service = ProductAnalyticsService(
      capability: capability,
      authSession: authSession,
      analyticsRepository: analyticsRepository,
      preferenceRepository: preferenceRepository,
    );
  }

  tearDown(() async {
    await service.dispose();
    await authSession.dispose();
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
    preferenceRepository.reconcileHandlers.add(
      (_, _) async => ProductAnalyticsPreferenceSynchronized(record: record),
    );

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

    await service.markPostSplashReady();

    expect(preferenceRepository.reconcileCalls, hasLength(1));
    expect(service.state.isActive, isTrue);
    expect(analyticsRepository.calls, hasLength(1));
    expect(analyticsRepository.calls.single.envelope.event, isA<AnalyticsSchemaReadyEvent>());
    expect(analyticsRepository.calls.single.userKey, _userKeyA);

    await service.markPostSplashReady();
    expect(preferenceRepository.reconcileCalls, hasLength(1));
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

  test("schema readiness retries after SDK rejection in the same auth generation", () async {
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
    expect(analyticsRepository.calls, hasLength(1));

    analyticsRepository.result = AnalyticsDeliveryResult.acceptedBySdk;
    await service.refreshPreference();

    expect(analyticsRepository.calls, hasLength(2));
    expect(
      analyticsRepository.calls.map((call) => call.envelope.event),
      everyElement(isA<AnalyticsSchemaReadyEvent>()),
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

    preferenceRepository.throwOnLoad = false;
    await service.refreshPreference();

    expect(preferenceRepository.reconcileCalls, hasLength(1));
    expect(service.state.isActive, isTrue);
    expect(analyticsRepository.calls.single.envelope.event, isA<AnalyticsSchemaReadyEvent>());
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

    final pending = LocalProductAnalyticsPendingDisable(record: enabled, operationId: _operationId);
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

    final pending = LocalProductAnalyticsPendingEnable(record: disabled, operationId: _operationId);
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

    final volatile = LocalProductAnalyticsPendingDisable(record: enabled, operationId: _operationId);
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

  test("prepareForLogout suppresses first and makes one pending-disable retry", () async {
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

    final pending = LocalProductAnalyticsPendingDisable(record: enabled, operationId: _operationId);
    preferenceRepository.setHandlers.add(
      (_, _, _) async => ProductAnalyticsPreferencePendingSync(pending: pending),
    );
    await service.setPreference(preference: ProductAnalyticsPreference.disabled);
    preferenceRepository.reconcileHandlers.add(
      (_, local) async {
        expect(service.state.isActive, isFalse);
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
    await service.prepareForLogout();
    localLoad.complete(LocalProductAnalyticsSynced(record: enabled));
    await Future.wait([startFuture, readyFuture]);

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

    final pending = LocalProductAnalyticsPendingDisable(record: enabled, operationId: _operationId);
    preferenceRepository.setHandlers.add(
      (_, _, _) async => ProductAnalyticsPreferencePendingSync(pending: pending),
    );
    await service.setPreference(preference: ProductAnalyticsPreference.disabled);

    final hangingRetry = Completer<ProductAnalyticsPreferenceRepositoryResult>();
    preferenceRepository.reconcileHandlers.add((_, _) => hangingRetry.future);
    fakeAsync((async) {
      var completed = false;
      service.prepareForLogout().then((_) => completed = true);

      async.elapse(const Duration(seconds: 10));
      async.flushMicrotasks();

      expect(completed, isTrue);
      expect(service.state.isActive, isFalse);
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

  test("one automatic read occurs per auth generation while explicit refresh reads again", () async {
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
    for (var i = 0; i < 5 && preferenceRepository.reconcileCalls.length < 3; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(preferenceRepository.reconcileCalls, hasLength(3));
  });
}
