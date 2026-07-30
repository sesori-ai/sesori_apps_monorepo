import "dart:convert";

import "package:freezed_annotation/freezed_annotation.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../../foundation/models/product_analytics/product_analytics_preference.dart";

part "product_analytics_preference_storage.freezed.dart";
part "product_analytics_preference_storage.g.dart";

const _storageVersion = 1;
const _storedPreferenceKindKey = "kind";

@Freezed(
  fromJson: true,
  toJson: true,
  unionKey: _storedPreferenceKindKey,
  unionValueCase: FreezedUnionCase.snake,
)
sealed class StoredProductAnalyticsPreference with _$StoredProductAnalyticsPreference {
  const factory StoredProductAnalyticsPreference.synced({
    required String userId,
    required int revision,
    required String userKey,
    required ProductAnalyticsPreference preference,
  }) = StoredProductAnalyticsSynced;

  const factory StoredProductAnalyticsPreference.pendingDisable({
    required String userId,
    required int revision,
    required String userKey,
    required String operationId,
  }) = StoredProductAnalyticsPendingDisable;

  const factory StoredProductAnalyticsPreference.pendingEnable({
    required String userId,
    required int revision,
    required String userKey,
    required String operationId,
  }) = StoredProductAnalyticsPendingEnable;

  factory StoredProductAnalyticsPreference.fromJson(Map<String, dynamic> json) =>
      _$StoredProductAnalyticsPreferenceFromJson(json);
}

@lazySingleton
class ProductAnalyticsPreferenceStorage {
  static const _keyPrefix = "product_analytics_preference_v1:";

  final SecureStorage _storage;

  ProductAnalyticsPreferenceStorage({required SecureStorage storage}) : _storage = storage;

  Future<StoredProductAnalyticsPreference?> read({required String userId}) async {
    final value = await _storage.read(key: _key(userId));
    if (value == null) return null;
    final StoredProductAnalyticsPreference record;
    try {
      final json = jsonDecodeMap(value);
      final version = json["version"];
      final revision = json["revision"];
      if (version is! int || version != _storageVersion || revision is! int || revision < 1) {
        throw const FormatException("Invalid stored product analytics preference");
      }
      record = StoredProductAnalyticsPreference.fromJson(json);
    } on Object {
      throw const FormatException("Invalid stored product analytics preference");
    }
    if (record.userId != userId ||
        record.revision < 1 ||
        !isValidProductAnalyticsUserKey(value: record.userKey) ||
        !_hasValidOperationId(record)) {
      throw const FormatException("Invalid stored product analytics preference");
    }
    return record;
  }

  Future<void> write({required StoredProductAnalyticsPreference record}) {
    final json = record.toJson()..["version"] = _storageVersion;
    return _storage.write(key: _key(record.userId), value: jsonEncode(json));
  }

  Future<void> delete({required String userId}) => _storage.delete(key: _key(userId));

  String _key(String userId) => "$_keyPrefix$userId";
}

bool _hasValidOperationId(StoredProductAnalyticsPreference record) => switch (record) {
  StoredProductAnalyticsSynced() => true,
  StoredProductAnalyticsPendingDisable(:final operationId) ||
  StoredProductAnalyticsPendingEnable(:final operationId) => _operationIdPattern.hasMatch(operationId),
};

final _operationIdPattern = RegExp(
  r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
);
