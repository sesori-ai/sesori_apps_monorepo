import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "firebase_register_module.dart";
import "injection.config.dart";

final getIt = GetIt.instance;

// 3-phase DI initialization order:
//   1. getIt.init()                  — Flutter platform deps (SecureStorage, http.Client, etc.)
//   2. configureAuthDependencies(…)  — Auth deps (AuthManager, interface bindings, etc.)
//   3. configureCoreDependencies(…)  — Core deps (ConnectionService, VoiceApi, etc.)
//
// The analytics runtime capability depends on the stored auth session, so it is
// resolved after phase 2 and registered before phase 3. Every consumer of it is
// a lazy singleton, so nothing reads it earlier.
@InjectableInit()
Future<void> configureDependencies({
  required bool firebaseEnabled,
  required Future<AnalyticsRuntimeCapability> Function({required AuthSession authSession})
  createAnalyticsRuntimeCapability,
}) async {
  getIt.init(
    environment: firebaseEnabled ? firebaseEnabledEnvironmentName : firebaseDisabledEnvironmentName,
  );

  configureAuthDependencies(getIt);
  getIt.registerSingleton<AnalyticsRuntimeCapability>(
    await createAnalyticsRuntimeCapability(authSession: getIt<AuthSession>()),
  );
  configureCoreDependencies(getIt);
  getIt<MessageThumbnailCacheService>();
}
