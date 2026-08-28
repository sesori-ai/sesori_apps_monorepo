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
import 'package:sesori_desktop_core/src/api/bridge_process_api.dart' as _i874;
import 'package:sesori_desktop_core/src/api/bridge_process_log_storage.dart'
    as _i570;
import 'package:sesori_desktop_core/src/control/control_message_dispatcher.dart'
    as _i21;
import 'package:sesori_desktop_core/src/foundation/control_channel_server.dart'
    as _i464;
import 'package:sesori_desktop_core/src/foundation/platform/bridge_executable_path_resolver.dart'
    as _i961;
import 'package:sesori_desktop_core/src/foundation/platform/desktop_application_support_directory.dart'
    as _i695;
import 'package:sesori_desktop_core/src/repositories/bridge_process_repository.dart'
    as _i209;
import 'package:sesori_desktop_core/src/services/bridge_process_service.dart'
    as _i765;
import 'package:sesori_desktop_core/src/trackers/bridge_process_log_tracker.dart'
    as _i866;
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
    gh.lazySingleton<_i874.BridgeProcessApi>(() => _i874.BridgeProcessApi());
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
    gh.lazySingleton<_i570.BridgeProcessLogStorage>(
      () => _i570.BridgeProcessLogStorage(
        applicationSupportDirectory:
            gh<_i695.DesktopApplicationSupportDirectory>(),
      ),
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
    gh.lazySingleton<_i209.BridgeProcessRepository>(
      () => _i209.BridgeProcessRepository(
        processApi: gh<_i874.BridgeProcessApi>(),
        controlChannelServer: gh<_i464.ControlChannelServer>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i866.BridgeProcessLogTracker>(
      () => _i866.BridgeProcessLogTracker(
        storage: gh<_i570.BridgeProcessLogStorage>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i765.BridgeProcessService>(
      () => _i765.BridgeProcessService(
        repository: gh<_i209.BridgeProcessRepository>(),
        logTracker: gh<_i866.BridgeProcessLogTracker>(),
        controlChannelServer: gh<_i464.ControlChannelServer>(),
        authSession: gh<_i948.AuthSession>(),
        executablePathResolver: gh<_i961.BridgeExecutablePathResolver>(),
      ),
      dispose: (i) => i.dispose(),
    );
    return this;
  }
}
