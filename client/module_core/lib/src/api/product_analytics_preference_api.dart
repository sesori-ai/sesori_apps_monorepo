import "dart:async";
import "dart:convert";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/models/product_analytics/product_analytics_preference.dart";

const _operationDeadline = Duration(seconds: 10);

final class ProductAnalyticsPreferenceApiRecord {
  final ProductAnalyticsPreference preference;
  final int revision;
  final String userKey;

  const ProductAnalyticsPreferenceApiRecord({
    required this.preference,
    required this.revision,
    required this.userKey,
  });
}

sealed class ProductAnalyticsPreferenceApiResult {
  const ProductAnalyticsPreferenceApiResult();
}

final class ProductAnalyticsPreferenceApiSuccess extends ProductAnalyticsPreferenceApiResult {
  final ProductAnalyticsPreferenceApiRecord record;
  const ProductAnalyticsPreferenceApiSuccess({required this.record});
}

final class ProductAnalyticsPreferenceApiConflict extends ProductAnalyticsPreferenceApiResult {
  final ProductAnalyticsPreferenceApiRecord record;
  const ProductAnalyticsPreferenceApiConflict({required this.record});
}

final class ProductAnalyticsPreferenceApiTimeout extends ProductAnalyticsPreferenceApiResult {
  const ProductAnalyticsPreferenceApiTimeout();
}

final class ProductAnalyticsPreferenceApiFailure extends ProductAnalyticsPreferenceApiResult {
  const ProductAnalyticsPreferenceApiFailure();
}

@lazySingleton
class ProductAnalyticsPreferenceApi {
  final AuthenticatedHttpApiClient _client;
  final Uri _url;

  ProductAnalyticsPreferenceApi({required AuthenticatedHttpApiClient client})
    : _client = client,
      _url = Uri.parse("$authBaseUrl/product-analytics/preference");

  Future<ProductAnalyticsPreferenceApiResult> getPreference({required String userId}) async {
    try {
      final response = await _client
          .getForUser<ProductAnalyticsPreferenceApiRecord>(
            url: _url,
            userId: userId,
            fromJson: _recordFromJson,
          )
          .timeout(_operationDeadline);
      return switch (response) {
        SuccessResponse(:final data) => ProductAnalyticsPreferenceApiSuccess(record: data),
        ErrorResponse() => const ProductAnalyticsPreferenceApiFailure(),
      };
    } on TimeoutException {
      return const ProductAnalyticsPreferenceApiTimeout();
    } on Object {
      return const ProductAnalyticsPreferenceApiFailure();
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
            fromJson: _recordFromJson,
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
        SuccessResponse(:final data) => ProductAnalyticsPreferenceApiSuccess(record: data),
        ErrorResponse(error: NonSuccessCodeError(errorCode: 409, :final rawErrorString)) => _conflictFromRawJson(
          rawErrorString,
        ),
        ErrorResponse() => const ProductAnalyticsPreferenceApiFailure(),
      };
    } on TimeoutException {
      return const ProductAnalyticsPreferenceApiTimeout();
    } on Object {
      return const ProductAnalyticsPreferenceApiFailure();
    }
  }

  ProductAnalyticsPreferenceApiResult _conflictFromRawJson(String? value) {
    if (value == null) return const ProductAnalyticsPreferenceApiFailure();
    try {
      final decoded = jsonDecode(value);
      // ignore: no_slop_linter/prefer_specific_type, JSON boundary
      if (decoded is! Map<String, dynamic> || decoded["error"] != "conflict") {
        return const ProductAnalyticsPreferenceApiFailure();
      }
      return ProductAnalyticsPreferenceApiConflict(record: _recordFromJson(decoded));
    } on Object {
      return const ProductAnalyticsPreferenceApiFailure();
    }
  }
}

// ignore: no_slop_linter/prefer_specific_type, SafeApiClient JSON callback
ProductAnalyticsPreferenceApiRecord _recordFromJson(dynamic value) {
  // ignore: no_slop_linter/prefer_specific_type, JSON boundary
  if (value is! Map<String, dynamic>) {
    throw const FormatException("Invalid product analytics preference response");
  }
  final preferenceValue = value["preference"];
  final revision = value["revision"];
  final userKey = value["userKey"];
  final preference = preferenceValue is String
      ? ProductAnalyticsPreference.fromWireValue(value: preferenceValue)
      : null;
  if (preference == null ||
      revision is! int ||
      revision < 1 ||
      userKey is! String ||
      !isValidProductAnalyticsUserKey(value: userKey)) {
    throw const FormatException("Invalid product analytics preference response");
  }
  return ProductAnalyticsPreferenceApiRecord(preference: preference, revision: revision, userKey: userKey);
}
