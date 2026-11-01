import "dart:convert";

import "package:freezed_annotation/freezed_annotation.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../foundation/models/product_analytics/product_analytics_event_delivery.dart";

part "product_analytics_event_api.freezed.dart";
part "product_analytics_event_api.g.dart";

const _attemptDeadline = Duration(seconds: 5);

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

/// Posts one product event to the auth server.
@lazySingleton
class ProductAnalyticsEventApi({required final AuthenticatedHttpApiClient _client}) {
  final Uri _url;

  this : _url = Uri.parse("$authBaseUrl/product-analytics/events");

  /// Makes one attempt under its own deadline, which throws when it passes. A
  /// timed-out request is abandoned rather than cancelled; the server ignores a
  /// duplicate if it still arrives.
  Future<ApiResponse<bool>> send({
    required String userId,
    required ProductAnalyticsEventRequest request,
  }) => _client
      .postForUser<bool>(
        url: _url,
        userId: userId,
        fromJson: (_) => true,
        body: jsonEncode(request.toJson()),
      )
      .timeout(_attemptDeadline);
}
