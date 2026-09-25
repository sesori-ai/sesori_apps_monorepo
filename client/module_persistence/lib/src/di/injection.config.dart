// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:sesori_persistence/src/api/persister_api.dart' as _i449;
import 'package:sesori_persistence/src/foundation/persistence/persistence_database.dart'
    as _i103;
import 'package:sesori_persistence/src/foundation/persistence_scope.dart'
    as _i143;
import 'package:sesori_persistence/src/foundation/platform/persistence_directory.dart'
    as _i64;
import 'package:sesori_persistence/src/foundation/storage_cipher.dart' as _i527;
import 'package:sesori_persistence/src/repositories/persister_repository.dart'
    as _i865;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.lazySingleton<_i527.StorageCipher>(
      () => _i527.StorageCipher(scope: gh<_i143.PersistenceScope>()),
    );
    gh.lazySingleton<_i103.PersistenceDatabase>(
      () => _i103.PersistenceDatabase.open(
        persistenceDirectory: gh<_i64.PersistenceDirectory>(),
        scope: gh<_i143.PersistenceScope>(),
      ),
      dispose: (i) => i.close(),
    );
    gh.lazySingleton<_i449.PersisterApi>(
      () => _i449.PersisterApi(database: gh<_i103.PersistenceDatabase>()),
    );
    gh.lazySingleton<_i865.PersisterRepository>(
      () => _i865.PersisterRepository(persisterApi: gh<_i449.PersisterApi>()),
    );
    return this;
  }
}
