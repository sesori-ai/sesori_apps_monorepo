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
import 'package:sesori_dart_core/sesori_dart_core.dart' as _i948;
import 'package:sesori_desktop_core/src/control/control_message_dispatcher.dart'
    as _i21;
import 'package:sesori_desktop_core/src/foundation/control_channel_server.dart'
    as _i464;
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
    gh.lazySingleton<_i464.ControlChannelServer>(
      () => _i464.ControlChannelServer(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i686.BridgePromptTracker>(
      () => _i686.BridgePromptTracker(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i227.BridgeStatusTracker>(
      () => _i227.BridgeStatusTracker(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i21.ControlMessageDispatcher>(
      () => _i21.ControlMessageDispatcher(
        server: gh<_i464.ControlChannelServer>(),
        tokenProvider: gh<_i948.AuthTokenProvider>(),
        statusTracker: gh<_i227.BridgeStatusTracker>(),
        promptTracker: gh<_i686.BridgePromptTracker>(),
      ),
      dispose: (i) => i.dispose(),
    );
    return this;
  }
}
