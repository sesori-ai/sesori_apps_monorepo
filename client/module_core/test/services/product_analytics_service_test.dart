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
  int revision = 1,
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

  void emit(AuthState state) => states.add(state);

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

  @override
  Future<AnalyticsDeliveryResult> logEvent({
    required ProductAnalyticsEnvelope envelope,
    required String userKey,
  }) async {
    calls.add((envelope: envelope, userKey: userKey));
    return result;
  }
}

void main() {
  late _FakeAuthSession authSession;
  late _FakePreferenceRepository preferenceRepository;
  late _RecordingProductAnalyticsRepository analyticsRepository;
  late ProductAnalyticsService service;

  void createService({
    AnalyticsRuntimeCapability capability = const AnalyticsRuntimeCapability.enabled(),
    AuthState initialAuthState = const AuthState.authenticated(user: _userA),
  }) {
    authSession = _FakeAuthSession(initialState: initialAuthState);
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

    authSession.emit(const AuthState.authenticated(user: _userB));
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
    createService(
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
          record: _record(
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
          record: _record(
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

    authSession.emit(const AuthState.authenticated(user: _userB));
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
    await readyFuture;
    await Future<void>.delayed(Duration.zero);

    expect(service.state.displayedPreference, ProductAnalyticsPreference.disabled);
    expect(service.state.isActive, isFalse);
    expect(analyticsRepository.calls, isEmpty);
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

    authSession.emit(const AuthState.authenticated(user: _userA));
    for (var i = 0; i < 5 && preferenceRepository.reconcileCalls.length < 3; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(preferenceRepository.reconcileCalls, hasLength(3));
  });
}
