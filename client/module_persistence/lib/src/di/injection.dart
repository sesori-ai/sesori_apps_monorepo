import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";

import "../foundation/persistence_scope.dart";
import "../foundation/platform/master_key_store.dart";
import "../foundation/platform/persistence_directory.dart";
import "injection.config.dart";

/// Register after the shell's lazy platform bindings and before auth/core.
/// Neither configuration nor registration performs persistence I/O.
@InjectableInit(ignoreUnregisteredTypes: [PersistenceScope, PersistenceDirectory, MasterKeyStore])
void configurePersistenceDependencies({required GetIt getIt}) => getIt.init();
