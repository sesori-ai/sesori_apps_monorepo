import "package:freezed_annotation/freezed_annotation.dart";

@JsonEnum(valueField: "wireValue")
enum ProductAnalyticsPreference({required final String wireValue}) {
  enabled(wireValue: "enabled"),
  disabled(wireValue: "disabled");
}

final _productAnalyticsUserKeyPattern = RegExp(r"^[a-f0-9]{64}$");

bool isValidProductAnalyticsUserKey({required String value}) => _productAnalyticsUserKeyPattern.hasMatch(value);
