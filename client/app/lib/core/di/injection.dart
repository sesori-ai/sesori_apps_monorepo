import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "analytics_runtime_bootstrap.dart";
import "firebase_register_module.dart";
import "injection.config.dart";

final getIt = GetIt.instance;

// 3-phase DI registration order:
//   1. getIt.init()                  — Flutter platform deps (SecureStorage, http.Client, etc.)
//   2. configureAuthDependencies(…)  — Auth deps (AuthManager, interface bindings, etc.)
//   3. configureCoreDependencies(…)  — Core deps (ConnectionService, VoiceApi, etc.)
//
// Core registrations are lazy. Resolve only the crawl-gate service after phase
// 3, prepare the analytics runtime without awaiting its remote crawl-gate
// decision, then register the capability before any consumer is instantiated.
@InjectableInit()
Future<AnalyticsRuntimeBootstrap> configureDependencies({
  required bool firebaseEnabled,
  required Future<AnalyticsRuntimeBootstrap> Function({
    required AnalyticsCrawlGateService crawlGateService,
  })
  createAnalyticsRuntimeBootstrap,
}) async {
  getIt.init(
    environment: firebaseEnabled ? firebaseEnabledEnvironmentName : firebaseDisabledEnvironmentName,
  );

  configureAuthDependencies(getIt);
  configureCoreDependencies(getIt);
  final bootstrap = await createAnalyticsRuntimeBootstrap(
    crawlGateService: getIt<AnalyticsCrawlGateService>(),
  );
  getIt.registerSingleton<AnalyticsRuntimeCapability>(bootstrap.capability);
  getIt<MessageThumbnailCacheService>();
  return bootstrap;
}
