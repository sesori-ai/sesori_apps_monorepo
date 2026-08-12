enum AnalyticsRuntimeDisabledReason() {
  debugOrProfile,
  unsupportedPlatform,
  analyticsSinkUnavailable,
  identitySafetyPreconditionFailed,
}

sealed class const AnalyticsRuntimeCapability() {
  const factory enabled() = AnalyticsRuntimeEnabled;
  const factory disabled({required AnalyticsRuntimeDisabledReason reason}) =
      AnalyticsRuntimeDisabled;

  bool get isEnabled => this is AnalyticsRuntimeEnabled;
}

final class const AnalyticsRuntimeEnabled() extends AnalyticsRuntimeCapability;

final class const AnalyticsRuntimeDisabled({required final AnalyticsRuntimeDisabledReason reason}) extends AnalyticsRuntimeCapability;
