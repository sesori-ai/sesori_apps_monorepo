import "../../foundation/models/product_analytics/product_analytics_preference.dart";
import "../../repositories/models/product_analytics_preference_models.dart";

sealed class ProductAnalyticsPreferenceStatus {
  const ProductAnalyticsPreferenceStatus();
}

final class ProductAnalyticsPreferenceUnknown extends ProductAnalyticsPreferenceStatus {
  const ProductAnalyticsPreferenceUnknown();
}

final class ProductAnalyticsPreferenceKnown extends ProductAnalyticsPreferenceStatus {
  final ProductAnalyticsPreferenceRecord record;
  final ProductAnalyticsPreference preference;

  const ProductAnalyticsPreferenceKnown({required this.record, required this.preference});
}

sealed class ProductAnalyticsSynchronizationStatus {
  const ProductAnalyticsSynchronizationStatus();
}

final class ProductAnalyticsNotSynchronized extends ProductAnalyticsSynchronizationStatus {
  const ProductAnalyticsNotSynchronized();
}

final class ProductAnalyticsSynchronizationInProgress extends ProductAnalyticsSynchronizationStatus {
  const ProductAnalyticsSynchronizationInProgress();
}

final class ProductAnalyticsDisableRequestInProgress extends ProductAnalyticsSynchronizationStatus {
  const ProductAnalyticsDisableRequestInProgress();
}

final class ProductAnalyticsEnableRequestInProgress extends ProductAnalyticsSynchronizationStatus {
  const ProductAnalyticsEnableRequestInProgress();
}

final class ProductAnalyticsSynchronized extends ProductAnalyticsSynchronizationStatus {
  const ProductAnalyticsSynchronized();
}

final class ProductAnalyticsDisablePending extends ProductAnalyticsSynchronizationStatus {
  const ProductAnalyticsDisablePending();
}

final class ProductAnalyticsEnablePending extends ProductAnalyticsSynchronizationStatus {
  const ProductAnalyticsEnablePending();
}

final class ProductAnalyticsDisableRetryRequired extends ProductAnalyticsSynchronizationStatus {
  const ProductAnalyticsDisableRetryRequired();
}

final class ProductAnalyticsSynchronizationFailed extends ProductAnalyticsSynchronizationStatus {
  const ProductAnalyticsSynchronizationFailed();
}

enum ProductAnalyticsInactiveReason {
  unauthenticated,
  postSplashNotReady,
  preferenceUnknown,
  preferenceDisabled,
  synchronizationPending,
  runtimeUnavailable,
  storageFailure,
  requestFailure,
}

sealed class ProductAnalyticsAvailability {
  const ProductAnalyticsAvailability();
}

final class ProductAnalyticsActive extends ProductAnalyticsAvailability {
  final String userKey;
  const ProductAnalyticsActive({required this.userKey});
}

final class ProductAnalyticsInactive extends ProductAnalyticsAvailability {
  final ProductAnalyticsInactiveReason reason;
  const ProductAnalyticsInactive({required this.reason});
}

final class ProductAnalyticsState {
  final ProductAnalyticsPreferenceStatus preference;
  final ProductAnalyticsSynchronizationStatus synchronization;
  final ProductAnalyticsAvailability availability;

  const ProductAnalyticsState({
    required this.preference,
    required this.synchronization,
    required this.availability,
  });

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
