import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

@LazySingleton(as: AnalyticsClient)
class NoOpAnalyticsClient implements AnalyticsClient {
  @override
  Future<void> logProductEvent({required ProductAnalyticsEnvelope envelope, required String userKey}) async {}

  @override
  Future<void> logInstallationEvent({required InstallationAnalyticsEvent event}) async {}
}
