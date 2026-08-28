import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../di/firebase_register_module.dart";

@firebaseDisabledEnvironment
@LazySingleton(as: AndroidAnalyticsReleaseCutoffSource)
class NoOpAndroidAnalyticsReleaseCutoffSource() implements AndroidAnalyticsReleaseCutoffSource {
  @override
  Future<int?> fetchLatestSubmittedProductionBuild() async => null;
}
