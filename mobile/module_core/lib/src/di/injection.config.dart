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
import 'package:sesori_auth/sesori_auth.dart' as _i442;
import 'package:sesori_dart_core/src/api/client/relay_http_client.dart'
    as _i857;
import 'package:sesori_dart_core/src/api/notification_api.dart' as _i400;
import 'package:sesori_dart_core/src/api/notification_preferences_api.dart'
    as _i396;
import 'package:sesori_dart_core/src/api/permission_api.dart' as _i231;
import 'package:sesori_dart_core/src/api/project_api.dart' as _i733;
import 'package:sesori_dart_core/src/api/session_api.dart' as _i603;
import 'package:sesori_dart_core/src/capabilities/project/project_service.dart'
    as _i680;
import 'package:sesori_dart_core/src/capabilities/relay/room_key_storage.dart'
    as _i895;
import 'package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart'
    as _i369;
import 'package:sesori_dart_core/src/capabilities/session/session_service.dart'
    as _i12;
import 'package:sesori_dart_core/src/capabilities/sse/sse_event_repository.dart'
    as _i569;
import 'package:sesori_dart_core/src/capabilities/voice/voice_api.dart'
    as _i176;
import 'package:sesori_dart_core/src/platform/lifecycle_source.dart' as _i903;
import 'package:sesori_dart_core/src/platform/local_notification_client.dart'
    as _i1037;
import 'package:sesori_dart_core/src/platform/push_messaging_source.dart'
    as _i330;
import 'package:sesori_dart_core/src/platform/route_dispatcher.dart' as _i951;
import 'package:sesori_dart_core/src/repositories/notification_preferences_repository.dart'
    as _i458;
import 'package:sesori_dart_core/src/repositories/notification_repository.dart'
    as _i471;
import 'package:sesori_dart_core/src/repositories/permission_repository.dart'
    as _i679;
import 'package:sesori_dart_core/src/repositories/project_repository.dart'
    as _i80;
import 'package:sesori_dart_core/src/repositories/session_repository.dart'
    as _i7;
import 'package:sesori_dart_core/src/routing/notification_open_dispatcher.dart'
    as _i516;
import 'package:sesori_dart_core/src/routing/oauth_callback_dispatcher.dart'
    as _i607;
import 'package:sesori_dart_core/src/services/foreground_notification_dispatcher.dart'
    as _i101;
import 'package:sesori_dart_core/src/services/notification_registration_service.dart'
    as _i659;
import 'package:sesori_dart_core/src/services/session_detail_load_service.dart'
    as _i709;
import 'package:sesori_shared/sesori_shared.dart' as _i553;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.lazySingleton<_i369.ClockProvider>(() => const _i369.ClockProvider());
    gh.lazySingleton<_i369.RelayClientFactory>(
      () => const _i369.RelayClientFactory(),
    );
    gh.lazySingleton<_i607.OAuthCallbackDispatcher>(
      () => _i607.OAuthCallbackDispatcher(gh<_i442.OAuthFlowProvider>()),
    );
    gh.lazySingleton<_i895.RoomKeyStorage>(
      () => _i895.RoomKeyStorage(gh<_i442.SecureStorage>()),
    );
    gh.lazySingleton<_i400.NotificationApi>(
      () =>
          _i400.NotificationApi(client: gh<_i442.AuthenticatedHttpApiClient>()),
    );
    gh.lazySingleton<_i176.VoiceApi>(
      () => _i176.VoiceApi(gh<_i442.AuthenticatedHttpApiClient>()),
    );
    gh.lazySingleton<_i516.NotificationOpenDispatcher>(
      () => _i516.NotificationOpenDispatcher(
        authSession: gh<_i442.AuthSession>(),
        pushMessagingSource: gh<_i330.PushMessagingSource>(),
        localNotificationClient: gh<_i1037.LocalNotificationClient>(),
        routeDispatcher: gh<_i951.RouteDispatcher>(),
      ),
    );
    gh.lazySingleton<_i396.NotificationPreferencesApi>(
      () =>
          _i396.NotificationPreferencesApi(storage: gh<_i442.SecureStorage>()),
    );
    gh.lazySingleton<_i369.ConnectionService>(
      () => _i369.ConnectionService(
        gh<_i553.RelayCryptoService>(),
        gh<_i895.RoomKeyStorage>(),
        gh<_i442.AuthTokenProvider>(),
        gh<_i442.AuthSession>(),
        gh<_i903.LifecycleSource>(),
        gh<_i553.FailureReporter>(),
        clock: gh<_i369.ClockProvider>(),
        relayClientFactory: gh<_i369.RelayClientFactory>(),
      ),
    );
    gh.lazySingleton<_i857.RelayHttpApiClient>(
      () => _i857.RelayHttpApiClient(gh<_i369.ConnectionService>()),
    );
    gh.lazySingleton<_i231.PermissionApi>(
      () => _i231.PermissionApi(client: gh<_i857.RelayHttpApiClient>()),
    );
    gh.lazySingleton<_i733.ProjectApi>(
      () => _i733.ProjectApi(client: gh<_i857.RelayHttpApiClient>()),
    );
    gh.lazySingleton<_i603.SessionApi>(
      () => _i603.SessionApi(client: gh<_i857.RelayHttpApiClient>()),
    );
    gh.lazySingleton<_i471.NotificationRepository>(
      () => _i471.NotificationRepository(api: gh<_i400.NotificationApi>()),
    );
    gh.lazySingleton<_i458.NotificationPreferencesRepository>(
      () => _i458.NotificationPreferencesRepository(
        api: gh<_i396.NotificationPreferencesApi>(),
      ),
    );
    gh.lazySingleton<_i680.ProjectService>(
      () => _i680.ProjectService(gh<_i857.RelayHttpApiClient>()),
    );
    gh.lazySingleton<_i7.SessionRepository>(
      () => _i7.SessionRepository(api: gh<_i603.SessionApi>()),
    );
    gh.lazySingleton<_i101.ForegroundNotificationDispatcher>(
      () => _i101.ForegroundNotificationDispatcher(
        notificationPreferencesRepository:
            gh<_i458.NotificationPreferencesRepository>(),
        localNotificationClient: gh<_i1037.LocalNotificationClient>(),
        pushMessagingSource: gh<_i330.PushMessagingSource>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i659.NotificationRegistrationService>(
      () => _i659.NotificationRegistrationService(
        repository: gh<_i471.NotificationRepository>(),
        authSession: gh<_i442.AuthSession>(),
        pushMessagingSource: gh<_i330.PushMessagingSource>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i569.SseEventRepository>(
      () => _i569.SseEventRepository(
        gh<_i369.ConnectionService>(),
        failureReporter: gh<_i553.FailureReporter>(),
      ),
    );
    gh.lazySingleton<_i80.ProjectRepository>(
      () => _i80.ProjectRepository(api: gh<_i733.ProjectApi>()),
    );
    gh.lazySingleton<_i12.SessionService>(
      () => _i12.SessionService(repository: gh<_i7.SessionRepository>()),
    );
    gh.lazySingleton<_i679.PermissionRepository>(
      () => _i679.PermissionRepository(api: gh<_i231.PermissionApi>()),
    );
    gh.lazySingleton<_i709.SessionDetailLoadService>(
      () => _i709.SessionDetailLoadService(
        repository: gh<_i7.SessionRepository>(),
        projectRepository: gh<_i80.ProjectRepository>(),
        connectionService: gh<_i369.ConnectionService>(),
      ),
    );
    return this;
  }
}
