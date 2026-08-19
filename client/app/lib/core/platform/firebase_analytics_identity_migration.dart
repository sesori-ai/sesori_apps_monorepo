import "package:firebase_analytics/firebase_analytics.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

class const FirebaseAnalyticsIdentityMigration({required final FirebaseAnalytics _analytics}) {
  /// Clears the legacy Firebase user ID, reporting whether the clear is confirmed.
  Future<bool> clearLegacyIdentity() async {
    try {
      await _analytics.setUserId(id: null);
      return true;
    } on Object catch (error, stackTrace) {
      logw("Failed to clear legacy Firebase analytics identity", error, stackTrace);
      return false;
    }
  }
}
