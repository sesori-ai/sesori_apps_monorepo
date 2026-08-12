import "../../foundation/models/product_analytics/product_analytics_preference.dart";
import "../../repositories/models/product_analytics_preference_models.dart";

sealed class const ProductAnalyticsPreferenceSnapshot() {
  LocalProductAnalyticsPreference? get local;
  ProductAnalyticsPreferenceRecord? get currentRecord;

  ProductAnalyticsPreferenceSnapshot get commandBaseline => switch (this) {
    ProductAnalyticsPreferenceCommandSnapshot(:final baseline) => baseline,
    ProductAnalyticsPreferenceVolatileDisableSnapshot(:final pending) =>
      ProductAnalyticsPreferenceServerConfirmedStorageFailedSnapshot(
        record: pending.record,
        retainedLocal: null,
      ),
    ProductAnalyticsPreferenceUnresolved() ||
    ProductAnalyticsPreferenceSynchronizedSnapshot() ||
    ProductAnalyticsPreferencePendingDisableSnapshot() ||
    ProductAnalyticsPreferencePendingEnableSnapshot() ||
    ProductAnalyticsPreferenceStorageReadFailedSnapshot() ||
    ProductAnalyticsPreferenceRefreshRequiredSnapshot() ||
    ProductAnalyticsPreferenceServerConfirmedStorageFailedSnapshot() => this,
  };

  bool get storageReadFailed => switch (this) {
    ProductAnalyticsPreferenceStorageReadFailedSnapshot() => true,
    ProductAnalyticsPreferenceCommandSnapshot(:final baseline) => baseline.storageReadFailed,
    ProductAnalyticsPreferenceUnresolved() ||
    ProductAnalyticsPreferenceSynchronizedSnapshot() ||
    ProductAnalyticsPreferencePendingDisableSnapshot() ||
    ProductAnalyticsPreferencePendingEnableSnapshot() ||
    ProductAnalyticsPreferenceVolatileDisableSnapshot() ||
    ProductAnalyticsPreferenceRefreshRequiredSnapshot() ||
    ProductAnalyticsPreferenceServerConfirmedStorageFailedSnapshot() => false,
  };

  LocalProductAnalyticsPendingDisable? get volatileDisable => switch (this) {
    ProductAnalyticsPreferenceVolatileDisableSnapshot(:final pending) => pending,
    ProductAnalyticsPreferenceUnresolved() ||
    ProductAnalyticsPreferenceSynchronizedSnapshot() ||
    ProductAnalyticsPreferencePendingDisableSnapshot() ||
    ProductAnalyticsPreferencePendingEnableSnapshot() ||
    ProductAnalyticsPreferenceStorageReadFailedSnapshot() ||
    ProductAnalyticsPreferenceCommandSnapshot() ||
    ProductAnalyticsPreferenceRefreshRequiredSnapshot() ||
    ProductAnalyticsPreferenceServerConfirmedStorageFailedSnapshot() => null,
  };
}

final class const ProductAnalyticsPreferenceUnresolved() extends ProductAnalyticsPreferenceSnapshot {
  @override
  LocalProductAnalyticsPreference? get local => null;

  @override
  ProductAnalyticsPreferenceRecord? get currentRecord => null;
}

final class const ProductAnalyticsPreferenceSynchronizedSnapshot({
  required final ProductAnalyticsPreferenceRecord record,
}) extends ProductAnalyticsPreferenceSnapshot {
  @override
  LocalProductAnalyticsPreference get local => LocalProductAnalyticsSynced(record: record);

  @override
  ProductAnalyticsPreferenceRecord get currentRecord => record;
}

sealed class const ProductAnalyticsPreferenceDurablePendingSnapshot() extends ProductAnalyticsPreferenceSnapshot {
  LocalProductAnalyticsPending get pending;

  @override
  LocalProductAnalyticsPreference get local => pending;

  @override
  ProductAnalyticsPreferenceRecord get currentRecord => pending.record;
}

final class const ProductAnalyticsPreferencePendingDisableSnapshot({
  @override required final LocalProductAnalyticsPendingDisable pending,
}) extends ProductAnalyticsPreferenceDurablePendingSnapshot;

final class const ProductAnalyticsPreferencePendingEnableSnapshot({
  @override required final LocalProductAnalyticsPendingEnable pending,
}) extends ProductAnalyticsPreferenceDurablePendingSnapshot;

final class const ProductAnalyticsPreferenceVolatileDisableSnapshot({
  required final LocalProductAnalyticsPendingDisable pending,
}) extends ProductAnalyticsPreferenceSnapshot {
  @override
  LocalProductAnalyticsPreference? get local => null;

  @override
  ProductAnalyticsPreferenceRecord get currentRecord => pending.record;
}

final class const ProductAnalyticsPreferenceStorageReadFailedSnapshot() extends ProductAnalyticsPreferenceSnapshot {
  @override
  LocalProductAnalyticsPreference? get local => null;

  @override
  ProductAnalyticsPreferenceRecord? get currentRecord => null;
}

final class const ProductAnalyticsPreferenceCommandSnapshot({
  required final ProductAnalyticsPreferenceSnapshot baseline,
  required final ProductAnalyticsPreference desiredPreference,
}) extends ProductAnalyticsPreferenceSnapshot {
  @override
  LocalProductAnalyticsPreference? get local => baseline.local;

  @override
  ProductAnalyticsPreferenceRecord? get currentRecord => baseline.currentRecord;
}

final class const ProductAnalyticsPreferenceRefreshRequiredSnapshot({
  required final ProductAnalyticsPreferenceRecord record,
}) extends ProductAnalyticsPreferenceSnapshot {
  @override
  LocalProductAnalyticsPreference get local => LocalProductAnalyticsSynced(record: record);

  @override
  ProductAnalyticsPreferenceRecord get currentRecord => record;
}

final class const ProductAnalyticsPreferenceServerConfirmedStorageFailedSnapshot({
  required final ProductAnalyticsPreferenceRecord record,
  required final LocalProductAnalyticsPreference? retainedLocal,
}) extends ProductAnalyticsPreferenceSnapshot {
  @override
  LocalProductAnalyticsPreference? get local => retainedLocal;

  @override
  ProductAnalyticsPreferenceRecord get currentRecord => record;
}

ProductAnalyticsPreferenceSnapshot productAnalyticsSnapshotFromLocal({
  required LocalProductAnalyticsPreference? local,
}) => switch (local) {
  null => const ProductAnalyticsPreferenceUnresolved(),
  LocalProductAnalyticsSynced(:final record) => ProductAnalyticsPreferenceSynchronizedSnapshot(record: record),
  LocalProductAnalyticsPendingDisable() => ProductAnalyticsPreferencePendingDisableSnapshot(pending: local),
  LocalProductAnalyticsPendingEnable() => ProductAnalyticsPreferencePendingEnableSnapshot(pending: local),
};
