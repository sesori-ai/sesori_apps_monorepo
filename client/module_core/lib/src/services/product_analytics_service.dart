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
  Future<void>? _reconciliation;
  Future<void>? _localInitialization;
  Future<void>? _activeDisableUpdate;
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
  bool _postSplashReady = false;
  bool _localReadFailed = false;
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
    await _reconcileIfNeeded(force: false);
  }

  Future<void> refreshPreference() {
    if (_volatileDisable != null) return retryPendingDisable();
    if (_localReadFailed) return _retryLocalReadAndReconcile();
    return _reconcileIfNeeded(force: true);
  }

  Future<void> setPreference({required ProductAnalyticsPreference preference}) async {
    final userId = _userId;
    final current = _currentRecord;
    if (userId == null || current == null) {
      await _reconcileIfNeeded(force: true);
      return;
    }
    final generation = _generation;
    _volatileDisable = null;
    _emitInactiveForPreference(
      record: current,
      preference: preference,
      synchronization: preference == ProductAnalyticsPreference.disabled
          ? const ProductAnalyticsDisableRequestInProgress()
          : const ProductAnalyticsEnableRequestInProgress(),
      reason: null,
    );
    final disableCompletion = preference == ProductAnalyticsPreference.disabled ? Completer<void>() : null;
    final disableUpdate = disableCompletion?.future;
    if (disableUpdate != null) _activeDisableUpdate = disableUpdate;
    try {
      final result = await _preferenceRepository.setPreference(
        userId: userId,
        current: current,
        preference: preference,
      );
      if (!_matches(generation: generation, userId: userId)) return;
      await _applyRepositoryResult(result);
    } finally {
      disableCompletion?.complete();
      if (disableUpdate != null && identical(_activeDisableUpdate, disableUpdate)) {
        _activeDisableUpdate = null;
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
    await _reconcileIfNeeded(force: true);
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
    final activeDisableUpdate = _activeDisableUpdate;
    if (activeDisableUpdate != null) await activeDisableUpdate;
    if (_volatileDisable != null) {
      await retryPendingDisable();
    } else if (_local is LocalProductAnalyticsPendingDisable) {
      await _reconcileIfNeeded(force: true);
    }
  }

  Future<void> resumeAfterFailedLogout() async {
    final preparation = _logoutPreparation;
    _logoutPreparation = null;
    if (preparation == null || preparation.generation != _generation || _userId == null) return;
    final availability = state.availability;
    if (availability is ProductAnalyticsInactive &&
        availability.reason == ProductAnalyticsInactiveReason.unauthenticated) {
      _state.add(preparation.state);
    }
  }

  Future<AnalyticsDeliveryResult> logEvent({
    required ProductAnalyticsEvent event,
    required DateTime occurredAtUtc,
  }) async {
    final availability = state.availability;
    final userId = _userId;
    final generation = _generation;
    if (availability is! ProductAnalyticsActive || userId == null) {
      return AnalyticsDeliveryResult.failed;
    }
    final result = await _analyticsRepository.logEvent(
      envelope: ProductAnalyticsEnvelope(event: event, occurredAtUtc: occurredAtUtc),
      userKey: availability.userKey,
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
    _currentRecord = null;
    _local = null;
    _activeDisableUpdate = null;
    _volatileDisable = null;
    _localReadFailed = false;
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
      if (_postSplashReady && !_localReadFailed) await _reconcileIfNeeded(force: false);
    });
  }

  Future<void> _loadAndApplyLocalPreference({required int generation, required String userId}) async {
    try {
      final local = await _preferenceRepository.loadLocal(userId: userId);
      if (!_matches(generation: generation, userId: userId)) return;
      _local = local;
      _applyLocalState(local);
    } on Object catch (error, stackTrace) {
      logw("Failed to read local analytics preference", error, stackTrace);
      if (!_matches(generation: generation, userId: userId)) return;
      _localReadFailed = true;
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
          record: record,
          preference: record.preference,
          synchronization: const ProductAnalyticsSynchronized(),
          reason: null,
        );
      case LocalProductAnalyticsPendingDisable(:final record):
        _emitInactiveForPreference(
          record: record,
          preference: ProductAnalyticsPreference.disabled,
          synchronization: const ProductAnalyticsDisablePending(),
          reason: null,
        );
      case LocalProductAnalyticsPendingEnable(:final record):
        _emitInactiveForPreference(
          record: record,
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

  Future<void> _reconcileIfNeeded({required bool force}) async {
    await _awaitLatestLocalInitialization();
    final userId = _userId;
    if (!_postSplashReady || userId == null || _localReadFailed) return;
    if (!force && _reconciledGeneration == _generation) return;
    final active = _reconciliation;
    if (active != null) {
      await active.whenComplete(() {
        if (_postSplashReady && _userId != null && _reconciledGeneration != _generation) {
          return _reconcileIfNeeded(force: false);
        }
      });
      return;
    }
    final generation = _generation;
    final future = _performReconciliation(generation: generation, userId: userId);
    _reconciliation = future;
    await future.whenComplete(() {
      if (identical(_reconciliation, future)) _reconciliation = null;
    });
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
    await _reconcileIfNeeded(force: true);
  }

  Future<void> _performReconciliation({required int generation, required String userId}) async {
    _state.add(
      ProductAnalyticsState(
        preference: state.preference,
        synchronization: const ProductAnalyticsSynchronizationInProgress(),
        availability: const ProductAnalyticsInactive(reason: ProductAnalyticsInactiveReason.preferenceUnknown),
      ),
    );
    final result = await _preferenceRepository.reconcile(userId: userId, local: _local);
    if (!_matches(generation: generation, userId: userId)) return;
    _reconciledGeneration = generation;
    await _applyRepositoryResult(result);
  }

  Future<void> _applyRepositoryResult(ProductAnalyticsPreferenceRepositoryResult result) async {
    switch (result) {
      case ProductAnalyticsPreferenceSynchronized(:final record):
        _volatileDisable = null;
        _currentRecord = record;
        _local = LocalProductAnalyticsSynced(record: record);
        if (record.preference == ProductAnalyticsPreference.enabled && _capability.isEnabled) {
          _state.add(
            ProductAnalyticsState(
              preference: ProductAnalyticsPreferenceKnown(record: record, preference: record.preference),
              synchronization: const ProductAnalyticsSynchronized(),
              availability: ProductAnalyticsActive(userKey: record.userKey),
            ),
          );
          await _reportSchemaReadyIfNeeded();
        } else {
          _emitInactiveForPreference(
            record: record,
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
          record: pending.record,
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
          record: pending.record,
          preference: ProductAnalyticsPreference.disabled,
          synchronization: const ProductAnalyticsDisableRetryRequired(),
          reason: ProductAnalyticsInactiveReason.storageFailure,
        );
      case ProductAnalyticsPreferenceRefreshRequired(:final record):
        _volatileDisable = null;
        _currentRecord = record;
        _local = LocalProductAnalyticsSynced(record: record);
        _emitInactiveForPreference(
          record: record,
          preference: record.preference,
          synchronization: const ProductAnalyticsSynchronizationFailed(),
          reason: null,
        );
      case ProductAnalyticsPreferenceServerConfirmedStorageFailed(:final record):
        _volatileDisable = null;
        _currentRecord = record;
        _emitInactiveForPreference(
          record: record,
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
            record: current,
            preference: current.preference,
            synchronization: const ProductAnalyticsSynchronizationFailed(),
            reason: ProductAnalyticsInactiveReason.storageFailure,
          );
        }
    }
  }

  void _emitInactiveForPreference({
    required ProductAnalyticsPreferenceRecord record,
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
        preference: ProductAnalyticsPreferenceKnown(record: record, preference: preference),
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

  bool _matches({required int generation, required String userId}) => generation == _generation && userId == _userId;

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
