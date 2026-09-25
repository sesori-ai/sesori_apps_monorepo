import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:sesori_persistence/sesori_persistence.dart";

import "../migrations/deprecated_native_storage_v1/foundation/platform/legacy_native_storage.dart";
import "injection.config.dart";

@InjectableInit(ignoreUnregisteredTypes: [LegacyNativeStorage, PersisterRepository, SecureStorageRepository])
void configureCoreDependencies(GetIt getIt) => getIt.init();
