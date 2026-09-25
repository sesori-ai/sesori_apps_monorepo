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
import 'package:sesori_persistence/src/foundation/platform/primitive_storage.dart'
    as _i599;
import 'package:sesori_persistence/src/repositories/persister_repository.dart'
    as _i865;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.lazySingleton<_i449.PersisterApi>(
      () => _i449.PersisterApi(primitiveStorage: gh<_i599.PrimitiveStorage>()),
    );
    gh.lazySingleton<_i865.PersisterRepository>(
      () => _i865.PersisterRepository(persisterApi: gh<_i449.PersisterApi>()),
    );
    return this;
  }
}
