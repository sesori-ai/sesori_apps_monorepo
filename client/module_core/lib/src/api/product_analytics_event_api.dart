import "dart:convert";

import "package:freezed_annotation/freezed_annotation.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

part "product_analytics_event_api.freezed.dart";
part "product_analytics_event_api.g.dart";

const _attemptDeadline = Duration(seconds: 5);

@JsonEnum(valueField: "wireValue")
enum ProductAnalyticsEventSchemaVersion({required final int wireValue}) {
  v1(wireValue: 1),
}

/// The app's own OS, uppercase to match GA4's `IOS` and `ANDROID` in the same
/// warehouse column.
@JsonEnum(valueField: "wireValue")
enum ProductAnalyticsEventPlatform({required final String wireValue}) {
  macos(wireValue: "MACOS"),
  linux(wireValue: "LINUX"),
  windows(wireValue: "WINDOWS"),
}

/// One event. It carries no user key, because the server derives it from the
/// access token.
@Freezed(fromJson: false, toJson: true)
sealed class ProductAnalyticsEventRequest with _$ProductAnalyticsEventRequest {
  const factory({
    required ProductAnalyticsEventSchemaVersion schemaVersion,
    required ProductAnalyticsEventPlatform platform,
    required String appVersion,
    required String name,
    required int occurredAtMicros,
    required Map<String, String> params,
  }) = _ProductAnalyticsEventRequest;
}

@Freezed(fromJson: false, toJson: false)
sealed class ProductAnalyticsEventApiResult with _$ProductAnalyticsEventApiResult {
  const factory delivered() = ProductAnalyticsEventApiDelivered;

  /// [description] is the failure category or HTTP status. It's safe to log, and
  /// so is [cause]. Response bodies stay out, because a server can echo a request.
  const factory permanentFailure({
    required String description,
    // ignore: no_slop_linter/prefer_specific_type, the original error is only rendered at the logging boundary
    required Object? cause,
  }) = ProductAnalyticsEventApiPermanentFailure;

  /// See [ProductAnalyticsEventApiResult.permanentFailure]. Only a thrown failure has a [stackTrace].
  const factory transientFailure({
    required String description,
    // ignore: no_slop_linter/prefer_specific_type, Dart permits arbitrary thrown objects
    required Object? cause,
    required StackTrace? stackTrace,
  }) = ProductAnalyticsEventApiTransientFailure;
}

@lazySingleton
class ProductAnalyticsEventApi({required final AuthenticatedHttpApiClient _client}) {
  final Uri _url;

  this : _url = Uri.parse("$authBaseUrl/product-analytics/events");

  /// Makes one attempt under its own deadline. A timed-out request is abandoned
  /// rather than cancelled; the server ignores a duplicate if it still arrives.
  Future<ProductAnalyticsEventApiResult> send({
    required String userId,
    required ProductAnalyticsEventRequest request,
  }) async {
    try {
      final response = await _client
          .postForUser<bool>(
            url: _url,
            userId: userId,
            fromJson: (_) => true,
            body: jsonEncode(request.toJson()),
          )
          .timeout(_attemptDeadline);
      return switch (response) {
        SuccessResponse() => const ProductAnalyticsEventApiResult.delivered(),
        ErrorResponse(:final error) => switch (error) {
          // A failed token refresh surfaces as not authenticated, usually after
          // waking from sleep. After a real sign-out or account switch, a retry
          // stops locally and sends nothing.
          NotAuthenticatedError() => const ProductAnalyticsEventApiResult.transientFailure(
            description: "not authenticated",
            cause: null,
            stackTrace: null,
          ),
          DartHttpClientError(:final innerError) => ProductAnalyticsEventApiResult.transientFailure(
            description: "network error",
            cause: innerError,
            stackTrace: null,
          ),
          NonSuccessCodeError(:final errorCode) when errorCode >= 500 =>
            ProductAnalyticsEventApiResult.transientFailure(
              description: "HTTP $errorCode",
              cause: null,
              stackTrace: null,
            ),
          NonSuccessCodeError(:final errorCode) => ProductAnalyticsEventApiResult.permanentFailure(
            description: "HTTP $errorCode",
            cause: null,
          ),
          // ApiError renders these without the response body.
          JsonParsingError() || EmptyResponseError() || GenericError() =>
            ProductAnalyticsEventApiResult.permanentFailure(description: "unusable response", cause: error),
        },
      };
    } on Object catch (error, stackTrace) {
      // The deadline, and transport failures the HTTP client doesn't wrap, such
      // as a TLS handshake failure.
      return ProductAnalyticsEventApiResult.transientFailure(
        description: "no response",
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
