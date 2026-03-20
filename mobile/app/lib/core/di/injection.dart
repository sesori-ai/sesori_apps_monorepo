import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "injection.config.dart";

final getIt = GetIt.instance;

// 3-phase DI initialization order:
//   1. getIt.init()                  — Flutter platform deps (SecureStorage, http.Client, etc.)
//   2. configureAuthDependencies(…)  — Auth deps (AuthManager, interface bindings, etc.)
//   3. configureCoreDependencies(…)  — Core deps (ConnectionService, VoiceApi, etc.)
@InjectableInit()
void configureDependencies() {
  getIt.init();
  configureAuthDependencies(getIt);
  configureCoreDependencies(getIt);
}
