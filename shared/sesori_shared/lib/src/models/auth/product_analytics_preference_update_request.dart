import "package:freezed_annotation/freezed_annotation.dart";

part "product_analytics_preference_update_request.freezed.dart";
part "product_analytics_preference_update_request.g.dart";

enum ProductAnalyticsPreferenceUpdateValue() {
  @JsonValue("enabled")
  enabled,
  @JsonValue("disabled")
  disabled,
}

@Freezed(fromJson: true, toJson: true)
sealed class ProductAnalyticsPreferenceUpdateRequest with _$ProductAnalyticsPreferenceUpdateRequest {
  const factory({
    required ProductAnalyticsPreferenceUpdateValue preference,
    required int expectedRevision,
    required String operationId,
  }) = _ProductAnalyticsPreferenceUpdateRequest;

  factory fromJson(Map<String, dynamic> json) =>
      _$ProductAnalyticsPreferenceUpdateRequestFromJson(json);
}
