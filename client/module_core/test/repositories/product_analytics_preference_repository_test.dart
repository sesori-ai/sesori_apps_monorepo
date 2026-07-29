import "dart:collection";

import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

const _userKey = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const _operationId = "123e4567-e89b-42d3-a456-426614174000";

ProductAnalyticsPreferenceApiRecord _apiRecord({
  required ProductAnalyticsPreference preference,
  required int revision,
}) => ProductAnalyticsPreferenceApiRecord(
  preference: preference,
  revision: revision,
  userKey: _userKey,
);

ProductAnalyticsPreferenceRecord _domainRecord({
  ProductAnalyticsPreference preference = ProductAnalyticsPreference.enabled,
  int revision = 1,
}) => ProductAnalyticsPreferenceRecord(
  userId: "user-a",
  preference: preference,
  revision: revision,
  userKey: _userKey,
);

class _RecordingPreferenceApi implements ProductAnalyticsPreferenceApi {
  final List<String> operations;
  final getResults = Queue<ProductAnalyticsPreferenceApiResult>();
  final updateResults = Queue<ProductAnalyticsPreferenceApiResult>();
  final updates = <({String userId, ProductAnalyticsPreference preference, int revision, String operationId})>[];

  _RecordingPreferenceApi({required this.operations});

  @override
  Future<ProductAnalyticsPreferenceApiResult> getPreference({required String userId}) async {
    operations.add("api:get");
    return getResults.removeFirst();
  }

  @override
  Future<ProductAnalyticsPreferenceApiResult> updatePreference({
    required String userId,
    required ProductAnalyticsPreference preference,
    required int expectedRevision,
    required String operationId,
  }) async {
    operations.add("api:put:${preference.wireValue}:$expectedRevision");
    updates.add((
      userId: userId,
      preference: preference,
      revision: expectedRevision,
      operationId: operationId,
    ));
    return updateResults.removeFirst();
  }
}

class _RecordingPreferenceStorage implements ProductAnalyticsPreferenceStorage {
  final List<String> operations;
  final writes = <StoredProductAnalyticsPreference>[];
  StoredProductAnalyticsPreference? stored;
  Object? readError;
  Set<int> failingWriteNumbers = {};

  _RecordingPreferenceStorage({required this.operations});

  @override
  Future<StoredProductAnalyticsPreference?> read({required String userId}) async {
    operations.add("storage:read:$userId");
    final error = readError;
    if (error != null) throw error;
    return stored;
  }

  @override
  Future<void> write({required StoredProductAnalyticsPreference record}) async {
    writes.add(record);
    operations.add("storage:write:${record.runtimeType}");
    if (failingWriteNumbers.contains(writes.length)) throw StateError("storage unavailable");
    stored = record;
  }

  @override
  Future<void> delete({required String userId}) async {
    operations.add("storage:delete:$userId");
    stored = null;
  }
}

void main() {
  late _RecordingPreferenceApi api;
  late _RecordingPreferenceStorage storage;
  late ProductAnalyticsPreferenceRepository repository;
  late List<String> operations;

  setUp(() {
    operations = [];
    api = _RecordingPreferenceApi(operations: operations);
    storage = _RecordingPreferenceStorage(operations: operations);
    repository = ProductAnalyticsPreferenceRepository(api: api, storage: storage);
  });

  test("disable writes durable intent before the server request", () async {
    api.updateResults.add(
      ProductAnalyticsPreferenceApiSuccess(
        record: _apiRecord(preference: ProductAnalyticsPreference.disabled, revision: 2),
      ),
    );

    final result = await repository.setPreference(
      userId: "user-a",
      current: _domainRecord(),
      preference: ProductAnalyticsPreference.disabled,
    );

    expect(result, isA<ProductAnalyticsPreferenceSynchronized>());
    expect(storage.writes.first, isA<StoredProductAnalyticsPendingDisable>());
    expect(storage.writes.last, isA<StoredProductAnalyticsSynced>());
    expect(operations.first, startsWith("storage:write:StoredProductAnalyticsPendingDisable"));
    expect(operations[1], "api:put:disabled:1");
    expect(api.updates.single.userId, "user-a");
    expect(api.updates.single.operationId, matches(RegExp(r"^[0-9a-f-]{36}$")));
  });

  test("malformed local storage is deleted and treated as absent", () async {
    storage.readError = const FormatException("invalid stored preference");

    final result = await repository.loadLocal(userId: "user-a");

    expect(result, isNull);
    expect(operations, ["storage:read:user-a", "storage:delete:user-a"]);
  });

  test("enable never calls the server when its write-ahead record fails", () async {
    storage.failingWriteNumbers = {1};

    final result = await repository.setPreference(
      userId: "user-a",
      current: _domainRecord(preference: ProductAnalyticsPreference.disabled),
      preference: ProductAnalyticsPreference.enabled,
    );

    expect(result, isA<ProductAnalyticsPreferenceStorageFailed>());
    expect(operations.where((operation) => operation.startsWith("api:")), isEmpty);
  });

  test("double-failed disable remains a distinct volatile retry state", () async {
    storage.failingWriteNumbers = {1};
    api.updateResults.add(const ProductAnalyticsPreferenceApiFailure());

    final result = await repository.setPreference(
      userId: "user-a",
      current: _domainRecord(),
      preference: ProductAnalyticsPreference.disabled,
    );

    expect(result, isA<ProductAnalyticsPreferenceVolatileDisablePending>());
    expect(operations, [startsWith("storage:write:"), "api:put:disabled:1"]);
  });

  test("pending enable stays pending when reconciliation cannot reach the server", () async {
    final pending = LocalProductAnalyticsPendingEnable(record: _domainRecord(), operationId: _operationId);
    api.getResults.add(const ProductAnalyticsPreferenceApiTimeout());

    final result = await repository.reconcile(userId: "user-a", local: pending);

    expect(result, isA<ProductAnalyticsPreferencePendingSync>());
    expect((result as ProductAnalyticsPreferencePendingSync).pending, same(pending));
    expect(storage.writes, isEmpty);
  });

  test("pending enable retries its stable operation when the server revision is unchanged", () async {
    final pending = LocalProductAnalyticsPendingEnable(
      record: _domainRecord(preference: ProductAnalyticsPreference.disabled, revision: 7),
      operationId: _operationId,
    );
    api.getResults.add(
      ProductAnalyticsPreferenceApiSuccess(
        record: _apiRecord(preference: ProductAnalyticsPreference.disabled, revision: 7),
      ),
    );
    api.updateResults.add(
      ProductAnalyticsPreferenceApiSuccess(
        record: _apiRecord(preference: ProductAnalyticsPreference.enabled, revision: 8),
      ),
    );

    final result = await repository.reconcile(userId: "user-a", local: pending);

    expect(result, isA<ProductAnalyticsPreferenceSynchronized>());
    expect(api.updates.single, (
      userId: "user-a",
      preference: ProductAnalyticsPreference.enabled,
      revision: 7,
      operationId: _operationId,
    ));
    expect((storage.stored! as StoredProductAnalyticsSynced).preference, ProductAnalyticsPreference.enabled);
  });

  test("a pending disable survives restart and reuses its stable operation id", () async {
    storage.stored = const StoredProductAnalyticsPendingDisable(
      userId: "user-a",
      revision: 4,
      userKey: _userKey,
      operationId: _operationId,
    );
    api.updateResults.add(
      ProductAnalyticsPreferenceApiSuccess(
        record: _apiRecord(preference: ProductAnalyticsPreference.disabled, revision: 5),
      ),
    );

    final restored = await repository.loadLocal(userId: "user-a");
    final result = await repository.reconcile(userId: "user-a", local: restored);

    expect(restored, isA<LocalProductAnalyticsPendingDisable>());
    expect(result, isA<ProductAnalyticsPreferenceSynchronized>());
    expect(api.updates.single.operationId, _operationId);
    expect(api.updates.single.revision, 4);
    expect((storage.stored! as StoredProductAnalyticsSynced).preference, ProductAnalyticsPreference.disabled);
  });

  test("a pending enable restart stays inactive until GET and local finalization succeed", () async {
    storage.stored = const StoredProductAnalyticsPendingEnable(
      userId: "user-a",
      revision: 7,
      userKey: _userKey,
      operationId: _operationId,
    );
    api.getResults.add(
      ProductAnalyticsPreferenceApiSuccess(
        record: _apiRecord(preference: ProductAnalyticsPreference.enabled, revision: 8),
      ),
    );

    final restored = await repository.loadLocal(userId: "user-a");
    final result = await repository.reconcile(userId: "user-a", local: restored);

    expect(restored, isA<LocalProductAnalyticsPendingEnable>());
    expect(result, isA<ProductAnalyticsPreferenceSynchronized>());
    expect((storage.stored! as StoredProductAnalyticsSynced).preference, ProductAnalyticsPreference.enabled);
  });

  test("server success cannot activate enable until synchronized storage finalizes", () async {
    storage.failingWriteNumbers = {2};
    api.updateResults.add(
      ProductAnalyticsPreferenceApiSuccess(
        record: _apiRecord(preference: ProductAnalyticsPreference.enabled, revision: 2),
      ),
    );

    final result = await repository.setPreference(
      userId: "user-a",
      current: _domainRecord(preference: ProductAnalyticsPreference.disabled),
      preference: ProductAnalyticsPreference.enabled,
    );

    expect(result, isA<ProductAnalyticsPreferencePendingSync>());
    expect((result as ProductAnalyticsPreferencePendingSync).pending, isA<LocalProductAnalyticsPendingEnable>());
    expect(storage.stored, isA<StoredProductAnalyticsPendingEnable>());
  });

  test("disable conflict retries once at the returned revision with one stable operation id", () async {
    api.updateResults
      ..add(
        ProductAnalyticsPreferenceApiConflict(
          record: _apiRecord(preference: ProductAnalyticsPreference.enabled, revision: 2),
        ),
      )
      ..add(
        ProductAnalyticsPreferenceApiSuccess(
          record: _apiRecord(preference: ProductAnalyticsPreference.disabled, revision: 3),
        ),
      );

    final result = await repository.setPreference(
      userId: "user-a",
      current: _domainRecord(),
      preference: ProductAnalyticsPreference.disabled,
    );

    expect(result, isA<ProductAnalyticsPreferenceSynchronized>());
    expect(api.updates.map((update) => update.revision), [1, 2]);
    expect(api.updates.first.operationId, api.updates.last.operationId);
    expect(storage.writes.whereType<StoredProductAnalyticsPendingDisable>(), hasLength(2));
  });

  test("enable conflict stays inactive and requires an explicit refresh", () async {
    api.updateResults.add(
      ProductAnalyticsPreferenceApiConflict(
        record: _apiRecord(preference: ProductAnalyticsPreference.disabled, revision: 2),
      ),
    );

    final result = await repository.setPreference(
      userId: "user-a",
      current: _domainRecord(preference: ProductAnalyticsPreference.disabled),
      preference: ProductAnalyticsPreference.enabled,
    );

    expect(result, isA<ProductAnalyticsPreferenceRefreshRequired>());
    expect(api.updates, hasLength(1));
    expect(storage.stored, isA<StoredProductAnalyticsSynced>());
    expect((storage.stored! as StoredProductAnalyticsSynced).preference, ProductAnalyticsPreference.disabled);
  });
}
