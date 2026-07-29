import "../../foundation/models/product_analytics/product_analytics_preference.dart";

final class ProductAnalyticsPreferenceRecord {
  final String userId;
  final ProductAnalyticsPreference preference;
  final int revision;
  final String userKey;

  const ProductAnalyticsPreferenceRecord({
    required this.userId,
    required this.preference,
    required this.revision,
    required this.userKey,
  });
}

sealed class LocalProductAnalyticsPreference {
  final ProductAnalyticsPreferenceRecord record;
  const LocalProductAnalyticsPreference({required this.record});
}

final class LocalProductAnalyticsSynced extends LocalProductAnalyticsPreference {
  const LocalProductAnalyticsSynced({required super.record});
}

sealed class LocalProductAnalyticsPending extends LocalProductAnalyticsPreference {
  final String operationId;
  const LocalProductAnalyticsPending({required super.record, required this.operationId});
}

final class LocalProductAnalyticsPendingDisable extends LocalProductAnalyticsPending {
  const LocalProductAnalyticsPendingDisable({required super.record, required super.operationId});
}

final class LocalProductAnalyticsPendingEnable extends LocalProductAnalyticsPending {
  const LocalProductAnalyticsPendingEnable({required super.record, required super.operationId});
}

sealed class ProductAnalyticsPreferenceRepositoryResult {
  const ProductAnalyticsPreferenceRepositoryResult();
}

final class ProductAnalyticsPreferenceSynchronized extends ProductAnalyticsPreferenceRepositoryResult {
  final ProductAnalyticsPreferenceRecord record;
  const ProductAnalyticsPreferenceSynchronized({required this.record});
}

final class ProductAnalyticsPreferencePendingSync extends ProductAnalyticsPreferenceRepositoryResult {
  final LocalProductAnalyticsPending pending;
  const ProductAnalyticsPreferencePendingSync({required this.pending});
}

/// The current process suppresses product events, but neither the local
/// write-ahead record nor the server disable could be confirmed. Unlike a
/// durable pending disable, this state cannot survive a process restart.
final class ProductAnalyticsPreferenceVolatileDisablePending extends ProductAnalyticsPreferenceRepositoryResult {
  final LocalProductAnalyticsPendingDisable pending;

  const ProductAnalyticsPreferenceVolatileDisablePending({required this.pending});
}

final class ProductAnalyticsPreferenceRefreshRequired extends ProductAnalyticsPreferenceRepositoryResult {
  final ProductAnalyticsPreferenceRecord record;
  const ProductAnalyticsPreferenceRefreshRequired({required this.record});
}

final class ProductAnalyticsPreferenceServerConfirmedStorageFailed extends ProductAnalyticsPreferenceRepositoryResult {
  final ProductAnalyticsPreferenceRecord record;
  const ProductAnalyticsPreferenceServerConfirmedStorageFailed({required this.record});
}

final class ProductAnalyticsPreferenceTimedOut extends ProductAnalyticsPreferenceRepositoryResult {
  const ProductAnalyticsPreferenceTimedOut();
}

final class ProductAnalyticsPreferenceFailed extends ProductAnalyticsPreferenceRepositoryResult {
  const ProductAnalyticsPreferenceFailed();
}

final class ProductAnalyticsPreferenceStorageFailed extends ProductAnalyticsPreferenceRepositoryResult {
  const ProductAnalyticsPreferenceStorageFailed();
}
