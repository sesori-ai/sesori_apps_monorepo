import "package:firebase_analytics/firebase_analytics.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

class FirebaseAnalyticsIdentityMigration {
  final FirebaseAnalytics _analytics;

  const FirebaseAnalyticsIdentityMigration({required FirebaseAnalytics analytics}) : _analytics = analytics;

  Future<AnalyticsRuntimeCapability> clearLegacyIdentity({
    required AnalyticsRuntimeDisabledReason? disabledReasonAfterSuccess,
  }) async {
    try {
      await _analytics.setUserId(id: null);
      final reason = disabledReasonAfterSuccess;
      return reason == null
          ? const AnalyticsRuntimeCapability.enabled()
          : AnalyticsRuntimeCapability.disabled(reason: reason);
    } on Object catch (error, stackTrace) {
      logw("Failed to clear legacy Firebase analytics identity", error, stackTrace);
      return const AnalyticsRuntimeCapability.disabled(
        reason: AnalyticsRuntimeDisabledReason.legacyIdentityClearFailed,
      );
    }
  }
}
