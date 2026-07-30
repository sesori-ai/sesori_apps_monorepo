import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/services/models/product_analytics_preference_snapshot.dart";
import "package:test/test.dart";

const _userKey = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const _operationId = "123e4567-e89b-42d3-a456-426614174000";

void main() {
  const synchronizedRecord = ProductAnalyticsPreferenceRecord(
    userId: "user-a",
    preference: ProductAnalyticsPreference.enabled,
    revision: 1,
    userKey: _userKey,
  );
  const pendingDisable = LocalProductAnalyticsPendingDisable(
    userId: "user-a",
    revision: 1,
    userKey: _userKey,
    operationId: _operationId,
  );
  const pendingEnable = LocalProductAnalyticsPendingEnable(
    userId: "user-a",
    revision: 1,
    userKey: _userKey,
    operationId: _operationId,
  );

  test("synchronized snapshot derives one matching local and current record", () {
    const snapshot = ProductAnalyticsPreferenceSynchronizedSnapshot(record: synchronizedRecord);

    expect(snapshot.currentRecord, same(synchronizedRecord));
    expect(snapshot.local, isA<LocalProductAnalyticsSynced>());
    expect(snapshot.local.record, same(synchronizedRecord));
    expect(snapshot.volatileDisable, isNull);
  });

  test("durable pending variants derive their valid disabled baseline", () {
    const disableSnapshot = ProductAnalyticsPreferencePendingDisableSnapshot(pending: pendingDisable);
    const enableSnapshot = ProductAnalyticsPreferencePendingEnableSnapshot(pending: pendingEnable);

    expect(disableSnapshot.local, same(pendingDisable));
    expect(disableSnapshot.currentRecord.preference, ProductAnalyticsPreference.disabled);
    expect(enableSnapshot.local, same(pendingEnable));
    expect(enableSnapshot.currentRecord.preference, ProductAnalyticsPreference.disabled);
  });

  test("volatile disable has a current record but no false durable local record", () {
    const snapshot = ProductAnalyticsPreferenceVolatileDisableSnapshot(pending: pendingDisable);

    expect(snapshot.local, isNull);
    expect(snapshot.currentRecord.userId, pendingDisable.userId);
    expect(snapshot.currentRecord.preference, ProductAnalyticsPreference.disabled);
    expect(snapshot.volatileDisable, same(pendingDisable));
  });

  test("command snapshot clears an obsolete volatile retry while retaining its remote record", () {
    const volatile = ProductAnalyticsPreferenceVolatileDisableSnapshot(pending: pendingDisable);
    final baseline = volatile.commandBaseline;
    final command = ProductAnalyticsPreferenceCommandSnapshot(
      baseline: baseline,
      desiredPreference: ProductAnalyticsPreference.enabled,
    );

    expect(command.local, isNull);
    expect(command.currentRecord?.userId, pendingDisable.userId);
    expect(command.currentRecord?.preference, ProductAnalyticsPreference.disabled);
    expect(command.currentRecord?.revision, pendingDisable.revision);
    expect(command.currentRecord?.userKey, pendingDisable.userKey);
    expect(command.commandBaseline, same(baseline));
    expect(command.volatileDisable, isNull);
    expect(baseline, isA<ProductAnalyticsPreferenceServerConfirmedStorageFailedSnapshot>());
    expect(baseline.local, isNull);
    expect(baseline.volatileDisable, isNull);
  });

  test("command snapshot preserves a storage-read failure from its baseline", () {
    const storageFailure = ProductAnalyticsPreferenceStorageReadFailedSnapshot();
    const command = ProductAnalyticsPreferenceCommandSnapshot(
      baseline: storageFailure,
      desiredPreference: ProductAnalyticsPreference.disabled,
    );

    expect(storageFailure.storageReadFailed, isTrue);
    expect(command.storageReadFailed, isTrue);
  });
}
