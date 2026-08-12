import "../foundation/models/product_analytics/analytics_runtime_capability.dart";
import "../foundation/models/product_analytics/product_analytics_preference.dart";
import "../repositories/models/product_analytics_preference_models.dart";
import "models/product_analytics_preference_snapshot.dart";
import "models/product_analytics_state.dart";

enum _ProductAnalyticsActivationPolicy() { inactive, authoritativeSynchronization }

final class const ProductAnalyticsPreferenceTransition({required final ProductAnalyticsPreferenceSnapshot snapshot, required final ProductAnalyticsState state});

final class const ProductAnalyticsPreferenceStateMapper({required final AnalyticsRuntimeCapability _capability}) {

  ProductAnalyticsState fromLocal({
    required ProductAnalyticsPreferenceSnapshot snapshot,
    required bool postSplashReady,
  }) => switch (snapshot) {
    ProductAnalyticsPreferenceUnresolved() => ProductAnalyticsState(
      preference: const ProductAnalyticsPreferenceUnknown(),
      synchronization: const ProductAnalyticsNotSynchronized(),
      availability: ProductAnalyticsInactive(
        reason: postSplashReady
            ? ProductAnalyticsInactiveReason.preferenceUnknown
            : ProductAnalyticsInactiveReason.postSplashNotReady,
      ),
    ),
    ProductAnalyticsPreferenceSynchronizedSnapshot(:final record) => _known(
      preference: record.preference,
      synchronization: const ProductAnalyticsSynchronized(),
      explicitReason: null,
      postSplashReady: postSplashReady,
      activationPolicy: _ProductAnalyticsActivationPolicy.inactive,
    ),
    ProductAnalyticsPreferencePendingDisableSnapshot() => _known(
      preference: ProductAnalyticsPreference.disabled,
      synchronization: const ProductAnalyticsDisablePending(),
      explicitReason: null,
      postSplashReady: postSplashReady,
      activationPolicy: _ProductAnalyticsActivationPolicy.inactive,
    ),
    ProductAnalyticsPreferencePendingEnableSnapshot() => _known(
      preference: ProductAnalyticsPreference.enabled,
      synchronization: const ProductAnalyticsEnablePending(),
      explicitReason: null,
      postSplashReady: postSplashReady,
      activationPolicy: _ProductAnalyticsActivationPolicy.inactive,
    ),
    ProductAnalyticsPreferenceVolatileDisableSnapshot() => _known(
      preference: ProductAnalyticsPreference.disabled,
      synchronization: const ProductAnalyticsDisableRetryRequired(),
      explicitReason: ProductAnalyticsInactiveReason.storageFailure,
      postSplashReady: postSplashReady,
      activationPolicy: _ProductAnalyticsActivationPolicy.inactive,
    ),
    ProductAnalyticsPreferenceStorageReadFailedSnapshot() => const ProductAnalyticsState(
      preference: ProductAnalyticsPreferenceUnknown(),
      synchronization: ProductAnalyticsSynchronizationFailed(),
      availability: ProductAnalyticsInactive(reason: ProductAnalyticsInactiveReason.storageFailure),
    ),
    ProductAnalyticsPreferenceCommandSnapshot(:final desiredPreference) => requestInProgress(
      preference: desiredPreference,
      postSplashReady: postSplashReady,
    ),
    ProductAnalyticsPreferenceRefreshRequiredSnapshot(:final record) => _known(
      preference: record.preference,
      synchronization: const ProductAnalyticsSynchronizationFailed(),
      explicitReason: null,
      postSplashReady: postSplashReady,
      activationPolicy: _ProductAnalyticsActivationPolicy.inactive,
    ),
    ProductAnalyticsPreferenceServerConfirmedStorageFailedSnapshot(:final record) => _known(
      preference: record.preference,
      synchronization: const ProductAnalyticsSynchronizationFailed(),
      explicitReason: ProductAnalyticsInactiveReason.storageFailure,
      postSplashReady: postSplashReady,
      activationPolicy: _ProductAnalyticsActivationPolicy.inactive,
    ),
  };

  ProductAnalyticsState reconciliationInProgress({required ProductAnalyticsState current}) => ProductAnalyticsState(
    preference: current.preference,
    synchronization: const ProductAnalyticsSynchronizationInProgress(),
    availability: const ProductAnalyticsInactive(reason: ProductAnalyticsInactiveReason.preferenceUnknown),
  );

  ProductAnalyticsState requestInProgress({
    required ProductAnalyticsPreference preference,
    required bool postSplashReady,
  }) => _known(
    preference: preference,
    synchronization: preference == ProductAnalyticsPreference.disabled
        ? const ProductAnalyticsDisableRequestInProgress()
        : const ProductAnalyticsEnableRequestInProgress(),
    explicitReason: null,
    postSplashReady: postSplashReady,
    activationPolicy: _ProductAnalyticsActivationPolicy.inactive,
  );

  ProductAnalyticsPreferenceTransition fromRepositoryResult({
    required ProductAnalyticsPreferenceRepositoryResult result,
    required ProductAnalyticsPreferenceSnapshot currentSnapshot,
    required ProductAnalyticsState currentState,
    required ProductAnalyticsPreference? pendingPreference,
    required bool postSplashReady,
    required bool suppressForLogout,
  }) {
    final transition = switch (result) {
      ProductAnalyticsPreferenceSynchronized(:final record) => _forSnapshot(
        snapshot: ProductAnalyticsPreferenceSynchronizedSnapshot(record: record),
        preference: record.preference,
        synchronization: const ProductAnalyticsSynchronized(),
        explicitReason: null,
        pendingPreference: pendingPreference,
        postSplashReady: postSplashReady,
        suppressForLogout: suppressForLogout,
        activationPolicy: _ProductAnalyticsActivationPolicy.authoritativeSynchronization,
      ),
      ProductAnalyticsPreferencePendingSync(:final pending) => switch (pending) {
        LocalProductAnalyticsPendingDisable() => _forSnapshot(
          snapshot: ProductAnalyticsPreferencePendingDisableSnapshot(pending: pending),
          preference: ProductAnalyticsPreference.disabled,
          synchronization: const ProductAnalyticsDisablePending(),
          explicitReason: null,
          pendingPreference: null,
          postSplashReady: postSplashReady,
          suppressForLogout: suppressForLogout,
          activationPolicy: _ProductAnalyticsActivationPolicy.inactive,
        ),
        LocalProductAnalyticsPendingEnable() => _forSnapshot(
          snapshot: ProductAnalyticsPreferencePendingEnableSnapshot(pending: pending),
          preference: ProductAnalyticsPreference.enabled,
          synchronization: const ProductAnalyticsEnablePending(),
          explicitReason: null,
          pendingPreference: null,
          postSplashReady: postSplashReady,
          suppressForLogout: suppressForLogout,
          activationPolicy: _ProductAnalyticsActivationPolicy.inactive,
        ),
      },
      ProductAnalyticsPreferenceVolatileDisablePending(:final pending) => _volatile(
        pending: pending,
        pendingPreference: pendingPreference,
        postSplashReady: postSplashReady,
        suppressForLogout: suppressForLogout,
      ),
      ProductAnalyticsPreferenceRefreshRequired(:final record) => _forSnapshot(
        snapshot: ProductAnalyticsPreferenceRefreshRequiredSnapshot(record: record),
        preference: record.preference,
        synchronization: const ProductAnalyticsSynchronizationFailed(),
        explicitReason: null,
        pendingPreference: null,
        postSplashReady: postSplashReady,
        suppressForLogout: suppressForLogout,
        activationPolicy: _ProductAnalyticsActivationPolicy.inactive,
      ),
      ProductAnalyticsPreferenceServerConfirmedStorageFailed(:final record) => _forSnapshot(
        snapshot: ProductAnalyticsPreferenceServerConfirmedStorageFailedSnapshot(
          record: record,
          retainedLocal: currentSnapshot.local,
        ),
        preference: record.preference,
        synchronization: const ProductAnalyticsSynchronizationFailed(),
        explicitReason: ProductAnalyticsInactiveReason.storageFailure,
        pendingPreference: null,
        postSplashReady: postSplashReady,
        suppressForLogout: suppressForLogout,
        activationPolicy: _ProductAnalyticsActivationPolicy.inactive,
      ),
      ProductAnalyticsPreferenceTimedOut() ||
      ProductAnalyticsPreferenceFailed() => ProductAnalyticsPreferenceTransition(
        snapshot: currentSnapshot.commandBaseline,
        state: suppressForLogout
            ? currentState
            : ProductAnalyticsState(
                preference: currentState.preference,
                synchronization: const ProductAnalyticsSynchronizationFailed(),
                availability: const ProductAnalyticsInactive(reason: ProductAnalyticsInactiveReason.requestFailure),
              ),
      ),
      ProductAnalyticsPreferenceStorageFailed() => _storageFailure(
        snapshot: currentSnapshot.commandBaseline,
        currentState: currentState,
        postSplashReady: postSplashReady,
        suppressForLogout: suppressForLogout,
      ),
    };
    return transition;
  }

  ProductAnalyticsPreferenceTransition _volatile({
    required LocalProductAnalyticsPendingDisable pending,
    required ProductAnalyticsPreference? pendingPreference,
    required bool postSplashReady,
    required bool suppressForLogout,
  }) {
    final volatile = ProductAnalyticsPreferenceVolatileDisableSnapshot(pending: pending);
    final enabling = pendingPreference == ProductAnalyticsPreference.enabled;
    return _forSnapshot(
      snapshot: enabling
          ? ProductAnalyticsPreferenceCommandSnapshot(
              baseline: volatile.commandBaseline,
              desiredPreference: ProductAnalyticsPreference.enabled,
            )
          : volatile,
      preference: enabling ? ProductAnalyticsPreference.enabled : ProductAnalyticsPreference.disabled,
      synchronization: enabling
          ? const ProductAnalyticsEnableRequestInProgress()
          : const ProductAnalyticsDisableRetryRequired(),
      explicitReason: enabling ? null : ProductAnalyticsInactiveReason.storageFailure,
      pendingPreference: null,
      postSplashReady: postSplashReady,
      suppressForLogout: suppressForLogout,
      activationPolicy: _ProductAnalyticsActivationPolicy.inactive,
    );
  }

  ProductAnalyticsPreferenceTransition _storageFailure({
    required ProductAnalyticsPreferenceSnapshot snapshot,
    required ProductAnalyticsState currentState,
    required bool postSplashReady,
    required bool suppressForLogout,
  }) {
    if (suppressForLogout) return ProductAnalyticsPreferenceTransition(snapshot: snapshot, state: currentState);
    final current = snapshot.currentRecord;
    return ProductAnalyticsPreferenceTransition(
      snapshot: snapshot,
      state: current == null
          ? const ProductAnalyticsState(
              preference: ProductAnalyticsPreferenceUnknown(),
              synchronization: ProductAnalyticsSynchronizationFailed(),
              availability: ProductAnalyticsInactive(reason: ProductAnalyticsInactiveReason.storageFailure),
            )
          : _known(
              preference: current.preference,
              synchronization: const ProductAnalyticsSynchronizationFailed(),
              explicitReason: ProductAnalyticsInactiveReason.storageFailure,
              postSplashReady: postSplashReady,
              activationPolicy: _ProductAnalyticsActivationPolicy.inactive,
            ),
    );
  }

  ProductAnalyticsPreferenceTransition _forSnapshot({
    required ProductAnalyticsPreferenceSnapshot snapshot,
    required ProductAnalyticsPreference preference,
    required ProductAnalyticsSynchronizationStatus synchronization,
    required ProductAnalyticsInactiveReason? explicitReason,
    required ProductAnalyticsPreference? pendingPreference,
    required bool postSplashReady,
    required bool suppressForLogout,
    required _ProductAnalyticsActivationPolicy activationPolicy,
  }) => ProductAnalyticsPreferenceTransition(
    snapshot: snapshot,
    state: suppressForLogout
        ? ProductAnalyticsState(
            preference: ProductAnalyticsPreferenceKnown(preference: preference),
            synchronization: synchronization,
            availability: const ProductAnalyticsInactive(reason: ProductAnalyticsInactiveReason.unauthenticated),
          )
        : pendingPreference != null
        ? requestInProgress(preference: pendingPreference, postSplashReady: postSplashReady)
        : _known(
            preference: preference,
            synchronization: synchronization,
            explicitReason: explicitReason,
            postSplashReady: postSplashReady,
            activationPolicy: activationPolicy,
          ),
  );

  ProductAnalyticsState _known({
    required ProductAnalyticsPreference preference,
    required ProductAnalyticsSynchronizationStatus synchronization,
    required ProductAnalyticsInactiveReason? explicitReason,
    required bool postSplashReady,
    required _ProductAnalyticsActivationPolicy activationPolicy,
  }) {
    if (activationPolicy == _ProductAnalyticsActivationPolicy.authoritativeSynchronization &&
        synchronization is ProductAnalyticsSynchronized &&
        preference == ProductAnalyticsPreference.enabled &&
        _capability.isEnabled &&
        postSplashReady &&
        explicitReason == null) {
      return ProductAnalyticsState(
        preference: ProductAnalyticsPreferenceKnown(preference: preference),
        synchronization: synchronization,
        availability: const ProductAnalyticsActive(),
      );
    }

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
    final reason =
        explicitReason ??
        (synchronizationPending
            ? ProductAnalyticsInactiveReason.synchronizationPending
            : preference == ProductAnalyticsPreference.disabled
            ? ProductAnalyticsInactiveReason.preferenceDisabled
            : !_capability.isEnabled
            ? ProductAnalyticsInactiveReason.runtimeUnavailable
            : postSplashReady
            ? ProductAnalyticsInactiveReason.preferenceUnknown
            : ProductAnalyticsInactiveReason.postSplashNotReady);
    return ProductAnalyticsState(
      preference: ProductAnalyticsPreferenceKnown(preference: preference),
      synchronization: synchronization,
      availability: ProductAnalyticsInactive(reason: reason),
    );
  }
}
