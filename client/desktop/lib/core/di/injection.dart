import "package:get_it/get_it.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

final GetIt getIt = GetIt.instance;

// Desktop 4-phase DI initialization order (see client/AGENTS.md):
//   1. getIt.init()                         — desktop platform adapters
//      (SecureStorage, UrlLauncher, http.Client, …); registered once the
//      first adapters land — nothing resolves them until then.
//   2. configureAuthDependencies(…)         — auth module
//   3. configureCoreDependencies(…)         — core module
//   4. configureDesktopCoreDependencies(…)  — desktop core module
//
// All module registrations are lazy: resolution happens on first getIt<T>()
// use, which is why the adapter-less bootstrap is safe today.
void configureDesktopDependencies() {
  configureAuthDependencies(getIt);
  configureCoreDependencies(getIt);
  configureDesktopCoreDependencies(getIt);
}
