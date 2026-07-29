import "dart:async";

import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../foundation/models/product_analytics/analytics_runtime_capability.dart";
import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../foundation/models/product_analytics/product_analytics_preference.dart";
import "../logging/logging.dart";
import "../repositories/models/analytics_delivery_result.dart";
import "../repositories/models/product_analytics_preference_models.dart";
import "../repositories/product_analytics_preference_repository.dart";
import "../repositories/product_analytics_repository.dart";
import "models/product_analytics_state.dart";

const _logoutPreparationDeadline = Duration(seconds: 10);

@lazySingleton
class ProductAnalyticsService {
  final AnalyticsRuntimeCapability _capability;
  final AuthSession _authSession;
  final ProductAnalyticsRepository _analyticsRepository;
  final ProductAnalyticsPreferenceRepository _preferenceRepository;
  final BehaviorSubject<ProductAnalyticsState> _state = BehaviorSubject.seeded(ProductAnalyticsState.initial);

  StreamSubscription<AuthState>? _authSubscription;
  ({int generation, Future<void> future})? _accountOperation;
  Future<void>? _localInitialization;
  LocalProductAnalyticsPreference? _local;
  LocalProductAnalyticsPendingDisable? _volatileDisable;
  ProductAnalyticsPreferenceRecord? _currentRecord;
  String? _userId;
  int _generation = 0;
  int? _reconciledGeneration;
  int? _schemaReadyGeneration;
  int? _schemaReportGeneration;
  Future<void>? _schemaReport;
  ({int generation, ProductAnalyticsState state})? _logoutPreparation;
  bool _reconcileAfterFailedLogout = false;
  bool _postSplashReady = false;
  bool _localReadFailed = false;
  int _preferenceRequestSequence = 0;
  ProductAnalyticsPreference? _latestRequestedPreference;
  Future<void>? _startFuture;

  ProductAnalyticsService({
    required AnalyticsRuntimeCapability capability,
    required AuthSession authSession,
    required ProductAnalyticsRepository analyticsRepository,
    required ProductAnalyticsPreferenceRepository preferenceRepository,
  }) : _capability = capability,
       _authSession = authSession,
       _analyticsRepository = analyticsRepository,
       _preferenceRepository = preferenceRepository;

  ValueStream<ProductAnalyticsState> get stateStream => _state.stream;
  ProductAnalyticsState get state => _state.value;

  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    final initialStateObserved = Completer<void>();
    _authSubscription = _authSession.authStateStream.listen((authState) {
      final application = _applyAuthState(authState);
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
    if (_postSplashReady) return;
    _postSplashReady = true;
    await _awaitLatestLocalInitialization();
    await _reconcileIfNeeded(force: false, allowDuringLogout: false);
  }

  Future<void> refreshPreference() {
    if (_volatileDisable != null) return retryPendingDisable();
    if (_localReadFailed) return _retryLocalReadAndReconcile();
    return _reconcileIfNeeded(force: true, allowDuringLogout: false);
  }

  Future<void> setPreference({required ProductAnalyticsPreference preference}) async {
    final userId = _userId;
    if (userId == null) return;
    final generation = _generation;
    final requestSequence = ++_preferenceRequestSequence;
    _latestRequestedPreference = preference;
    _volatileDisable = null;
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
              _reconcileAfterFailedLogout = true;
            }
            return;
          }
          _emitPreferenceRequestInProgress(preference: preference);
          var operationRecord = _currentRecord;
          if (operationRecord == null) {
            await _performReconciliation(
              generation: generation,
              userId: userId,
              allowDuringLogout: allowDuringLogout,
              pendingPreference: preference,
            );
            if (!_canApply(
              generation: generation,
              userId: userId,
              allowDuringLogout: allowDuringLogout,
            )) {
              if (_matchesAccount(generation: generation, userId: userId)) {
                _reconcileAfterFailedLogout = true;
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
          if (!_canApply(
            generation: generation,
            userId: userId,
            allowDuringLogout: allowDuringLogout,
          )) {
            if (_matchesAccount(generation: generation, userId: userId)) {
              _reconcileAfterFailedLogout = true;
            }
            return;
          }
          if (_logoutPreparation != null) _reconcileAfterFailedLogout = true;
          final newerPreference = requestSequence == _preferenceRequestSequence ? null : _latestRequestedPreference;
          await _applyRepositoryResult(result: result, pendingPreference: newerPreference);
          if (newerPreference != null) {
            _emitPreferenceRequestInProgress(preference: newerPreference);
          }
        },
      );
    } finally {
      if (requestSequence == _preferenceRequestSequence) {
        _latestRequestedPreference = null;
      }
    }
  }

  Future<void> retryPendingDisable() async {
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

  Future<void> prepareForLogout() async {
    final userId = _userId;
    if (userId == null) return;
    _logoutPreparation ??= (generation: _generation, state: state);
    _state.add(
      ProductAnalyticsState(
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
    final activeOperation = _accountOperation;
    if (activeOperation != null && activeOperation.generation == _generation) {
      await activeOperation.future;
    }
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
    final preparation = _logoutPreparation;
    _logoutPreparation = null;
    if (preparation == null || preparation.generation != _generation || _userId == null) return;
    final shouldReconcile = _reconcileAfterFailedLogout;
    _reconcileAfterFailedLogout = false;
    final availability = state.availability;
    if (availability is ProductAnalyticsInactive &&
        availability.reason == ProductAnalyticsInactiveReason.unauthenticated) {
      _state.add(preparation.state);
    }
    if (shouldReconcile) {
      if (_localReadFailed) {
        await _retryLocalReadAndReconcile();
      } else {
        await _reconcileIfNeeded(force: true, allowDuringLogout: false);
      }
    }
  }

  Future<AnalyticsDeliveryResult> logEvent({
    required ProductAnalyticsEvent event,
    required DateTime occurredAtUtc,
  }) async {
    final availability = state.availability;
    final userId = _userId;
    final generation = _generation;
    final current = _currentRecord;
    if (availability is! ProductAnalyticsActive || userId == null || current == null) {
      return AnalyticsDeliveryResult.failed;
    }
    final result = await _analyticsRepository.logEvent(
      envelope: ProductAnalyticsEnvelope(event: event, occurredAtUtc: occurredAtUtc),
      userKey: current.userKey,
    );
    return _matches(generation: generation, userId: userId) ? result : AnalyticsDeliveryResult.failed;
  }

  Future<void> _applyAuthState(AuthState authState) {
    _generation += 1;
    _reconciledGeneration = null;
    _schemaReadyGeneration = null;
    _schemaReportGeneration = null;
    _schemaReport = null;
    _logoutPreparation = null;
    _reconcileAfterFailedLogout = false;
    _accountOperation = null;
    _currentRecord = null;
    _local = null;
    _volatileDisable = null;
    _localReadFailed = false;
    _latestRequestedPreference = null;
    final userId = switch (authState) {
      AuthAuthenticated(:final user) => user.id,
      AuthInitial() || AuthUnauthenticated() || AuthAuthenticating() || AuthFailed() => null,
    };
    _userId = userId;
    if (userId == null) {
      final initialization = Future<void>.value();
      _localInitialization = initialization;
      _state.add(ProductAnalyticsState.initial);
      return initialization;
    }

    _applyLocalState(null);

    final generation = _generation;
    final initialization = _loadAndApplyLocalPreference(generation: generation, userId: userId);
    _localInitialization = initialization;
    return initialization.then<void>((_) async {
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
      _local = local;
      if (_logoutPreparation != null) {
        _currentRecord = local?.record;
        _reconcileAfterFailedLogout = true;
        return;
      }
      _applyLocalState(local);
    } on Object catch (error, stackTrace) {
      logw("Failed to read local analytics preference", error, stackTrace);
      if (!_matchesAccount(generation: generation, userId: userId)) return;
      _localReadFailed = true;
      if (_logoutPreparation != null) {
        _reconcileAfterFailedLogout = true;
        return;
      }
      _state.add(
        const ProductAnalyticsState(
          preference: ProductAnalyticsPreferenceUnknown(),
          synchronization: ProductAnalyticsSynchronizationFailed(),
          availability: ProductAnalyticsInactive(reason: ProductAnalyticsInactiveReason.storageFailure),
        ),
      );
    }
  }

  void _applyLocalState(LocalProductAnalyticsPreference? local) {
    if (local == null) {
      _state.add(
        ProductAnalyticsState(
          preference: const ProductAnalyticsPreferenceUnknown(),
          synchronization: const ProductAnalyticsNotSynchronized(),
          availability: ProductAnalyticsInactive(
            reason: _postSplashReady
                ? ProductAnalyticsInactiveReason.preferenceUnknown
                : ProductAnalyticsInactiveReason.postSplashNotReady,
          ),
        ),
      );
      return;
    }
    _currentRecord = local.record;
    switch (local) {
      case LocalProductAnalyticsSynced(:final record):
        _emitInactiveForPreference(
          preference: record.preference,
          synchronization: const ProductAnalyticsSynchronized(),
          reason: null,
        );
      case LocalProductAnalyticsPendingDisable():
        _emitInactiveForPreference(
          preference: ProductAnalyticsPreference.disabled,
          synchronization: const ProductAnalyticsDisablePending(),
          reason: null,
        );
      case LocalProductAnalyticsPendingEnable():
        _emitInactiveForPreference(
          preference: ProductAnalyticsPreference.enabled,
          synchronization: const ProductAnalyticsEnablePending(),
          reason: null,
        );
    }
  }

  Future<void> _awaitLatestLocalInitialization() async {
    while (true) {
      final initialization = _localInitialization;
      if (initialization == null) return;
      await initialization;
      if (identical(initialization, _localInitialization)) return;
    }
  }

  Future<void> _reconcileIfNeeded({required bool force, required bool allowDuringLogout}) async {
    await _awaitLatestLocalInitialization();
    final userId = _userId;
    if (!_postSplashReady || userId == null || _localReadFailed) return;
    if (!force && _reconciledGeneration == _generation) return;
    final generation = _generation;
    await _runAccountOperation(
      generation: generation,
      userId: userId,
      operation: () async {
        if (!force && _reconciledGeneration == generation) return;
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
    final userId = _userId;
    if (!_postSplashReady || userId == null) return;
    final generation = _generation;
    try {
      final local = await _preferenceRepository.loadLocal(userId: userId);
      if (!_matches(generation: generation, userId: userId)) return;
      _localReadFailed = false;
      _local = local;
      _applyLocalState(local);
    } on Object catch (error, stackTrace) {
      logw("Failed to retry local analytics preference read", error, stackTrace);
      return;
    }
    await _reconcileIfNeeded(force: true, allowDuringLogout: false);
  }

  Future<void> _performReconciliation({
    required int generation,
    required String userId,
    required bool allowDuringLogout,
    required ProductAnalyticsPreference? pendingPreference,
  }) async {
    _state.add(
      ProductAnalyticsState(
        preference: state.preference,
        synchronization: const ProductAnalyticsSynchronizationInProgress(),
        availability: const ProductAnalyticsInactive(reason: ProductAnalyticsInactiveReason.preferenceUnknown),
      ),
    );
    final result = await _preferenceRepository.reconcile(userId: userId, local: _local);
    if (!_canApply(
      generation: generation,
      userId: userId,
      allowDuringLogout: allowDuringLogout,
    )) {
      if (_matchesAccount(generation: generation, userId: userId) && _logoutPreparation != null) {
        _reconcileAfterFailedLogout = true;
      }
      return;
    }
    if (_logoutPreparation != null) _reconcileAfterFailedLogout = true;
    _reconciledGeneration = generation;
    await _applyRepositoryResult(
      result: result,
      pendingPreference: pendingPreference ?? _latestRequestedPreference,
    );
  }

  Future<void> _applyRepositoryResult({
    required ProductAnalyticsPreferenceRepositoryResult result,
    required ProductAnalyticsPreference? pendingPreference,
  }) async {
    switch (result) {
      case ProductAnalyticsPreferenceSynchronized(:final record):
        _volatileDisable = null;
        _currentRecord = record;
        _local = LocalProductAnalyticsSynced(record: record);
        if (pendingPreference != null) {
          _emitPreferenceRequestInProgress(preference: pendingPreference);
        } else if (record.preference == ProductAnalyticsPreference.enabled && _capability.isEnabled) {
          _state.add(
            ProductAnalyticsState(
              preference: ProductAnalyticsPreferenceKnown(preference: record.preference),
              synchronization: const ProductAnalyticsSynchronized(),
              availability: const ProductAnalyticsActive(),
            ),
          );
          unawaited(
            _reportSchemaReadyIfNeeded().catchError((Object error, StackTrace stackTrace) {
              logw("Failed to report analytics schema readiness", error, stackTrace);
            }),
          );
        } else {
          _emitInactiveForPreference(
            preference: record.preference,
            synchronization: const ProductAnalyticsSynchronized(),
            reason: null,
          );
        }
      case ProductAnalyticsPreferencePendingSync(:final pending):
        _volatileDisable = null;
        _local = pending;
        _currentRecord = pending.record;
        _emitInactiveForPreference(
          preference: pending is LocalProductAnalyticsPendingDisable
              ? ProductAnalyticsPreference.disabled
              : ProductAnalyticsPreference.enabled,
          synchronization: pending is LocalProductAnalyticsPendingDisable
              ? const ProductAnalyticsDisablePending()
              : const ProductAnalyticsEnablePending(),
          reason: null,
        );
      case ProductAnalyticsPreferenceVolatileDisablePending(:final pending):
        _volatileDisable = pending;
        _local = null;
        _currentRecord = pending.record;
        _emitInactiveForPreference(
          preference: ProductAnalyticsPreference.disabled,
          synchronization: const ProductAnalyticsDisableRetryRequired(),
          reason: ProductAnalyticsInactiveReason.storageFailure,
        );
      case ProductAnalyticsPreferenceRefreshRequired(:final record):
        _volatileDisable = null;
        _currentRecord = record;
        _local = LocalProductAnalyticsSynced(record: record);
        _emitInactiveForPreference(
          preference: record.preference,
          synchronization: const ProductAnalyticsSynchronizationFailed(),
          reason: null,
        );
      case ProductAnalyticsPreferenceServerConfirmedStorageFailed(:final record):
        _volatileDisable = null;
        _currentRecord = record;
        _emitInactiveForPreference(
          preference: record.preference,
          synchronization: const ProductAnalyticsSynchronizationFailed(),
          reason: ProductAnalyticsInactiveReason.storageFailure,
        );
      case ProductAnalyticsPreferenceTimedOut() || ProductAnalyticsPreferenceFailed():
        _state.add(
          ProductAnalyticsState(
            preference: state.preference,
            synchronization: const ProductAnalyticsSynchronizationFailed(),
            availability: const ProductAnalyticsInactive(reason: ProductAnalyticsInactiveReason.requestFailure),
          ),
        );
      case ProductAnalyticsPreferenceStorageFailed():
        final current = _currentRecord;
        if (current == null) {
          _state.add(
            const ProductAnalyticsState(
              preference: ProductAnalyticsPreferenceUnknown(),
              synchronization: ProductAnalyticsSynchronizationFailed(),
              availability: ProductAnalyticsInactive(reason: ProductAnalyticsInactiveReason.storageFailure),
            ),
          );
        } else {
          _emitInactiveForPreference(
            preference: current.preference,
            synchronization: const ProductAnalyticsSynchronizationFailed(),
            reason: ProductAnalyticsInactiveReason.storageFailure,
          );
        }
    }
  }

  void _emitInactiveForPreference({
    required ProductAnalyticsPreference preference,
    required ProductAnalyticsSynchronizationStatus synchronization,
    required ProductAnalyticsInactiveReason? reason,
  }) {
    final synchronizationPending = switch (synchronization) {
      ProductAnalyticsSynchronizationInProgress() ||
      ProductAnalyticsDisableRequestInProgress() ||
      ProductAnalyticsEnableRequestInProgress() ||
      ProductAnalyticsDisablePending() ||
      ProductAnalyticsEnablePending() ||
      ProductAnalyticsDisableRetryRequired() => true,
      ProductAnalyticsNotSynchronized() ||
      ProductAnalyticsSynchronized() ||
      ProductAnalyticsSynchronizationFailed() => false,
    };
    final effectiveReason =
        reason ??
        (synchronizationPending
            ? ProductAnalyticsInactiveReason.synchronizationPending
            : preference == ProductAnalyticsPreference.disabled
            ? ProductAnalyticsInactiveReason.preferenceDisabled
            : !_capability.isEnabled
            ? ProductAnalyticsInactiveReason.runtimeUnavailable
            : _postSplashReady
            ? ProductAnalyticsInactiveReason.preferenceUnknown
            : ProductAnalyticsInactiveReason.postSplashNotReady);
    _state.add(
      ProductAnalyticsState(
        preference: ProductAnalyticsPreferenceKnown(preference: preference),
        synchronization: synchronization,
        availability: ProductAnalyticsInactive(reason: effectiveReason),
      ),
    );
  }

  Future<void> _reportSchemaReadyIfNeeded() async {
    final generation = _generation;
    if (_schemaReadyGeneration == generation) return;
    final activeReport = _schemaReport;
    if (_schemaReportGeneration == generation && activeReport != null) {
      await activeReport;
      return;
    }
    final report = _deliverSchemaReady(generation: generation);
    _schemaReportGeneration = generation;
    _schemaReport = report;
    try {
      await report;
    } finally {
      if (identical(_schemaReport, report)) {
        _schemaReport = null;
        _schemaReportGeneration = null;
      }
    }
  }

  Future<void> _deliverSchemaReady({required int generation}) async {
    final result = await logEvent(
      event: const ProductAnalyticsEvent.analyticsSchemaReady(),
      occurredAtUtc: DateTime.now().toUtc(),
    );
    if (generation == _generation && result == AnalyticsDeliveryResult.acceptedBySdk) {
      _schemaReadyGeneration = generation;
    }
  }

  Future<void> _runAccountOperation({
    required int generation,
    required String userId,
    required Future<void> Function() operation,
  }) {
    final active = _accountOperation;
    final previous = active != null && active.generation == generation ? active.future : null;
    final future = () async {
      if (previous != null) {
        try {
          await previous;
        } on Object {
          // The prior caller owns its surfaced failure. A later explicit action
          // must still be allowed to recover this account generation.
        }
      }
      if (!_matchesAccount(generation: generation, userId: userId)) return;
      await operation();
    }();
    _accountOperation = (generation: generation, future: future);
    return future.whenComplete(() {
      if (identical(_accountOperation?.future, future)) _accountOperation = null;
    });
  }

  void _emitPreferenceRequestInProgress({required ProductAnalyticsPreference preference}) {
    _emitInactiveForPreference(
      preference: preference,
      synchronization: preference == ProductAnalyticsPreference.disabled
          ? const ProductAnalyticsDisableRequestInProgress()
          : const ProductAnalyticsEnableRequestInProgress(),
      reason: null,
    );
  }

  bool _matchesAccount({required int generation, required String userId}) =>
      generation == _generation && userId == _userId;

  bool _canApply({required int generation, required String userId, required bool allowDuringLogout}) =>
      _matchesAccount(generation: generation, userId: userId) && (allowDuringLogout || _logoutPreparation == null);

  bool _matches({required int generation, required String userId}) =>
      _canApply(generation: generation, userId: userId, allowDuringLogout: false);

  @disposeMethod
  Future<void> dispose() async {
    // Invalidate every in-flight account-scoped completion before closing the
    // replay subject so detached timeout/storage work cannot publish afterward.
    _generation += 1;
    _userId = null;
    _postSplashReady = false;
    await _authSubscription?.cancel();
    _authSubscription = null;
    await _state.close();
  }
}
