import "../../foundation/models/product_analytics/product_analytics_preference.dart";

sealed class const ProductAnalyticsPreferenceStatus();

final class const ProductAnalyticsPreferenceUnknown() extends ProductAnalyticsPreferenceStatus;

final class const ProductAnalyticsPreferenceKnown({required final ProductAnalyticsPreference preference}) extends ProductAnalyticsPreferenceStatus;

sealed class const ProductAnalyticsSynchronizationStatus();

final class const ProductAnalyticsNotSynchronized() extends ProductAnalyticsSynchronizationStatus;

final class const ProductAnalyticsSynchronizationInProgress() extends ProductAnalyticsSynchronizationStatus;

final class const ProductAnalyticsDisableRequestInProgress() extends ProductAnalyticsSynchronizationStatus;

final class const ProductAnalyticsEnableRequestInProgress() extends ProductAnalyticsSynchronizationStatus;

final class const ProductAnalyticsSynchronized() extends ProductAnalyticsSynchronizationStatus;

final class const ProductAnalyticsDisablePending() extends ProductAnalyticsSynchronizationStatus;

final class const ProductAnalyticsEnablePending() extends ProductAnalyticsSynchronizationStatus;

final class const ProductAnalyticsDisableRetryRequired() extends ProductAnalyticsSynchronizationStatus;

final class const ProductAnalyticsSynchronizationFailed() extends ProductAnalyticsSynchronizationStatus;

enum ProductAnalyticsInactiveReason() {
  unauthenticated,
  postSplashNotReady,
  preferenceUnknown,
  preferenceDisabled,
  synchronizationPending,
  runtimeUnavailable,
  storageFailure,
  requestFailure,
}

sealed class const ProductAnalyticsAvailability();

final class const ProductAnalyticsActive() extends ProductAnalyticsAvailability;

final class const ProductAnalyticsInactive({required final ProductAnalyticsInactiveReason reason}) extends ProductAnalyticsAvailability;

final class const ProductAnalyticsState({
    required final ProductAnalyticsPreferenceStatus preference,
    required final ProductAnalyticsSynchronizationStatus synchronization,
    required final ProductAnalyticsAvailability availability,
  }) {
  static const initial = ProductAnalyticsState(
    preference: ProductAnalyticsPreferenceUnknown(),
    synchronization: ProductAnalyticsNotSynchronized(),
    availability: ProductAnalyticsInactive(reason: ProductAnalyticsInactiveReason.unauthenticated),
  );

  ProductAnalyticsPreference? get displayedPreference => switch (preference) {
    ProductAnalyticsPreferenceUnknown() => null,
    ProductAnalyticsPreferenceKnown(:final preference) => preference,
  };

  bool get isActive => availability is ProductAnalyticsActive;
}
