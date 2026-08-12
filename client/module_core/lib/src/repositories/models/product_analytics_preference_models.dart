import "../../foundation/models/product_analytics/product_analytics_preference.dart";

final class const ProductAnalyticsPreferenceRecord({
    required this.userId,
    required this.preference,
    required this.revision,
    required this.userKey,
  }) {
  final String userId;
  final ProductAnalyticsPreference preference;
  final int revision;
  final String userKey;
}

sealed class const LocalProductAnalyticsPreference() {
  ProductAnalyticsPreferenceRecord get record;
}

final class const LocalProductAnalyticsSynced({required this.record}) extends LocalProductAnalyticsPreference {
  @override
  final ProductAnalyticsPreferenceRecord record;
}

sealed class const LocalProductAnalyticsPending({
    required this.userId,
    required this.revision,
    required this.userKey,
    required this.operationId,
  }) extends LocalProductAnalyticsPreference {
  final String userId;
  final int revision;
  final String userKey;
  final String operationId;

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

final class const ProductAnalyticsPreferenceSynchronized({required this.record}) extends ProductAnalyticsPreferenceRepositoryResult {
  final ProductAnalyticsPreferenceRecord record;
}

final class const ProductAnalyticsPreferencePendingSync({required this.pending}) extends ProductAnalyticsPreferenceRepositoryResult {
  final LocalProductAnalyticsPending pending;
}

/// The current process suppresses product events, but neither the local
/// write-ahead record nor the server disable could be confirmed. Unlike a
/// durable pending disable, this state cannot survive a process restart.
final class const ProductAnalyticsPreferenceVolatileDisablePending({required this.pending}) extends ProductAnalyticsPreferenceRepositoryResult {
  final LocalProductAnalyticsPendingDisable pending;
}

final class const ProductAnalyticsPreferenceRefreshRequired({required this.record}) extends ProductAnalyticsPreferenceRepositoryResult {
  final ProductAnalyticsPreferenceRecord record;
}

final class const ProductAnalyticsPreferenceServerConfirmedStorageFailed({required this.record}) extends ProductAnalyticsPreferenceRepositoryResult {
  final ProductAnalyticsPreferenceRecord record;
}

final class const ProductAnalyticsPreferenceTimedOut() extends ProductAnalyticsPreferenceRepositoryResult;

final class const ProductAnalyticsPreferenceFailed() extends ProductAnalyticsPreferenceRepositoryResult;

final class const ProductAnalyticsPreferenceStorageFailed() extends ProductAnalyticsPreferenceRepositoryResult;
