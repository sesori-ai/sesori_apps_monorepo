import "package:flutter/foundation.dart" show kReleaseMode;
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_persistence/sesori_persistence.dart";

import "../platform/desktop_route_dispatcher.dart";
import "injection.config.dart";
import "register_module.dart";

final GetIt getIt = GetIt.instance;

// Desktop 5-phase DI initialization order (see client/AGENTS.md):
//   1. getIt.init()                         — desktop platform capabilities
//   2. configurePersistenceDependencies(…)  — shared storage
//   3. configureAuthDependencies(…)         — auth module
//   4. configureCoreDependencies(…)         — core module
//   5. configureDesktopCoreDependencies(…)  — desktop core module
// Desktop never resolves the deprecated mobile importer.
//
// Module registrations are lazy: resolution happens on first getIt<T>() use.
// The only eager registration is the shell's own DesktopLifecycleObserver,
// which must attach its WidgetsBinding observer at startup.
@InjectableInit(ignoreUnregisteredTypes: [PersistenceScope])
void configureDesktopDependencies({required GoRouter router, required Future<void> routerReady}) {
  getIt.registerSingleton<PersistenceScope>(clientPersistenceScope);
  getIt.registerLazySingleton<RouteDispatcher>(
    () => DesktopRouteDispatcher(router: router, routerReady: routerReady),
  );
  getIt.registerSingleton<AnalyticsRuntimeCapability>(
    !kReleaseMode
        ? const AnalyticsRuntimeCapability.disabled(reason: AnalyticsRuntimeDisabledReason.debugOrProfile)
        // Source builds have no bundle identity, so delivery would drop every event.
        : const bool.hasEnvironment(DesktopBundleIdentity.defineName)
        ? const AnalyticsRuntimeCapability.enabled()
        : const AnalyticsRuntimeCapability.disabled(reason: AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable),
  );
  getIt.init();
  configurePersistenceDependencies(getIt: getIt);
  configureAuthDependencies(getIt);
  configureCoreDependencies(getIt);
  configureDesktopCoreDependencies(getIt);
}
