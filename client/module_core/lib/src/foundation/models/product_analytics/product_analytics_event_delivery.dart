import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_auth/sesori_auth.dart";

part "product_analytics_event_delivery.freezed.dart";

/// The app's own OS, uppercase to match GA4's `IOS` and `ANDROID` in the same
/// warehouse column.
@JsonEnum(valueField: "wireValue")
enum ProductAnalyticsEventPlatform({required final String wireValue}) {
  macos(wireValue: "MACOS"),
  linux(wireValue: "LINUX"),
  windows(wireValue: "WINDOWS"),
}

@Freezed(fromJson: false, toJson: false)
sealed class ProductAnalyticsEventDeliveryResult with _$ProductAnalyticsEventDeliveryResult {
  const factory delivered() = ProductAnalyticsEventDelivered;

  /// [description] is the failure category or HTTP status, with the start of any
  /// response body. It and [cause] are safe to log: a request holds only closed
  /// enums, so a server echoing one can't leak anything.
  const factory permanentFailure({required String description, required ApiError? cause}) =
      ProductAnalyticsEventPermanentFailure;

  /// See [ProductAnalyticsEventDeliveryResult.permanentFailure]. Only a thrown
  /// failure has a [stackTrace].
  const factory transientFailure({
    required String description,
    // ignore: no_slop_linter/prefer_specific_type, Dart permits arbitrary thrown objects
    required Object? cause,
    required StackTrace? stackTrace,
  }) = ProductAnalyticsEventTransientFailure;
}
