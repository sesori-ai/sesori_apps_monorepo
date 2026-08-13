import "dart:convert";

import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

const _userKey = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const _operationId = "123e4567-e89b-42d3-a456-426614174000";

class _MemorySecureStorage() implements SecureStorage {
  final values = <String, String>{};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

void main() {
  late _MemorySecureStorage secureStorage;
  late ProductAnalyticsPreferenceStorage storage;

  setUp(() {
    secureStorage = _MemorySecureStorage();
    storage = ProductAnalyticsPreferenceStorage(storage: secureStorage);
  });

  test("round-trips each versioned account-scoped record variant", () async {
    final records = <StoredProductAnalyticsPreference>[
      const StoredProductAnalyticsSynced(
        userId: "user-a",
        revision: 2,
        userKey: _userKey,
        preference: ProductAnalyticsPreference.enabled,
      ),
      const StoredProductAnalyticsPendingDisable(
        userId: "user-a",
        revision: 3,
        userKey: _userKey,
        operationId: _operationId,
      ),
      const StoredProductAnalyticsPendingEnable(
        userId: "user-a",
        revision: 4,
        userKey: _userKey,
        operationId: _operationId,
      ),
    ];

    for (final record in records) {
      await storage.write(record: record);
      final restored = await storage.read(userId: "user-a");

      expect(restored.runtimeType, record.runtimeType);
      expect(restored?.userId, record.userId);
      expect(restored?.revision, record.revision);
      expect(restored?.userKey, record.userKey);
      if (record case StoredProductAnalyticsSynced(:final preference)) {
        expect((restored! as StoredProductAnalyticsSynced).preference, preference);
      }
      if (record case StoredProductAnalyticsPendingDisable(:final operationId)) {
        expect((restored! as StoredProductAnalyticsPendingDisable).operationId, operationId);
      }
      if (record case StoredProductAnalyticsPendingEnable(:final operationId)) {
        expect((restored! as StoredProductAnalyticsPendingEnable).operationId, operationId);
      }
    }

    final encoded = jsonDecode(secureStorage.values.values.single) as Map<String, dynamic>;
    expect(encoded["version"], 1);
    expect(encoded["userId"], "user-a");
    expect(encoded.keys, isNot(contains("rawAccountId")));
  });

  test("records never bleed across account storage keys", () async {
    await storage.write(
      record: const StoredProductAnalyticsSynced(
        userId: "user-a",
        revision: 1,
        userKey: _userKey,
        preference: ProductAnalyticsPreference.disabled,
      ),
    );

    expect(await storage.read(userId: "user-b"), isNull);
    expect(await storage.read(userId: "user-a"), isA<StoredProductAnalyticsSynced>());

    await storage.delete(userId: "user-a");
    expect(await storage.read(userId: "user-a"), isNull);
  });

  test("invalid version, account, key, and operation ID fail closed", () async {
    final invalidPayloads = [
      {"kind": "synced", "userId": "user-a", "preference": "enabled", "revision": 1, "userKey": _userKey},
      {
        "version": null,
        "kind": "synced",
        "userId": "user-a",
        "preference": "enabled",
        "revision": 1,
        "userKey": _userKey,
      },
      {
        "version": 1.5,
        "kind": "synced",
        "userId": "user-a",
        "preference": "enabled",
        "revision": 1,
        "userKey": _userKey,
      },
      {"version": 2, "kind": "synced", "userId": "user-a", "preference": "enabled", "revision": 1, "userKey": _userKey},
      {
        "version": 1,
        "kind": "synced",
        "userId": "user-a",
        "preference": "enabled",
        "revision": 1.5,
        "userKey": _userKey,
      },
      {
        "version": 1,
        "kind": "unknown",
        "userId": "user-a",
        "preference": "enabled",
        "revision": 1,
        "userKey": _userKey,
      },
      {"version": 1, "kind": "synced", "userId": "user-b", "preference": "enabled", "revision": 1, "userKey": _userKey},
      {"version": 1, "kind": "synced", "userId": "user-a", "preference": "enabled", "revision": 1, "userKey": "bad"},
      {
        "version": 1,
        "kind": "pending_disable",
        "userId": "user-a",
        "revision": 1,
        "userKey": _userKey,
        "operationId": "not-a-uuid",
      },
    ];

    for (final payload in invalidPayloads) {
      secureStorage.values["product_analytics_preference_v1:user-a"] = jsonEncode(payload);
      await expectLater(storage.read(userId: "user-a"), throwsFormatException);
    }
  });

  test("malformed JSON errors never retain the stored source", () async {
    const malformed = '{"userId":"raw-user","userKey":"secret-key"';
    secureStorage.values["product_analytics_preference_v1:user-a"] = malformed;

    try {
      await storage.read(userId: "user-a");
      fail("Expected malformed storage to fail closed");
    } on FormatException catch (error) {
      expect(error, isA<ProductAnalyticsPreferenceStorageFormatException>());
      final storageError = error as ProductAnalyticsPreferenceStorageFormatException;
      expect(storageError.innerError, isA<FormatException>());
      expect(storageError.innerStackTrace, isNot(StackTrace.empty));
      expect(error.toString(), isNot(contains("raw-user")));
      expect(error.toString(), isNot(contains("secret-key")));
      expect(error.source, isNull);
    }
  });
}
