enum AnalyticsRuntimeDisabledReason {
  debugOrProfile,
  unsupportedPlatform,
  firebaseUnavailable,
  legacyIdentityClearFailed,
}

sealed class AnalyticsRuntimeCapability {
  const AnalyticsRuntimeCapability();

  const factory AnalyticsRuntimeCapability.enabled() = AnalyticsRuntimeEnabled;
  const factory AnalyticsRuntimeCapability.disabled({required AnalyticsRuntimeDisabledReason reason}) =
      AnalyticsRuntimeDisabled;

  bool get isEnabled => this is AnalyticsRuntimeEnabled;
}

final class AnalyticsRuntimeEnabled extends AnalyticsRuntimeCapability {
  const AnalyticsRuntimeEnabled();
}

final class AnalyticsRuntimeDisabled extends AnalyticsRuntimeCapability {
  final AnalyticsRuntimeDisabledReason reason;

  const AnalyticsRuntimeDisabled({required this.reason});
}
