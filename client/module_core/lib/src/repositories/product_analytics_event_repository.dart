import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../api/product_analytics_event_api.dart";
import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../foundation/models/product_analytics/product_analytics_event_delivery.dart";

const _maxLoggedBodyLength = 500;

@lazySingleton
class ProductAnalyticsEventRepository({required final ProductAnalyticsEventApi _api}) {
  /// Makes one attempt and says whether its outcome could change on a retry. The
  /// caller decides which [params] an event carries, and whether to retry.
  Future<ProductAnalyticsEventDeliveryResult> send({
    required String userId,
    required ProductAnalyticsEventPlatform platform,
    required String appVersion,
    required ProductAnalyticsEnvelope envelope,
    required Map<String, String> params,
  }) async {
    try {
      final response = await _api.send(
        userId: userId,
        request: ProductAnalyticsEventRequest(
          schemaVersion: ProductAnalyticsEventSchemaVersion.v1,
          platform: platform,
          appVersion: appVersion,
          name: envelope.event.wireName,
          occurredAtMicros: envelope.occurredAtUtc.microsecondsSinceEpoch,
          params: params,
        ),
      );
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
      // The API's deadline, and transport failures the HTTP client doesn't wrap,
      // such as a TLS handshake failure.
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
