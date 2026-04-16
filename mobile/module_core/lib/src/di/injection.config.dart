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
import 'package:sesori_dart_core/src/api/permission_api.dart' as _i231;
import 'package:sesori_dart_core/src/capabilities/notifications/notification_api_client.dart'
    as _i276;
import 'package:sesori_dart_core/src/capabilities/notifications/notification_preferences_service.dart'
    as _i786;
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
import 'package:sesori_dart_core/src/repositories/permission_repository.dart'
    as _i679;
import 'package:sesori_dart_core/src/routing/auth_redirect_service.dart'
    as _i436;
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
    gh.lazySingleton<_i786.NotificationPreferencesService>(
      () => _i786.NotificationPreferencesService(gh<_i442.SecureStorage>()),
    );
    gh.lazySingleton<_i895.RoomKeyStorage>(
      () => _i895.RoomKeyStorage(gh<_i442.SecureStorage>()),
    );
    gh.lazySingleton<_i276.NotificationApiClient>(
      () => _i276.NotificationApiClient(gh<_i442.AuthenticatedHttpApiClient>()),
    );
    gh.lazySingleton<_i176.VoiceApi>(
      () => _i176.VoiceApi(gh<_i442.AuthenticatedHttpApiClient>()),
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
    gh.lazySingleton<_i436.AuthRedirectService>(
      () => _i436.AuthRedirectService(
        gh<_i442.OAuthFlowProvider>(),
        gh<_i442.AuthSession>(),
        gh<_i442.AuthTokenProvider>(),
        gh<_i369.ConnectionService>(),
      ),
    );
    gh.lazySingleton<_i680.ProjectService>(
      () => _i680.ProjectService(gh<_i857.RelayHttpApiClient>()),
    );
    gh.lazySingleton<_i12.SessionService>(
      () => _i12.SessionService(gh<_i857.RelayHttpApiClient>()),
    );
    gh.lazySingleton<_i569.SseEventRepository>(
      () => _i569.SseEventRepository(
        gh<_i369.ConnectionService>(),
        failureReporter: gh<_i553.FailureReporter>(),
      ),
    );
    gh.lazySingleton<_i679.PermissionRepository>(
      () => _i679.PermissionRepository(api: gh<_i231.PermissionApi>()),
    );
    return this;
  }
}
