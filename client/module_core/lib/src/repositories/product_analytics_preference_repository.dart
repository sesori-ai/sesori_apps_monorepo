import "dart:math";

import "package:injectable/injectable.dart";

import "../api/product_analytics_preference_api.dart";
import "../api/storage/product_analytics_preference_storage.dart";
import "../foundation/models/product_analytics/product_analytics_preference.dart";
import "../logging/logging.dart";
import "models/product_analytics_preference_models.dart";

@lazySingleton
class ProductAnalyticsPreferenceRepository {
  final ProductAnalyticsPreferenceApi _api;
  final ProductAnalyticsPreferenceStorage _storage;

  ProductAnalyticsPreferenceRepository({
    required ProductAnalyticsPreferenceApi api,
    required ProductAnalyticsPreferenceStorage storage,
  }) : _api = api,
       _storage = storage;

  Future<LocalProductAnalyticsPreference?> loadLocal({required String userId}) async {
    final StoredProductAnalyticsPreference? stored;
    try {
      stored = await _storage.read(userId: userId);
    } on FormatException {
      try {
        await _storage.delete(userId: userId);
      } on Object catch (_, deleteStackTrace) {
        logw(
          "Failed to delete malformed local analytics preference",
          const _ProductAnalyticsPreferenceCleanupException(),
          deleteStackTrace,
        );
      }
      throw const FormatException("Invalid stored product analytics preference");
    }
    if (stored == null) return null;
    final record = _recordFromStored(stored);
    return switch (stored) {
      StoredProductAnalyticsSynced() => LocalProductAnalyticsSynced(record: record),
      StoredProductAnalyticsPendingDisable(:final operationId) => LocalProductAnalyticsPendingDisable(
        record: record,
        operationId: operationId,
      ),
      StoredProductAnalyticsPendingEnable(:final operationId) => LocalProductAnalyticsPendingEnable(
        record: record,
        operationId: operationId,
      ),
    };
  }

  Future<ProductAnalyticsPreferenceRepositoryResult> fetch({required String userId}) async {
    final result = await _api.getPreference(userId: userId);
    return switch (result) {
      ProductAnalyticsPreferenceApiSuccess(:final record) => _persistFetchedRecord(
        userId: userId,
        apiRecord: record,
      ),
      ProductAnalyticsPreferenceApiTimeout() => const ProductAnalyticsPreferenceTimedOut(),
      ProductAnalyticsPreferenceApiConflict() ||
      ProductAnalyticsPreferenceApiFailure() => const ProductAnalyticsPreferenceFailed(),
    };
  }

  Future<ProductAnalyticsPreferenceRepositoryResult> reconcile({
    required String userId,
    required LocalProductAnalyticsPreference? local,
  }) {
    if (local != null && local.record.userId != userId) {
      return Future.value(const ProductAnalyticsPreferenceFailed());
    }
    return switch (local) {
      LocalProductAnalyticsPendingDisable() => _putPending(userId: userId, pending: local),
      LocalProductAnalyticsPendingEnable() => _reconcilePendingEnable(userId: userId, pending: local),
      LocalProductAnalyticsSynced() || null => fetch(userId: userId),
    };
  }

  Future<ProductAnalyticsPreferenceRepositoryResult> setPreference({
    required String userId,
    required ProductAnalyticsPreferenceRecord current,
    required ProductAnalyticsPreference preference,
  }) async {
    if (current.userId != userId) return const ProductAnalyticsPreferenceFailed();
    final operationId = _newOperationId();
    final pending = switch (preference) {
      ProductAnalyticsPreference.disabled => LocalProductAnalyticsPendingDisable(
        record: current,
        operationId: operationId,
      ),
      ProductAnalyticsPreference.enabled => LocalProductAnalyticsPendingEnable(
        record: current,
        operationId: operationId,
      ),
    };

    var pendingPersisted = false;
    try {
      await _writePending(pending);
      pendingPersisted = true;
    } on Object catch (error, stackTrace) {
      if (preference == ProductAnalyticsPreference.enabled) {
        return const ProductAnalyticsPreferenceStorageFailed();
      }
      logw("Failed to persist analytics disable intent; continuing with server suppression", error, stackTrace);
    }

    return _putPending(userId: userId, pending: pending, pendingPersisted: pendingPersisted);
  }

  Future<ProductAnalyticsPreferenceRepositoryResult> _reconcilePendingEnable({
    required String userId,
    required LocalProductAnalyticsPendingEnable pending,
  }) async {
    final result = await _api.getPreference(userId: userId);
    return switch (result) {
      ProductAnalyticsPreferenceApiSuccess(:final record)
          when record.preference == ProductAnalyticsPreference.disabled =>
        _refreshPendingEnableAndRetry(userId: userId, pending: pending, apiRecord: record),
      ProductAnalyticsPreferenceApiSuccess(:final record) => _persistPendingRecord(
        userId: userId,
        apiRecord: record,
        pending: pending,
      ),
      ProductAnalyticsPreferenceApiTimeout() ||
      ProductAnalyticsPreferenceApiConflict() ||
      ProductAnalyticsPreferenceApiFailure() => ProductAnalyticsPreferencePendingSync(pending: pending),
    };
  }

  Future<ProductAnalyticsPreferenceRepositoryResult> _refreshPendingEnableAndRetry({
    required String userId,
    required LocalProductAnalyticsPendingEnable pending,
    required ProductAnalyticsPreferenceApiRecord apiRecord,
  }) async {
    final refreshedPending = LocalProductAnalyticsPendingEnable(
      record: _recordFromApi(userId: userId, record: apiRecord),
      operationId: pending.operationId,
    );
    if (apiRecord.revision != pending.record.revision) {
      try {
        await _writePending(refreshedPending);
      } on Object {
        return const ProductAnalyticsPreferenceStorageFailed();
      }
    }
    return _putPending(userId: userId, pending: refreshedPending);
  }

  Future<ProductAnalyticsPreferenceRepositoryResult> _putPending({
    required String userId,
    required LocalProductAnalyticsPending pending,
    bool pendingPersisted = true,
  }) async {
    if (pending.record.userId != userId) return const ProductAnalyticsPreferenceFailed();
    final desired = pending is LocalProductAnalyticsPendingDisable
        ? ProductAnalyticsPreference.disabled
        : ProductAnalyticsPreference.enabled;
    final result = await _api.updatePreference(
      userId: userId,
      preference: desired,
      expectedRevision: pending.record.revision,
      operationId: pending.operationId,
    );
    return switch (result) {
      ProductAnalyticsPreferenceApiSuccess(:final record) => _persistResultForPending(
        userId: userId,
        apiRecord: record,
        pending: pending,
        pendingPersisted: pendingPersisted,
      ),
      ProductAnalyticsPreferenceApiConflict(:final record) => switch (pending) {
        LocalProductAnalyticsPendingDisable() => _retryDisableAfterConflict(
          userId: userId,
          operationId: pending.operationId,
          conflictRecord: record,
          hasDurablePending: pendingPersisted,
        ),
        LocalProductAnalyticsPendingEnable() => _persistRefreshRequired(
          userId: userId,
          apiRecord: record,
          pending: pending,
        ),
      },
      ProductAnalyticsPreferenceApiTimeout() || ProductAnalyticsPreferenceApiFailure() => _pendingAfterRequestFailure(
        pending: pending,
        pendingPersisted: pendingPersisted,
      ),
    };
  }

  Future<ProductAnalyticsPreferenceRepositoryResult> _retryDisableAfterConflict({
    required String userId,
    required String operationId,
    required ProductAnalyticsPreferenceApiRecord conflictRecord,
    required bool hasDurablePending,
  }) async {
    var durablePending = hasDurablePending;
    if (conflictRecord.preference == ProductAnalyticsPreference.disabled) {
      final pending = LocalProductAnalyticsPendingDisable(
        record: _recordFromApi(userId: userId, record: conflictRecord),
        operationId: operationId,
      );
      return _persistResultForPending(
        userId: userId,
        apiRecord: conflictRecord,
        pending: pending,
        pendingPersisted: durablePending,
      );
    }
    final conflictDomainRecord = _recordFromApi(userId: userId, record: conflictRecord);
    final pending = LocalProductAnalyticsPendingDisable(record: conflictDomainRecord, operationId: operationId);
    try {
      await _writePending(pending);
      durablePending = true;
    } on Object catch (_, stackTrace) {
      logw(
        "Failed to persist refreshed analytics disable intent",
        const _ProductAnalyticsPreferenceCleanupException(),
        stackTrace,
      );
      // Source suppression is already active in memory. Continue the bounded
      // server disable even if refreshing the durable retry record fails.
    }
    final retry = await _api.updatePreference(
      userId: userId,
      preference: ProductAnalyticsPreference.disabled,
      expectedRevision: conflictRecord.revision,
      operationId: operationId,
    );
    switch (retry) {
      case ProductAnalyticsPreferenceApiSuccess(:final record):
        return _persistResultForPending(
          userId: userId,
          apiRecord: record,
          pending: pending,
          pendingPersisted: durablePending,
        );
      case ProductAnalyticsPreferenceApiConflict(:final record)
          when record.preference == ProductAnalyticsPreference.disabled:
        return _persistResultForPending(
          userId: userId,
          apiRecord: record,
          pending: pending,
          pendingPersisted: durablePending,
        );
      case ProductAnalyticsPreferenceApiTimeout() ||
          ProductAnalyticsPreferenceApiFailure() ||
          ProductAnalyticsPreferenceApiConflict():
        return _pendingAfterRequestFailure(
          pending: pending,
          pendingPersisted: durablePending,
        );
    }
  }

  Future<ProductAnalyticsPreferenceRepositoryResult> _persistFetchedRecord({
    required String userId,
    required ProductAnalyticsPreferenceApiRecord apiRecord,
  }) async {
    final record = _recordFromApi(userId: userId, record: apiRecord);
    try {
      await _storage.write(
        record: StoredProductAnalyticsSynced(
          userId: userId,
          preference: record.preference,
          revision: record.revision,
          userKey: record.userKey,
        ),
      );
      return ProductAnalyticsPreferenceSynchronized(record: record);
    } on Object {
      return ProductAnalyticsPreferenceServerConfirmedStorageFailed(record: record);
    }
  }

  Future<ProductAnalyticsPreferenceRepositoryResult> _persistPendingRecord({
    required String userId,
    required ProductAnalyticsPreferenceApiRecord apiRecord,
    required LocalProductAnalyticsPending pending,
  }) async {
    final record = _recordFromApi(userId: userId, record: apiRecord);
    try {
      await _storage.write(
        record: StoredProductAnalyticsSynced(
          userId: userId,
          preference: record.preference,
          revision: record.revision,
          userKey: record.userKey,
        ),
      );
      return ProductAnalyticsPreferenceSynchronized(record: record);
    } on Object {
      // The write-ahead record remains recoverable. Keep reporting inactive
      // until a later reconciliation can finalize synchronized storage.
      return ProductAnalyticsPreferencePendingSync(pending: pending);
    }
  }

  Future<ProductAnalyticsPreferenceRepositoryResult> _persistResultForPending({
    required String userId,
    required ProductAnalyticsPreferenceApiRecord apiRecord,
    required LocalProductAnalyticsPending pending,
    required bool pendingPersisted,
  }) {
    return pendingPersisted
        ? _persistPendingRecord(userId: userId, apiRecord: apiRecord, pending: pending)
        : _persistFetchedRecord(userId: userId, apiRecord: apiRecord);
  }

  Future<ProductAnalyticsPreferenceRepositoryResult> _persistRefreshRequired({
    required String userId,
    required ProductAnalyticsPreferenceApiRecord apiRecord,
    required LocalProductAnalyticsPendingEnable pending,
  }) async {
    final result = await _persistPendingRecord(userId: userId, apiRecord: apiRecord, pending: pending);
    return switch (result) {
      ProductAnalyticsPreferenceSynchronized(:final record) => ProductAnalyticsPreferenceRefreshRequired(
        record: record,
      ),
      ProductAnalyticsPreferencePendingSync() => result,
      ProductAnalyticsPreferenceRefreshRequired() ||
      ProductAnalyticsPreferenceServerConfirmedStorageFailed() ||
      ProductAnalyticsPreferenceTimedOut() ||
      ProductAnalyticsPreferenceFailed() ||
      ProductAnalyticsPreferenceStorageFailed() ||
      ProductAnalyticsPreferenceVolatileDisablePending() => const ProductAnalyticsPreferenceFailed(),
    };
  }

  ProductAnalyticsPreferenceRepositoryResult _pendingAfterRequestFailure({
    required LocalProductAnalyticsPending pending,
    required bool pendingPersisted,
  }) {
    if (pendingPersisted) return ProductAnalyticsPreferencePendingSync(pending: pending);
    return switch (pending) {
      LocalProductAnalyticsPendingDisable() => ProductAnalyticsPreferenceVolatileDisablePending(pending: pending),
      LocalProductAnalyticsPendingEnable() => const ProductAnalyticsPreferenceStorageFailed(),
    };
  }

  Future<void> _writePending(LocalProductAnalyticsPending pending) {
    final stored = switch (pending) {
      LocalProductAnalyticsPendingDisable() => StoredProductAnalyticsPendingDisable(
        userId: pending.record.userId,
        revision: pending.record.revision,
        userKey: pending.record.userKey,
        operationId: pending.operationId,
      ),
      LocalProductAnalyticsPendingEnable() => StoredProductAnalyticsPendingEnable(
        userId: pending.record.userId,
        revision: pending.record.revision,
        userKey: pending.record.userKey,
        operationId: pending.operationId,
      ),
    };
    return _storage.write(record: stored);
  }
}

final class _ProductAnalyticsPreferenceCleanupException implements Exception {
  const _ProductAnalyticsPreferenceCleanupException();

  @override
  String toString() => "Product analytics preference cleanup failed";
}

ProductAnalyticsPreferenceRecord _recordFromStored(StoredProductAnalyticsPreference stored) =>
    ProductAnalyticsPreferenceRecord(
      userId: stored.userId,
      preference: switch (stored) {
        StoredProductAnalyticsSynced(:final preference) => preference,
        StoredProductAnalyticsPendingDisable() => ProductAnalyticsPreference.disabled,
        StoredProductAnalyticsPendingEnable() => ProductAnalyticsPreference.disabled,
      },
      revision: stored.revision,
      userKey: stored.userKey,
    );

ProductAnalyticsPreferenceRecord _recordFromApi({
  required String userId,
  required ProductAnalyticsPreferenceApiRecord record,
}) => ProductAnalyticsPreferenceRecord(
  userId: userId,
  preference: record.preference,
  revision: record.revision,
  userKey: record.userKey,
);

String _newOperationId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, "0")).join();
  return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-"
      "${hex.substring(16, 20)}-${hex.substring(20)}";
}
