import "../../foundation/models/product_analytics/product_analytics_preference.dart";
import "../../repositories/models/product_analytics_preference_models.dart";

sealed class ProductAnalyticsPreferenceSnapshot {
  const ProductAnalyticsPreferenceSnapshot();

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

final class ProductAnalyticsPreferenceUnresolved extends ProductAnalyticsPreferenceSnapshot {
  const ProductAnalyticsPreferenceUnresolved();

  @override
  LocalProductAnalyticsPreference? get local => null;

  @override
  ProductAnalyticsPreferenceRecord? get currentRecord => null;
}

final class ProductAnalyticsPreferenceSynchronizedSnapshot extends ProductAnalyticsPreferenceSnapshot {
  final ProductAnalyticsPreferenceRecord record;

  const ProductAnalyticsPreferenceSynchronizedSnapshot({required this.record});

  @override
  LocalProductAnalyticsPreference get local => LocalProductAnalyticsSynced(record: record);

  @override
  ProductAnalyticsPreferenceRecord get currentRecord => record;
}

sealed class ProductAnalyticsPreferenceDurablePendingSnapshot extends ProductAnalyticsPreferenceSnapshot {
  LocalProductAnalyticsPending get pending;

  const ProductAnalyticsPreferenceDurablePendingSnapshot();

  @override
  LocalProductAnalyticsPreference get local => pending;

  @override
  ProductAnalyticsPreferenceRecord get currentRecord => pending.record;
}

final class ProductAnalyticsPreferencePendingDisableSnapshot extends ProductAnalyticsPreferenceDurablePendingSnapshot {
  @override
  final LocalProductAnalyticsPendingDisable pending;

  const ProductAnalyticsPreferencePendingDisableSnapshot({required this.pending});
}

final class ProductAnalyticsPreferencePendingEnableSnapshot extends ProductAnalyticsPreferenceDurablePendingSnapshot {
  @override
  final LocalProductAnalyticsPendingEnable pending;

  const ProductAnalyticsPreferencePendingEnableSnapshot({required this.pending});
}

final class ProductAnalyticsPreferenceVolatileDisableSnapshot extends ProductAnalyticsPreferenceSnapshot {
  final LocalProductAnalyticsPendingDisable pending;

  const ProductAnalyticsPreferenceVolatileDisableSnapshot({required this.pending});

  @override
  LocalProductAnalyticsPreference? get local => null;

  @override
  ProductAnalyticsPreferenceRecord get currentRecord => pending.record;
}

final class ProductAnalyticsPreferenceStorageReadFailedSnapshot extends ProductAnalyticsPreferenceSnapshot {
  const ProductAnalyticsPreferenceStorageReadFailedSnapshot();

  @override
  LocalProductAnalyticsPreference? get local => null;

  @override
  ProductAnalyticsPreferenceRecord? get currentRecord => null;
}

final class ProductAnalyticsPreferenceCommandSnapshot extends ProductAnalyticsPreferenceSnapshot {
  final ProductAnalyticsPreferenceSnapshot baseline;
  final ProductAnalyticsPreference desiredPreference;

  const ProductAnalyticsPreferenceCommandSnapshot({
    required this.baseline,
    required this.desiredPreference,
  });

  @override
  LocalProductAnalyticsPreference? get local => baseline.local;

  @override
  ProductAnalyticsPreferenceRecord? get currentRecord => baseline.currentRecord;
}

final class ProductAnalyticsPreferenceRefreshRequiredSnapshot extends ProductAnalyticsPreferenceSnapshot {
  final ProductAnalyticsPreferenceRecord record;

  const ProductAnalyticsPreferenceRefreshRequiredSnapshot({required this.record});

  @override
  LocalProductAnalyticsPreference get local => LocalProductAnalyticsSynced(record: record);

  @override
  ProductAnalyticsPreferenceRecord get currentRecord => record;
}

final class ProductAnalyticsPreferenceServerConfirmedStorageFailedSnapshot extends ProductAnalyticsPreferenceSnapshot {
  final ProductAnalyticsPreferenceRecord record;
  final LocalProductAnalyticsPreference? retainedLocal;

  const ProductAnalyticsPreferenceServerConfirmedStorageFailedSnapshot({
    required this.record,
    required this.retainedLocal,
  });

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
