import "package:freezed_annotation/freezed_annotation.dart";

part "product_analytics_preference_update_request.freezed.dart";
part "product_analytics_preference_update_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class ProductAnalyticsPreferenceUpdateRequest with _$ProductAnalyticsPreferenceUpdateRequest {
  const factory ProductAnalyticsPreferenceUpdateRequest({
    required String preference,
    required int expectedRevision,
    required String operationId,
  }) = _ProductAnalyticsPreferenceUpdateRequest;

  factory ProductAnalyticsPreferenceUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$ProductAnalyticsPreferenceUpdateRequestFromJson(json);
}
