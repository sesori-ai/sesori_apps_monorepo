enum ProductAnalyticsPreference {
  enabled(wireValue: "enabled"),
  disabled(wireValue: "disabled");

  final String wireValue;
  const ProductAnalyticsPreference({required this.wireValue});

  static ProductAnalyticsPreference? fromWireValue({required String value}) => switch (value) {
    "enabled" => ProductAnalyticsPreference.enabled,
    "disabled" => ProductAnalyticsPreference.disabled,
    _ => null,
  };
}

final _productAnalyticsUserKeyPattern = RegExp(r"^[a-f0-9]{64}$");

bool isValidProductAnalyticsUserKey({required String value}) => _productAnalyticsUserKeyPattern.hasMatch(value);
