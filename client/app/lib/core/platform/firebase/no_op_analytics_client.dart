import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../di/firebase_register_module.dart";

/// The [AnalyticsClient] for builds with no Firebase SDK (web, Linux, Windows,
/// Android profile). Mirrors `client/desktop`'s no-op of the same name.
@firebaseDisabledEnvironment
@LazySingleton(as: AnalyticsClient)
class NoOpAnalyticsClient() implements AnalyticsClient {
  @override
  Future<void> logProductEvent({required ProductAnalyticsEnvelope envelope, required String userKey}) async {}

  @override
  Future<void> logInstallationEvent({required InstallationAnalyticsEvent event}) async {}

  @override
  Future<void> activateAfterInteractiveAuthentication() async {}
}
