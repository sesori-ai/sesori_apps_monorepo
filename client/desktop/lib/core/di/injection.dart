import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

import "injection.config.dart";

final GetIt getIt = GetIt.instance;

// Desktop 4-phase DI initialization order (see client/AGENTS.md):
//   1. getIt.init()                         — desktop platform adapters
//      (SecureStorage, UrlLauncher, LifecycleSource, OAuthDeviceDescriptor-
//      Provider, http.Client, …)
//   2. configureAuthDependencies(…)         — auth module
//   3. configureCoreDependencies(…)         — core module
//   4. configureDesktopCoreDependencies(…)  — desktop core module
//
// Module registrations are lazy: resolution happens on first getIt<T>() use.
// The only eager registration is the shell's own DesktopLifecycleObserver,
// which must attach its WidgetsBinding observer at startup.
@InjectableInit()
void configureDesktopDependencies() {
  getIt.init();
  configureAuthDependencies(getIt);
  configureCoreDependencies(getIt);
  configureDesktopCoreDependencies(getIt);
}
