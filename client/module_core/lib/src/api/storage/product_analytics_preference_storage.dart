import "dart:convert";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../foundation/models/product_analytics/product_analytics_preference.dart";

sealed class StoredProductAnalyticsPreference {
  final String userId;
  final int revision;
  final String userKey;

  const StoredProductAnalyticsPreference({required this.userId, required this.revision, required this.userKey});
}

final class StoredProductAnalyticsSynced extends StoredProductAnalyticsPreference {
  final ProductAnalyticsPreference preference;

  const StoredProductAnalyticsSynced({
    required super.userId,
    required super.revision,
    required super.userKey,
    required this.preference,
  });
}

sealed class StoredProductAnalyticsPending extends StoredProductAnalyticsPreference {
  final String operationId;

  const StoredProductAnalyticsPending({
    required super.userId,
    required super.revision,
    required super.userKey,
    required this.operationId,
  });
}

final class StoredProductAnalyticsPendingDisable extends StoredProductAnalyticsPending {
  const StoredProductAnalyticsPendingDisable({
    required super.userId,
    required super.revision,
    required super.userKey,
    required super.operationId,
  });
}

final class StoredProductAnalyticsPendingEnable extends StoredProductAnalyticsPending {
  const StoredProductAnalyticsPendingEnable({
    required super.userId,
    required super.revision,
    required super.userKey,
    required super.operationId,
  });
}

@lazySingleton
class ProductAnalyticsPreferenceStorage {
  static const _storageVersion = 1;
  static const _keyPrefix = "product_analytics_preference_v1:";

  final SecureStorage _storage;

  ProductAnalyticsPreferenceStorage({required SecureStorage storage}) : _storage = storage;

  Future<StoredProductAnalyticsPreference?> read({required String userId}) async {
    final value = await _storage.read(key: _key(userId));
    if (value == null) return null;
    // ignore: no_slop_linter/prefer_specific_type, JSON boundary sanitized below
    final Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      throw const FormatException("Invalid stored product analytics preference");
    }
    // ignore: no_slop_linter/prefer_specific_type, JSON boundary
    if (decoded is! Map<String, dynamic> || decoded["version"] != _storageVersion || decoded["userId"] != userId) {
      throw const FormatException("Invalid stored product analytics preference");
    }
    final revision = decoded["revision"];
    final userKey = decoded["userKey"];
    final kind = decoded["kind"];
    if (revision is! int ||
        revision < 1 ||
        userKey is! String ||
        !isValidProductAnalyticsUserKey(value: userKey) ||
        kind is! String) {
      throw const FormatException("Invalid stored product analytics preference");
    }
    return switch (kind) {
      "synced" => _syncedFromJson(decoded: decoded, userId: userId, revision: revision, userKey: userKey),
      "pending_disable" => StoredProductAnalyticsPendingDisable(
        userId: userId,
        revision: revision,
        userKey: userKey,
        operationId: _operationIdFrom(decoded),
      ),
      "pending_enable" => StoredProductAnalyticsPendingEnable(
        userId: userId,
        revision: revision,
        userKey: userKey,
        operationId: _operationIdFrom(decoded),
      ),
      _ => throw const FormatException("Invalid stored product analytics preference"),
    };
  }

  Future<void> write({required StoredProductAnalyticsPreference record}) {
    final value = switch (record) {
      StoredProductAnalyticsSynced() => {
        "version": _storageVersion,
        "kind": "synced",
        "userId": record.userId,
        "preference": record.preference.wireValue,
        "revision": record.revision,
        "userKey": record.userKey,
      },
      StoredProductAnalyticsPendingDisable() => _pendingJson(record: record, kind: "pending_disable"),
      StoredProductAnalyticsPendingEnable() => _pendingJson(record: record, kind: "pending_enable"),
    };
    return _storage.write(key: _key(record.userId), value: jsonEncode(value));
  }

  Future<void> delete({required String userId}) => _storage.delete(key: _key(userId));

  String _key(String userId) => "$_keyPrefix$userId";
}

StoredProductAnalyticsSynced _syncedFromJson({
  // ignore: no_slop_linter/prefer_specific_type, decoded JSON object
  required Map<String, dynamic> decoded,
  required String userId,
  required int revision,
  required String userKey,
}) {
  final preferenceValue = decoded["preference"];
  final preference = preferenceValue is String
      ? ProductAnalyticsPreference.fromWireValue(value: preferenceValue)
      : null;
  if (preference == null) throw const FormatException("Invalid stored product analytics preference");
  return StoredProductAnalyticsSynced(
    userId: userId,
    preference: preference,
    revision: revision,
    userKey: userKey,
  );
}

// ignore: no_slop_linter/prefer_specific_type, heterogeneous JSON object
Map<String, Object> _pendingJson({required StoredProductAnalyticsPending record, required String kind}) => {
  "version": ProductAnalyticsPreferenceStorage._storageVersion,
  "kind": kind,
  "userId": record.userId,
  "revision": record.revision,
  "userKey": record.userKey,
  "operationId": record.operationId,
};

String _operationIdFrom(
  // ignore: no_slop_linter/prefer_specific_type, decoded JSON object
  Map<String, dynamic> decoded,
) {
  final operationId = decoded["operationId"];
  if (operationId is! String || !_operationIdPattern.hasMatch(operationId)) {
    throw const FormatException("Invalid stored product analytics preference");
  }
  return operationId;
}

final _operationIdPattern = RegExp(
  r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
);
