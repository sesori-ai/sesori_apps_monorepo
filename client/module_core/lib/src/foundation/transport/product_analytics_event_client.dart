import "dart:convert";

import "package:freezed_annotation/freezed_annotation.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

part "product_analytics_event_client.freezed.dart";
part "product_analytics_event_client.g.dart";

const _attemptDeadline = Duration(seconds: 5);
const _maxLoggedBodyLength = 500;

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
sealed class ProductAnalyticsEventClientResult with _$ProductAnalyticsEventClientResult {
  const factory delivered() = ProductAnalyticsEventClientDelivered;

  /// [description] is the failure category or HTTP status, with the start of any
  /// response body. It and [cause] are safe to log: a request holds only closed
  /// enums, so a server echoing one can't leak anything.
  const factory permanentFailure({
    required String description,
    // ignore: no_slop_linter/prefer_specific_type, the original error is only rendered at the logging boundary
    required Object? cause,
  }) = ProductAnalyticsEventClientPermanentFailure;

  /// See [ProductAnalyticsEventClientResult.permanentFailure]. Only a thrown
  /// failure has a [stackTrace].
  const factory transientFailure({
    required String description,
    // ignore: no_slop_linter/prefer_specific_type, Dart permits arbitrary thrown objects
    required Object? cause,
    required StackTrace? stackTrace,
  }) = ProductAnalyticsEventClientTransientFailure;
}

/// Posts one product event to the auth server and maps the outcome.
@lazySingleton
class ProductAnalyticsEventClient({required final AuthenticatedHttpApiClient _client}) {
  final Uri _url;

  this : _url = Uri.parse("$authBaseUrl/product-analytics/events");

  /// Makes one attempt under its own deadline. A timed-out request is abandoned
  /// rather than cancelled; the server ignores a duplicate if it still arrives.
  Future<ProductAnalyticsEventClientResult> send({
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
        SuccessResponse() => const ProductAnalyticsEventClientResult.delivered(),
        ErrorResponse(:final error) => switch (error) {
          // A failed token refresh surfaces as not authenticated, usually after
          // waking from sleep.
          NotAuthenticatedError() => const ProductAnalyticsEventClientResult.transientFailure(
            description: "not authenticated",
            cause: null,
            stackTrace: null,
          ),
          DartHttpClientError(:final innerError) => ProductAnalyticsEventClientResult.transientFailure(
            description: "network error",
            cause: innerError,
            stackTrace: null,
          ),
          NonSuccessCodeError(:final errorCode, :final rawErrorString) when errorCode >= 500 =>
            ProductAnalyticsEventClientResult.transientFailure(
              description: _describeStatus(status: errorCode, body: rawErrorString),
              cause: null,
              stackTrace: null,
            ),
          NonSuccessCodeError(:final errorCode, :final rawErrorString) =>
            ProductAnalyticsEventClientResult.permanentFailure(
              description: _describeStatus(status: errorCode, body: rawErrorString),
              cause: null,
            ),
          // ApiError renders these without the response body.
          JsonParsingError() || EmptyResponseError() || GenericError() =>
            ProductAnalyticsEventClientResult.permanentFailure(description: "unusable response", cause: error),
        },
      };
    } on Object catch (error, stackTrace) {
      // The deadline, and transport failures the HTTP client doesn't wrap, such
      // as a TLS handshake failure.
      return ProductAnalyticsEventClientResult.transientFailure(
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
