import "dart:async";

import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../foundation/models/product_analytics/analytics_runtime_capability.dart";
import "../foundation/models/product_analytics/product_analytics_preference.dart";
import "../logging/logging.dart";
import "../repositories/models/product_analytics_preference_models.dart";
import "../repositories/product_analytics_preference_repository.dart";
import "models/product_analytics_preference_runtime.dart";
import "models/product_analytics_preference_snapshot.dart";
import "models/product_analytics_state.dart";
import "product_analytics_account_operation_dispatcher.dart";
import "product_analytics_preference_state_mapper.dart";

const _logoutPreparationDeadline = Duration(seconds: 10);

final class ProductAnalyticsDeliveryContext {
  final int generation;
  final String userId;
  final String userKey;

  const ProductAnalyticsDeliveryContext({
    required this.generation,
    required this.userId,
    required this.userKey,
  });
}

@lazySingleton
class ProductAnalyticsPreferenceService {
  final AnalyticsRuntimeCapability _capability;
  final AuthSession _authSession;
  final ProductAnalyticsPreferenceRepository _preferenceRepository;
  final ProductAnalyticsPreferenceStateMapper _stateMapper;
  final BehaviorSubject<ProductAnalyticsState> _state = BehaviorSubject.seeded(ProductAnalyticsState.initial);
  final ProductAnalyticsAccountOperationDispatcher _operations = ProductAnalyticsAccountOperationDispatcher();

  StreamSubscription<AuthState>? _authSubscription;
  ProductAnalyticsAccountSession _session = const ProductAnalyticsSignedOutSession(generation: 0);
  int _generationCounter = 0;
  ProductAnalyticsLogoutState _logout = const ProductAnalyticsLogoutIdle();
  ({int generation, Future<void> future})? _logoutPreparationOperation;
  bool _postSplashReady = false;
  ProductAnalyticsPreferenceIntent _intent = const ProductAnalyticsPreferenceIntent.idle();
  Future<void>? _startFuture;
  Future<void>? _disposeFuture;
  bool _disposed = false;

  ProductAnalyticsPreferenceService({
    required AnalyticsRuntimeCapability capability,
    required AuthSession authSession,
    required ProductAnalyticsPreferenceRepository preferenceRepository,
  }) : _capability = capability,
       _authSession = authSession,
       _preferenceRepository = preferenceRepository,
       _stateMapper = ProductAnalyticsPreferenceStateMapper(capability: capability);

  ValueStream<ProductAnalyticsState> get stateStream => _state.stream;
  ProductAnalyticsState get state => _state.value;

  String? get _userId => _session.userId;
  int get _generation => _session.generation;
  ProductAnalyticsPreferenceSnapshot get _snapshot => _session.snapshot;
  set _snapshot(ProductAnalyticsPreferenceSnapshot value) => _session = _session.withSnapshot(snapshot: value);
  LocalProductAnalyticsPreference? get _local => _snapshot.local;
  ProductAnalyticsPreferenceRecord? get _currentRecord => _snapshot.currentRecord;
  LocalProductAnalyticsPendingDisable? get _volatileDisable => _snapshot.volatileDisable;
  bool get _localReadFailed => _snapshot.storageReadFailed;
  bool get _isPreparingLogout => _logout is ProductAnalyticsLogoutPreparation;

  ProductAnalyticsDeliveryContext? get deliveryContext {
    if (_disposed) return null;
    final userId = _userId;
    final current = _currentRecord;
    if (!state.isActive || userId == null || current == null || !_authSessionMatches(userId: userId)) return null;
    return ProductAnalyticsDeliveryContext(
      generation: _generation,
      userId: userId,
      userKey: current.userKey,
    );
  }

  bool isCurrentDeliveryContext({required ProductAnalyticsDeliveryContext context}) =>
      !_disposed && _matches(generation: context.generation, userId: context.userId);

  int? get authenticatedGeneration {
    if (_disposed) return null;
    final userId = _userId;
    return userId != null && _authSessionMatches(userId: userId) ? _generation : null;
  }

  int? get deferrableGeneration {
    if (!_capability.isEnabled || _isPreparingLogout || state.preference is! ProductAnalyticsPreferenceUnknown) {
      return null;
    }
    return authenticatedGeneration;
  }

  Future<void> start() {
    if (_disposed) return Future<void>.value();
    return _startFuture ??= _start();
  }

  Future<void> _start() async {
    final initialStateObserved = Completer<void>();
    _authSubscription = _authSession.authStateStream.listen((authState) {
      final application = _applyAuthState(authState: authState);
      if (!initialStateObserved.isCompleted) initialStateObserved.complete();
      unawaited(
        application.catchError((Object error, StackTrace stackTrace) {
          logw("Failed to apply analytics auth state", error, stackTrace);
        }),
      );
    });
    await initialStateObserved.future;
    await _awaitLatestLocalInitialization();
  }

  Future<void> markPostSplashReady() async {
    if (_disposed || _postSplashReady) return;
    _postSplashReady = true;
    await _awaitLatestLocalInitialization();
    if (_disposed) return;
    await _reconcileIfNeeded(force: false, allowDuringLogout: false);
  }

  Future<void> refreshPreference() {
    if (_disposed) return Future<void>.value();
    if (_volatileDisable != null) return retryPendingDisable();
    if (_localReadFailed) return _retryLocalReadAndReconcile();
    return _reconcileIfNeeded(force: true, allowDuringLogout: false);
  }

  Future<void> setPreference({required ProductAnalyticsPreference preference}) async {
    if (_disposed) return;
    final userId = _userId;
    if (userId == null) return;
    final generation = _generation;
    _intent = _intent.begin(preference: preference);
    final requestSequence = _intent.sequence;
    final baseline = _snapshot.commandBaseline;
    _snapshot = ProductAnalyticsPreferenceCommandSnapshot(
      baseline: baseline,
      desiredPreference: preference,
    );
    _emitPreferenceRequestInProgress(preference: preference);
    try {
      await _runAccountOperation(
        generation: generation,
        userId: userId,
        operation: () async {
          await _awaitLatestLocalInitialization();
          final allowDuringLogout = preference == ProductAnalyticsPreference.disabled;
          if (!_canApply(
            generation: generation,
            userId: userId,
            allowDuringLogout: allowDuringLogout,
          )) {
            if (_matchesAccount(generation: generation, userId: userId)) {
              _requireLogoutRecovery();
            }
            return;
          }
          final visiblePreference = requestSequence == _intent.sequence
              ? preference
              : _intent.latestPreference ?? preference;
          _emitPreferenceRequestInProgress(preference: visiblePreference);
          var operationRecord = _currentRecord;
          if (operationRecord == null) {
            await _performReconciliation(
              generation: generation,
              userId: userId,
              allowDuringLogout: allowDuringLogout,
              pendingPreference: visiblePreference,
            );
            if (!_canApply(
              generation: generation,
              userId: userId,
              allowDuringLogout: allowDuringLogout,
            )) {
              if (_matchesAccount(generation: generation, userId: userId)) {
                _requireLogoutRecovery();
              }
              return;
            }
            operationRecord = _currentRecord;
            if (operationRecord == null) return;
          }
          final result = await _preferenceRepository.setPreference(
            userId: userId,
            current: operationRecord,
            preference: preference,
          );
          if (!_matchesAccount(generation: generation, userId: userId)) return;
          final publishState = !_isPreparingLogout;
          if (!publishState) _requireLogoutRecovery();
          final newerPreference = requestSequence == _intent.sequence ? null : _intent.latestPreference;
          await _applyRepositoryResult(
            result: result,
            pendingPreference: newerPreference,
            publishState: publishState,
          );
          if (publishState && newerPreference != null) {
            _emitPreferenceRequestInProgress(preference: newerPreference);
          }
        },
      );
    } finally {
      _intent = _intent.complete(sequence: requestSequence);
    }
  }

  Future<void> retryPendingDisable() async {
    if (_disposed) return;
    if (_volatileDisable != null) {
      final current = _currentRecord;
      if (current != null) {
        await setPreference(preference: ProductAnalyticsPreference.disabled);
      }
      return;
    }
    if (_local is! LocalProductAnalyticsPendingDisable) return;
    await _reconcileIfNeeded(force: true, allowDuringLogout: false);
  }

  Future<void> prepareForLogout() {
    if (_disposed) return Future<void>.value();
    final userId = _userId;
    if (userId == null) return Future<void>.value();
    final generation = _generation;
    final active = _logoutPreparationOperation;
    if (active != null && active.generation == generation) return active.future;

    late final Future<void> tracked;
    tracked = _prepareForLogout().whenComplete(() {
      if (identical(_logoutPreparationOperation?.future, tracked)) {
        _logoutPreparationOperation = null;
      }
    });
    _logoutPreparationOperation = (generation: generation, future: tracked);
    return tracked;
  }

  Future<void> _prepareForLogout() async {
    if (_logout is ProductAnalyticsLogoutIdle) {
      _logout = ProductAnalyticsLogoutPreparationClean(generation: _generation, capturedState: state);
    }
    _emitState(
      state: ProductAnalyticsState(
        preference: state.preference,
        synchronization: state.synchronization,
        availability: const ProductAnalyticsInactive(reason: ProductAnalyticsInactiveReason.unauthenticated),
      ),
    );
    try {
      await _synchronizeBeforeLogout().timeout(_logoutPreparationDeadline);
    } on Object catch (error, stackTrace) {
      logw("Failed to synchronize product analytics before logout", error, stackTrace);
    }
  }

  Future<void> _synchronizeBeforeLogout() async {
    await _awaitLatestLocalInitialization();
    if (_localReadFailed && !await _retryLocalRead(allowDuringLogout: true)) {
      await _awaitLatestAccountOperation();
      return;
    }
    await _awaitLatestAccountOperation();
    if (_volatileDisable != null) {
      final current = _currentRecord;
      if (current != null) {
        await setPreference(preference: ProductAnalyticsPreference.disabled);
      }
    } else if (_local is LocalProductAnalyticsPendingDisable) {
      await _reconcileIfNeeded(force: true, allowDuringLogout: true);
    }
  }

  Future<void> resumeAfterFailedLogout() async {
    if (_disposed) return;
    final preparation = _logout;
    _logout = const ProductAnalyticsLogoutIdle();
    if (preparation is! ProductAnalyticsLogoutPreparation || preparation.generation != _generation || _userId == null) {
      return;
    }
    final shouldReconcile = preparation is ProductAnalyticsLogoutPreparationRecoveryRequired;
    if (shouldReconcile) {
      if (_volatileDisable != null) {
        await retryPendingDisable();
      } else if (_localReadFailed) {
        await _retryLocalReadAndReconcile();
      } else {
        await _reconcileIfNeeded(force: true, allowDuringLogout: false);
      }
      return;
    }
    final availability = state.availability;
    if (availability is ProductAnalyticsInactive &&
        availability.reason == ProductAnalyticsInactiveReason.unauthenticated) {
      _emitState(state: preparation.capturedState);
    }
  }

  Future<void> _applyAuthState({required AuthState authState}) {
    if (_disposed) return Future<void>.value();
    final userId = switch (authState) {
      AuthAuthenticated(:final user) => user.id,
      AuthInitial() || AuthUnauthenticated() || AuthAuthenticating() || AuthFailed() => null,
    };
    if (userId != null && userId == _userId) {
      return _session.hydration ?? Future<void>.value();
    }
    final generation = ++_generationCounter;
    _logout = const ProductAnalyticsLogoutIdle();
    _logoutPreparationOperation = null;
    _operations.reset();
    _intent = _intent.reset();
    if (userId == null) {
      _session = ProductAnalyticsSignedOutSession(generation: generation);
      _emitState(state: ProductAnalyticsState.initial);
      return Future<void>.value();
    }

    final completion = Completer<void>();
    _session = ProductAnalyticsHydratingSession(
      userId: userId,
      generation: generation,
      completion: completion,
      snapshot: const ProductAnalyticsPreferenceUnresolved(),
    );
    _applyLocalState(local: null);
    final initialization = _loadAndApplyLocalPreference(generation: generation, userId: userId);
    unawaited(
      initialization.whenComplete(() {
        final current = _session;
        if (current is ProductAnalyticsHydratingSession &&
            current.generation == generation &&
            identical(current.completion, completion)) {
          _session = ProductAnalyticsReadySession(
            userId: userId,
            generation: generation,
            snapshot: current.snapshot,
            reconciled: false,
          );
        }
        if (!completion.isCompleted) completion.complete();
      }),
    );
    return completion.future.then<void>((_) async {
      if (!_matches(generation: generation, userId: userId)) return;
      if (_postSplashReady && !_localReadFailed) {
        await _reconcileIfNeeded(force: false, allowDuringLogout: false);
      }
    });
  }

  Future<void> _loadAndApplyLocalPreference({required int generation, required String userId}) async {
    try {
      final local = await _preferenceRepository.loadLocal(userId: userId);
      if (!_matchesAccount(generation: generation, userId: userId)) return;
      _snapshot = productAnalyticsSnapshotFromLocal(local: local);
      if (_isPreparingLogout) {
        _requireLogoutRecovery();
        return;
      }
      _applyLocalState(local: local);
    } on Object catch (error, stackTrace) {
      logw("Failed to read local analytics preference", error, stackTrace);
      if (!_matchesAccount(generation: generation, userId: userId)) return;
      _snapshot = const ProductAnalyticsPreferenceStorageReadFailedSnapshot();
      if (_isPreparingLogout) {
        _requireLogoutRecovery();
        return;
      }
      _emitState(
        state: _stateMapper.fromLocal(snapshot: _snapshot, postSplashReady: _postSplashReady),
      );
    }
  }

  void _applyLocalState({required LocalProductAnalyticsPreference? local}) {
    _snapshot = productAnalyticsSnapshotFromLocal(local: local);
    _emitState(
      state: _stateMapper.fromLocal(snapshot: _snapshot, postSplashReady: _postSplashReady),
    );
  }

  Future<void> _awaitLatestLocalInitialization() async {
    while (true) {
      final session = _session;
      final hydration = session.hydration;
      if (hydration == null) return;
      await hydration;
      if (identical(session, _session)) return;
    }
  }

  Future<void> _awaitLatestAccountOperation() async {
    await _operations.awaitLatest(generation: _generation);
  }

  Future<void> _reconcileIfNeeded({required bool force, required bool allowDuringLogout}) async {
    await _awaitLatestLocalInitialization();
    final userId = _userId;
    if (!_postSplashReady || userId == null || _localReadFailed) return;
    if (!force && _session.reconciled) return;
    final generation = _generation;
    await _runAccountOperation(
      generation: generation,
      userId: userId,
      operation: () async {
        if (!force && _session.generation == generation && _session.reconciled) return;
        if (_volatileDisable != null) return;
        if (!_canApply(
          generation: generation,
          userId: userId,
          allowDuringLogout: allowDuringLogout,
        )) {
          return;
        }
        await _performReconciliation(
          generation: generation,
          userId: userId,
          allowDuringLogout: allowDuringLogout,
          pendingPreference: null,
        );
      },
    );
  }

  Future<void> _retryLocalReadAndReconcile() async {
    if (!await _retryLocalRead(allowDuringLogout: false)) return;
    await _reconcileIfNeeded(force: true, allowDuringLogout: false);
  }

  Future<bool> _retryLocalRead({required bool allowDuringLogout}) async {
    final userId = _userId;
    if ((!_postSplashReady && !allowDuringLogout) || userId == null) return false;
    final generation = _generation;
    final preferenceRequestSequence = _intent.sequence;
    try {
      final local = await _preferenceRepository.loadLocal(userId: userId);
      if (!_canApply(generation: generation, userId: userId, allowDuringLogout: allowDuringLogout)) return false;
      if (preferenceRequestSequence != _intent.sequence) return false;
      _snapshot = productAnalyticsSnapshotFromLocal(local: local);
      if (_isPreparingLogout) {
        _requireLogoutRecovery();
      } else {
        _applyLocalState(local: local);
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to retry local analytics preference read", error, stackTrace);
      return false;
    }
    return true;
  }

  Future<void> _performReconciliation({
    required int generation,
    required String userId,
    required bool allowDuringLogout,
    required ProductAnalyticsPreference? pendingPreference,
  }) async {
    if (!_isPreparingLogout) {
      _emitState(state: _stateMapper.reconciliationInProgress(current: state));
    }
    final result = await _preferenceRepository.reconcile(userId: userId, local: _local);
    if (!_canApply(
      generation: generation,
      userId: userId,
      allowDuringLogout: allowDuringLogout,
    )) {
      if (_matchesAccount(generation: generation, userId: userId) && _isPreparingLogout) {
        _requireLogoutRecovery();
      }
      return;
    }
    if (_isPreparingLogout) _requireLogoutRecovery();
    _session = _session.markReconciled();
    await _applyRepositoryResult(
      result: result,
      pendingPreference: pendingPreference ?? _intent.latestPreference,
      publishState: !_isPreparingLogout,
    );
  }

  Future<void> _applyRepositoryResult({
    required ProductAnalyticsPreferenceRepositoryResult result,
    required ProductAnalyticsPreference? pendingPreference,
    required bool publishState,
  }) async {
    final transition = _stateMapper.fromRepositoryResult(
      result: result,
      currentSnapshot: _snapshot,
      currentState: state,
      pendingPreference: pendingPreference,
      postSplashReady: _postSplashReady,
      suppressForLogout: !publishState,
    );
    _snapshot = transition.snapshot;
    _emitState(state: transition.state);
  }

  Future<void> _runAccountOperation({
    required int generation,
    required String userId,
    required Future<void> Function() operation,
  }) => _operations.run(
    generation: generation,
    isCurrent: () => _matchesAccount(generation: generation, userId: userId),
    operation: operation,
  );

  void _emitPreferenceRequestInProgress({required ProductAnalyticsPreference preference}) {
    _emitState(
      state: _stateMapper.requestInProgress(
        preference: preference,
        postSplashReady: _postSplashReady,
      ),
    );
  }

  void _emitState({required ProductAnalyticsState state}) {
    if (_disposed) return;
    _state.add(state);
  }

  void _requireLogoutRecovery() {
    final logout = _logout;
    if (logout is ProductAnalyticsLogoutPreparationClean) {
      _logout = ProductAnalyticsLogoutPreparationRecoveryRequired(
        generation: logout.generation,
        capturedState: logout.capturedState,
      );
    }
  }

  bool _matchesAccount({required int generation, required String userId}) =>
      generation == _generation && userId == _userId && _authSessionMatches(userId: userId);

  bool _authSessionMatches({required String userId}) => switch (_authSession.currentState) {
    AuthAuthenticated(:final user) => user.id == userId,
    AuthInitial() || AuthUnauthenticated() || AuthAuthenticating() || AuthFailed() => false,
  };

  bool _canApply({required int generation, required String userId, required bool allowDuringLogout}) =>
      _matchesAccount(generation: generation, userId: userId) && (allowDuringLogout || !_isPreparingLogout);

  bool _matches({required int generation, required String userId}) =>
      _canApply(generation: generation, userId: userId, allowDuringLogout: false);

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    // Invalidate every in-flight account-scoped completion before closing the
    // replay subject so detached timeout/storage work cannot publish afterward.
    _session = ProductAnalyticsSignedOutSession(generation: ++_generationCounter);
    _logout = const ProductAnalyticsLogoutIdle();
    _logoutPreparationOperation = null;
    _operations.reset();
    _intent = _intent.reset();
    _postSplashReady = false;
    await _authSubscription?.cancel();
    _authSubscription = null;
    await _state.close();
  }
}
