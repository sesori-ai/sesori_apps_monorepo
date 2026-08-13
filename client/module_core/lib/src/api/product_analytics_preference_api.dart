import "dart:async";
import "dart:convert";

import "package:freezed_annotation/freezed_annotation.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/models/product_analytics/product_analytics_preference.dart";

part "product_analytics_preference_api.freezed.dart";
part "product_analytics_preference_api.g.dart";

const _operationDeadline = Duration(seconds: 10);

@Freezed(fromJson: true, toJson: true)
sealed class ProductAnalyticsPreferenceApiRecord with _$ProductAnalyticsPreferenceApiRecord {
  const factory({
    required ProductAnalyticsPreference preference,
    required int revision,
    required String userKey,
  }) = _ProductAnalyticsPreferenceApiRecord;

  factory fromJson(Map<String, dynamic> json) {
    if (json["revision"] is! int) {
      throw const FormatException("Invalid product analytics preference response");
    }
    final record = _$ProductAnalyticsPreferenceApiRecordFromJson(json);
    if (record.revision < 1 || !isValidProductAnalyticsUserKey(value: record.userKey)) {
      throw const FormatException("Invalid product analytics preference response");
    }
    return record;
  }
}

@Freezed(fromJson: false, toJson: false)
sealed class ProductAnalyticsPreferenceApiResult with _$ProductAnalyticsPreferenceApiResult {
  const factory success({required ProductAnalyticsPreferenceApiRecord record}) = ProductAnalyticsPreferenceApiSuccess;
  const factory conflict({required ProductAnalyticsPreferenceApiRecord record}) = ProductAnalyticsPreferenceApiConflict;
  const factory timeout() = ProductAnalyticsPreferenceApiTimeout;
  const factory failure() = ProductAnalyticsPreferenceApiFailure;
}

@Freezed(fromJson: true, toJson: false)
sealed class const ProductAnalyticsPreferenceConflictResponse._() with _$ProductAnalyticsPreferenceConflictResponse {
  const factory({
    required ProductAnalyticsPreferenceConflictError error,
    required ProductAnalyticsPreference preference,
    required int revision,
    required String userKey,
  }) = _ProductAnalyticsPreferenceConflictResponse;

  factory fromJson(Map<String, dynamic> json) {
    if (json["revision"] is! int) {
      throw const FormatException("Invalid product analytics preference conflict response");
    }
    final response = _$ProductAnalyticsPreferenceConflictResponseFromJson(json);
    if (response.revision < 1 || !isValidProductAnalyticsUserKey(value: response.userKey)) {
      throw const FormatException("Invalid product analytics preference conflict response");
    }
    return response;
  }

  ProductAnalyticsPreferenceApiRecord get record => ProductAnalyticsPreferenceApiRecord(
    preference: preference,
    revision: revision,
    userKey: userKey,
  );
}

@JsonEnum(valueField: "wireValue")
enum ProductAnalyticsPreferenceConflictError({required final String wireValue}) {
  conflict(wireValue: "conflict");
}

@lazySingleton
class ProductAnalyticsPreferenceApi({required final AuthenticatedHttpApiClient _client}) {
  final Uri _url;

  this : _url = Uri.parse("$authBaseUrl/product-analytics/preference");

  Future<ProductAnalyticsPreferenceApiResult> getPreference({required String userId}) async {
    try {
      final response = await _client
          .getForUser<ProductAnalyticsPreferenceApiRecord>(
            url: _url,
            userId: userId,
            fromJson: (dynamic json) => ProductAnalyticsPreferenceApiRecord.fromJson(jsonCastMap(json)),
          )
          .timeout(_operationDeadline);
      return switch (response) {
        SuccessResponse(:final data) => ProductAnalyticsPreferenceApiResult.success(record: data),
        ErrorResponse() => const ProductAnalyticsPreferenceApiResult.failure(),
      };
    } on TimeoutException {
      return const ProductAnalyticsPreferenceApiResult.timeout();
    } on Object {
      return const ProductAnalyticsPreferenceApiResult.failure();
    }
  }

  Future<ProductAnalyticsPreferenceApiResult> updatePreference({
    required String userId,
    required ProductAnalyticsPreference preference,
    required int expectedRevision,
    required String operationId,
  }) async {
    try {
      final response = await _client
          .putForUser<ProductAnalyticsPreferenceApiRecord>(
            url: _url,
            userId: userId,
            fromJson: (dynamic json) => ProductAnalyticsPreferenceApiRecord.fromJson(jsonCastMap(json)),
            body: jsonEncode(
              ProductAnalyticsPreferenceUpdateRequest(
                preference: switch (preference) {
                  ProductAnalyticsPreference.enabled => ProductAnalyticsPreferenceUpdateValue.enabled,
                  ProductAnalyticsPreference.disabled => ProductAnalyticsPreferenceUpdateValue.disabled,
                },
                expectedRevision: expectedRevision,
                operationId: operationId,
              ).toJson(),
            ),
          )
          .timeout(_operationDeadline);
      return switch (response) {
        SuccessResponse(:final data) when data.preference == preference && data.revision > expectedRevision =>
          ProductAnalyticsPreferenceApiResult.success(record: data),
        SuccessResponse() => const ProductAnalyticsPreferenceApiResult.failure(),
        ErrorResponse(error: NonSuccessCodeError(errorCode: 409, :final rawErrorString)) => _conflictFromRawJson(
          rawErrorString,
        ),
        ErrorResponse() => const ProductAnalyticsPreferenceApiResult.failure(),
      };
    } on TimeoutException {
      return const ProductAnalyticsPreferenceApiResult.timeout();
    } on Object {
      return const ProductAnalyticsPreferenceApiResult.failure();
    }
  }

  ProductAnalyticsPreferenceApiResult _conflictFromRawJson(String? value) {
    if (value == null) return const ProductAnalyticsPreferenceApiResult.failure();
    try {
      final response = ProductAnalyticsPreferenceConflictResponse.fromJson(jsonDecodeMap(value));
      return ProductAnalyticsPreferenceApiResult.conflict(record: response.record);
    } on Object {
      return const ProductAnalyticsPreferenceApiResult.failure();
    }
  }
}
