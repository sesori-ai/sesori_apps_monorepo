import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_core/firebase_core.dart";
import "package:injectable/injectable.dart";

/// Owns access to the native Firebase SDK, separate from desktop startup policy.
@lazySingleton
class DesktopFirebaseSdk() {
  Future<FirebaseAnalytics> initialize() async {
    // TODO: Pass generated com.sesori.desktop FirebaseOptions before this PR is
    // ready. Do not bundle a default GoogleService-Info.plist: FlutterFire would
    // configure it during plugin registration, before primary-process admission.
    final app = await Firebase.initializeApp();
    return FirebaseAnalytics.instanceFor(app: app);
  }
}
