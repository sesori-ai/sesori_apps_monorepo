import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";

import "injection.config.dart";

// Phase 2 of 3-phase DI init:
//   1. Flutter platform DI (SecureStorage, http.Client, etc.)
//   2. configureAuthDependencies ← THIS
//   3. configureCoreDependencies (ConnectionService, etc.)
@InjectableInit()
void configureAuthDependencies(GetIt getIt) => getIt.init();
