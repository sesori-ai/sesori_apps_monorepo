import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_persistence/sesori_persistence.dart";

import "analytics_runtime_bootstrap.dart";
import "firebase_register_module.dart";
import "injection.config.dart";

final getIt = GetIt.instance;

// Platform → persistence → auth → core → production migration → consumers.
// Registrations stay lazy until import or its reset recovery finishes. Then prepare analytics
// without awaiting its remote crawl-gate decision and register its capability
// before consumer resolution. Development never resolves the legacy source.
@InjectableInit(ignoreUnregisteredTypes: [PersistenceScope])
Future<AnalyticsRuntimeBootstrap> configureDependencies({
  required PersistenceScope scope,
  required bool firebaseEnabled,
  required Future<AnalyticsRuntimeBootstrap> Function({
    required AnalyticsCrawlGateService crawlGateService,
  })
  createAnalyticsRuntimeBootstrap,
}) async {
  getIt.registerSingleton<PersistenceScope>(scope);
  getIt.init(
    environment: firebaseEnabled ? firebaseEnabledEnvironmentName : firebaseDisabledEnvironmentName,
  );

  configurePersistenceDependencies(getIt: getIt);
  configureAuthDependencies(getIt);
  configureCoreDependencies(getIt);
  // Recovery continues startup, so retain its diagnostics in the app log too.
  setLogSink(sink: getIt<LogSink>());
  if (getIt<PersistenceScope>() == PersistenceScope.production) {
    // COMPATIBILITY 2026-09-25 (v1.9.1): retain this deprecated import until
    // supported direct upgrades exclude all per-value-native production builds.
    // ignore: deprecated_member_use
    await getIt<LegacyNativeStorageMigrationService>().migrate();
  }
  final bootstrap = await createAnalyticsRuntimeBootstrap(
    crawlGateService: getIt<AnalyticsCrawlGateService>(),
  );
  getIt.registerSingleton<AnalyticsRuntimeCapability>(bootstrap.capability);
  getIt<MessageThumbnailCacheService>();
  return bootstrap;
}
