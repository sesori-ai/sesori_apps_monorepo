enum AnalyticsRuntimeDisabledReason() {
  debugOrProfile,
  unsupportedPlatform,
  analyticsSinkUnavailable,
  identitySafetyPreconditionFailed,
}

sealed class const AnalyticsRuntimeCapability() {
  const factory AnalyticsRuntimeCapability.enabled() = AnalyticsRuntimeEnabled;
  const factory AnalyticsRuntimeCapability.disabled({required AnalyticsRuntimeDisabledReason reason}) =
      AnalyticsRuntimeDisabled;

  bool get isEnabled => this is AnalyticsRuntimeEnabled;
}

final class const AnalyticsRuntimeEnabled() extends AnalyticsRuntimeCapability;

final class const AnalyticsRuntimeDisabled({required this.reason}) extends AnalyticsRuntimeCapability {
  final AnalyticsRuntimeDisabledReason reason;
}
