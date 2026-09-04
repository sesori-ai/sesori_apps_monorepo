import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../di/firebase_register_module.dart";

@firebaseDisabledEnvironment
@LazySingleton(as: AnalyticsReleaseCutoffSource)
class NoOpAnalyticsReleaseCutoffSource() implements AnalyticsReleaseCutoffSource {
  @override
  Future<int?> fetchLatestSubmittedProductionBuild() async => null;
}
