import "package:freezed_annotation/freezed_annotation.dart";

/// Where the rating sheet was opened from.
@JsonEnum(valueField: "wireValue")
enum FeedbackSource({required final String wireValue}) {
  automatic(wireValue: "automatic"),
  settings(wireValue: "settings"),
}
