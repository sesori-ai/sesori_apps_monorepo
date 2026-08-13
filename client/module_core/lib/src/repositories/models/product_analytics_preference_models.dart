import "../../foundation/models/product_analytics/product_analytics_preference.dart";

final class const ProductAnalyticsPreferenceRecord({
  required final String userId,
  required final ProductAnalyticsPreference preference,
  required final int revision,
  required final String userKey,
});

sealed class const LocalProductAnalyticsPreference() {
  ProductAnalyticsPreferenceRecord get record;
}

final class const LocalProductAnalyticsSynced({@override required final ProductAnalyticsPreferenceRecord record})
    extends LocalProductAnalyticsPreference;

sealed class const LocalProductAnalyticsPending({
  required final String userId,
  required final int revision,
  required final String userKey,
  required final String operationId,
}) extends LocalProductAnalyticsPreference {
  @override
  ProductAnalyticsPreferenceRecord get record => ProductAnalyticsPreferenceRecord(
    userId: userId,
    preference: ProductAnalyticsPreference.disabled,
    revision: revision,
    userKey: userKey,
  );
}

final class const LocalProductAnalyticsPendingDisable({
  required super.userId,
  required super.revision,
  required super.userKey,
  required super.operationId,
}) extends LocalProductAnalyticsPending;

final class const LocalProductAnalyticsPendingEnable({
  required super.userId,
  required super.revision,
  required super.userKey,
  required super.operationId,
}) extends LocalProductAnalyticsPending;

sealed class const ProductAnalyticsPreferenceRepositoryResult();

final class const ProductAnalyticsPreferenceSynchronized({required final ProductAnalyticsPreferenceRecord record})
    extends ProductAnalyticsPreferenceRepositoryResult;

final class const ProductAnalyticsPreferencePendingSync({required final LocalProductAnalyticsPending pending})
    extends ProductAnalyticsPreferenceRepositoryResult;

/// The current process suppresses product events, but neither the local
/// write-ahead record nor the server disable could be confirmed. Unlike a
/// durable pending disable, this state cannot survive a process restart.
final class const ProductAnalyticsPreferenceVolatileDisablePending({
  required final LocalProductAnalyticsPendingDisable pending,
}) extends ProductAnalyticsPreferenceRepositoryResult;

final class const ProductAnalyticsPreferenceRefreshRequired({required final ProductAnalyticsPreferenceRecord record})
    extends ProductAnalyticsPreferenceRepositoryResult;

final class const ProductAnalyticsPreferenceServerConfirmedStorageFailed({
  required final ProductAnalyticsPreferenceRecord record,
}) extends ProductAnalyticsPreferenceRepositoryResult;

final class const ProductAnalyticsPreferenceTimedOut() extends ProductAnalyticsPreferenceRepositoryResult;

final class const ProductAnalyticsPreferenceFailed() extends ProductAnalyticsPreferenceRepositoryResult;

final class const ProductAnalyticsPreferenceStorageFailed() extends ProductAnalyticsPreferenceRepositoryResult;
