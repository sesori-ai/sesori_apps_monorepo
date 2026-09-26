import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:sesori_persistence/sesori_persistence.dart";

import "injection.config.dart";

// Platform capabilities → persistence → auth → core.
// Both shells configure shared persistence before these lazy auth consumers.
@InjectableInit(ignoreUnregisteredTypes: [SecureStorageRepository])
void configureAuthDependencies(GetIt getIt) => getIt.init();
