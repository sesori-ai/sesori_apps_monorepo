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
  const LocalProductAnalyticsPreference();

  ProductAnalyticsPreferenceRecord get record;
}

final class LocalProductAnalyticsSynced extends LocalProductAnalyticsPreference {
  @override
  final ProductAnalyticsPreferenceRecord record;

  const LocalProductAnalyticsSynced({required this.record});
}

sealed class LocalProductAnalyticsPending extends LocalProductAnalyticsPreference {
  final String userId;
  final int revision;
  final String userKey;
  final String operationId;

  const LocalProductAnalyticsPending({
    required this.userId,
    required this.revision,
    required this.userKey,
    required this.operationId,
  });

  @override
  ProductAnalyticsPreferenceRecord get record => ProductAnalyticsPreferenceRecord(
    userId: userId,
    preference: ProductAnalyticsPreference.disabled,
    revision: revision,
    userKey: userKey,
  );
}

final class LocalProductAnalyticsPendingDisable extends LocalProductAnalyticsPending {
  const LocalProductAnalyticsPendingDisable({
    required super.userId,
    required super.revision,
    required super.userKey,
    required super.operationId,
  });
}

final class LocalProductAnalyticsPendingEnable extends LocalProductAnalyticsPending {
  const LocalProductAnalyticsPendingEnable({
    required super.userId,
    required super.revision,
    required super.userKey,
    required super.operationId,
  });
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
