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
import 'package:sesori_desktop_core/src/trackers/bridge_prompt_tracker.dart'
    as _i686;
import 'package:sesori_desktop_core/src/trackers/bridge_status_tracker.dart'
    as _i227;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.lazySingleton<_i686.BridgePromptTracker>(
      () => _i686.BridgePromptTracker(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i227.BridgeStatusTracker>(
      () => _i227.BridgeStatusTracker(),
      dispose: (i) => i.dispose(),
    );
    return this;
  }
}
