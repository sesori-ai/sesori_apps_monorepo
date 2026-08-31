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
import 'package:sesori_desktop_core/src/api/bridge_id_storage.dart' as _i73;
import 'package:sesori_desktop_core/src/api/bridge_process_api.dart' as _i874;
import 'package:sesori_desktop_core/src/api/bridge_process_log_storage.dart'
    as _i570;
import 'package:sesori_desktop_core/src/api/control_channel_api.dart' as _i639;
import 'package:sesori_desktop_core/src/api/desktop_instance_api.dart' as _i828;
import 'package:sesori_desktop_core/src/api/desktop_instance_storage.dart'
    as _i155;
import 'package:sesori_desktop_core/src/control/control_message_dispatcher.dart'
    as _i21;
import 'package:sesori_desktop_core/src/foundation/control_channel_server.dart'
    as _i464;
import 'package:sesori_desktop_core/src/foundation/platform/bridge_executable_path_resolver.dart'
    as _i962;
import 'package:sesori_desktop_core/src/foundation/platform/bridge_process_environment.dart'
    as _i961;
import 'package:sesori_desktop_core/src/foundation/platform/desktop_application_support_directory.dart'
    as _i695;
import 'package:sesori_desktop_core/src/foundation/platform/desktop_application_terminator.dart'
    as _i746;
import 'package:sesori_desktop_core/src/orchestration/desktop_bridge_takeover_orchestrator.dart'
    as _i850;
import 'package:sesori_desktop_core/src/orchestration/desktop_logout_orchestrator.dart'
    as _i165;
import 'package:sesori_desktop_core/src/orchestration/desktop_startup_orchestrator.dart'
    as _i455;
import 'package:sesori_desktop_core/src/repositories/bridge_process_log_repository.dart'
    as _i1072;
import 'package:sesori_desktop_core/src/repositories/bridge_process_repository.dart'
    as _i209;
import 'package:sesori_desktop_core/src/repositories/control_command_repository.dart'
    as _i171;
import 'package:sesori_desktop_core/src/repositories/desktop_instance_repository.dart'
    as _i210;
import 'package:sesori_desktop_core/src/services/bridge_process_service.dart'
    as _i765;
import 'package:sesori_desktop_core/src/services/control_command_service.dart'
    as _i175;
import 'package:sesori_desktop_core/src/services/desktop_instance_service.dart'
    as _i494;
import 'package:sesori_desktop_core/src/services/desktop_relay_connection_service.dart'
    as _i314;
import 'package:sesori_desktop_core/src/trackers/bridge_process_log_tracker.dart'
    as _i866;
import 'package:sesori_desktop_core/src/trackers/bridge_prompt_tracker.dart'
    as _i686;
import 'package:sesori_desktop_core/src/trackers/bridge_status_tracker.dart'
    as _i227;
import 'package:sesori_desktop_core/src/trackers/desktop_logout_tracker.dart'
    as _i786;

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
    gh.lazySingleton<_i786.DesktopLogoutTracker>(
      () => _i786.DesktopLogoutTracker(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i874.BridgeProcessApi>(
      () => _i874.BridgeProcessApi(
        processEnvironment: gh<_i961.BridgeProcessEnvironment>(),
      ),
    );
    gh.lazySingleton<_i73.BridgeIdStorage>(
      () => _i73.BridgeIdStorage(
        applicationSupportDirectory:
            gh<_i695.DesktopApplicationSupportDirectory>(),
      ),
    );
    gh.lazySingleton<_i570.BridgeProcessLogStorage>(
      () => _i570.BridgeProcessLogStorage(
        applicationSupportDirectory:
            gh<_i695.DesktopApplicationSupportDirectory>(),
      ),
    );
    gh.lazySingleton<_i828.DesktopInstanceApi>(
      () => _i828.DesktopInstanceApi(
        applicationSupportDirectory:
            gh<_i695.DesktopApplicationSupportDirectory>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i155.DesktopInstanceStorage>(
      () => _i155.DesktopInstanceStorage(
        applicationSupportDirectory:
            gh<_i695.DesktopApplicationSupportDirectory>(),
      ),
    );
    gh.lazySingleton<_i227.BridgeStatusTracker>(
      () => _i227.BridgeStatusTracker(
        bridgeIdStorage: gh<_i73.BridgeIdStorage>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i639.ControlChannelApi>(
      () => _i639.ControlChannelApi(server: gh<_i464.ControlChannelServer>()),
    );
    gh.lazySingleton<_i209.BridgeProcessRepository>(
      () => _i209.BridgeProcessRepository(
        processApi: gh<_i874.BridgeProcessApi>(),
        controlChannelServer: gh<_i464.ControlChannelServer>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i210.DesktopInstanceRepository>(
      () => _i210.DesktopInstanceRepository(
        api: gh<_i828.DesktopInstanceApi>(),
        storage: gh<_i155.DesktopInstanceStorage>(),
      ),
    );
    gh.lazySingleton<_i314.DesktopRelayConnectionService>(
      () => _i314.DesktopRelayConnectionService(
        authSession: gh<_i948.AuthSession>(),
        connectionService: gh<_i948.ConnectionService>(),
      ),
    );
    gh.lazySingleton<_i21.ControlMessageDispatcher>(
      () => _i21.ControlMessageDispatcher(
        server: gh<_i464.ControlChannelServer>(),
        tokenProvider: gh<_i948.AuthTokenProvider>(),
        authSession: gh<_i948.AuthSession>(),
        statusTracker: gh<_i227.BridgeStatusTracker>(),
        promptTracker: gh<_i686.BridgePromptTracker>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i171.ControlCommandRepository>(
      () => _i171.ControlCommandRepository(api: gh<_i639.ControlChannelApi>()),
    );
    gh.lazySingleton<_i1072.BridgeProcessLogRepository>(
      () => _i1072.BridgeProcessLogRepository(
        storage: gh<_i570.BridgeProcessLogStorage>(),
      ),
    );
    gh.lazySingleton<_i866.BridgeProcessLogTracker>(
      () => _i866.BridgeProcessLogTracker(
        storage: gh<_i570.BridgeProcessLogStorage>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i494.DesktopInstanceService>(
      () => _i494.DesktopInstanceService(
        repository: gh<_i210.DesktopInstanceRepository>(),
      ),
    );
    gh.lazySingleton<_i175.ControlCommandService>(
      () => _i175.ControlCommandService(
        repository: gh<_i171.ControlCommandRepository>(),
        promptTracker: gh<_i686.BridgePromptTracker>(),
      ),
    );
    gh.lazySingleton<_i765.BridgeProcessService>(
      () => _i765.BridgeProcessService(
        repository: gh<_i209.BridgeProcessRepository>(),
        logTracker: gh<_i866.BridgeProcessLogTracker>(),
        statusTracker: gh<_i227.BridgeStatusTracker>(),
        controlChannelServer: gh<_i464.ControlChannelServer>(),
        authSession: gh<_i948.AuthSession>(),
        executablePathResolver: gh<_i962.BridgeExecutablePathResolver>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i850.DesktopBridgeTakeoverOrchestrator>(
      () => _i850.DesktopBridgeTakeoverOrchestrator(
        processService: gh<_i765.BridgeProcessService>(),
        controlCommandService: gh<_i175.ControlCommandService>(),
        instanceService: gh<_i494.DesktopInstanceService>(),
        promptTracker: gh<_i686.BridgePromptTracker>(),
        statusTracker: gh<_i227.BridgeStatusTracker>(),
      ),
    );
    gh.lazySingleton<_i165.DesktopLogoutOrchestrator>(
      () => _i165.DesktopLogoutOrchestrator(
        processService: gh<_i765.BridgeProcessService>(),
        controlCommandService: gh<_i175.ControlCommandService>(),
        instanceService: gh<_i494.DesktopInstanceService>(),
        bridgeRepository: gh<_i948.BridgeRepository>(),
        statusTracker: gh<_i227.BridgeStatusTracker>(),
        logoutTracker: gh<_i786.DesktopLogoutTracker>(),
        authSession: gh<_i948.AuthSession>(),
      ),
    );
    gh.lazySingleton<_i455.DesktopStartupOrchestrator>(
      () => _i455.DesktopStartupOrchestrator(
        instanceService: gh<_i494.DesktopInstanceService>(),
        processService: gh<_i765.BridgeProcessService>(),
        applicationTerminator: gh<_i746.DesktopApplicationTerminator>(),
      ),
    );
    return this;
  }
}
