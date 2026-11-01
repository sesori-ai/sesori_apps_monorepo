import "dart:convert";

import "package:freezed_annotation/freezed_annotation.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../foundation/models/product_analytics/product_analytics_event_delivery.dart";

part "product_analytics_event_api.freezed.dart";
part "product_analytics_event_api.g.dart";

const _attemptDeadline = Duration(seconds: 5);
const _maxLoggedBodyLength = 500;

@JsonEnum(valueField: "wireValue")
enum ProductAnalyticsEventSchemaVersion({required final int wireValue}) {
  v1(wireValue: 1),
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

/// Posts one product event to the auth server and maps the outcome.
@lazySingleton
class ProductAnalyticsEventApi({required final AuthenticatedHttpApiClient _client}) {
  final Uri _url;

  this : _url = Uri.parse("$authBaseUrl/product-analytics/events");

  /// Makes one attempt under its own deadline. A timed-out request is abandoned
  /// rather than cancelled; the server ignores a duplicate if it still arrives.
  Future<ProductAnalyticsEventDeliveryResult> send({
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
        SuccessResponse() => const ProductAnalyticsEventDeliveryResult.delivered(),
        ErrorResponse(:final error) => switch (error) {
          // A failed token refresh, usually after waking from sleep, or an account
          // that is no longer current. The caller tells them apart by rechecking
          // the account before it retries.
          NotAuthenticatedError() => const ProductAnalyticsEventDeliveryResult.transientFailure(
            description: "not authenticated",
            cause: null,
            stackTrace: null,
          ),
          DartHttpClientError(:final innerError) => ProductAnalyticsEventDeliveryResult.transientFailure(
            description: "network error",
            cause: innerError,
            stackTrace: null,
          ),
          NonSuccessCodeError(:final errorCode, :final rawErrorString) when errorCode >= 500 =>
            ProductAnalyticsEventDeliveryResult.transientFailure(
              description: _describeStatus(status: errorCode, body: rawErrorString),
              cause: null,
              stackTrace: null,
            ),
          NonSuccessCodeError(:final errorCode, :final rawErrorString) =>
            ProductAnalyticsEventDeliveryResult.permanentFailure(
              description: _describeStatus(status: errorCode, body: rawErrorString),
              cause: null,
            ),
          // ApiError renders these without the response body.
          JsonParsingError() || EmptyResponseError() || GenericError() =>
            ProductAnalyticsEventDeliveryResult.permanentFailure(description: "unusable response", cause: error),
        },
      };
    } on Object catch (error, stackTrace) {
      // The deadline, and transport failures the HTTP client doesn't wrap, such
      // as a TLS handshake failure.
      return ProductAnalyticsEventDeliveryResult.transientFailure(
        description: "no response",
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// A proxy's error page can be long, so only its start is kept.
  String _describeStatus({required int status, required String? body}) {
    if (body == null || body.isEmpty) return "HTTP $status";
    return "HTTP $status: ${body.length > _maxLoggedBodyLength ? body.substring(0, _maxLoggedBodyLength) : body}";
  }
}
