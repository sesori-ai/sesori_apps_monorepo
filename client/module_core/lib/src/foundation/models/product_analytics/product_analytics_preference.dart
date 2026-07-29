enum ProductAnalyticsPreference {
  enabled("enabled"),
  disabled("disabled");

  final String wireValue;
  const ProductAnalyticsPreference(this.wireValue);

  static ProductAnalyticsPreference? fromWireValue(String value) => switch (value) {
    "enabled" => ProductAnalyticsPreference.enabled,
    "disabled" => ProductAnalyticsPreference.disabled,
    _ => null,
  };
}
