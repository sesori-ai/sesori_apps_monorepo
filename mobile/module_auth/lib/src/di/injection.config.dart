// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:http/http.dart' as _i519;
import 'package:injectable/injectable.dart' as _i526;
import 'package:sesori_auth/src/auth_manager.dart' as _i655;
import 'package:sesori_auth/src/client/authenticated_http_api_client.dart'
    as _i463;
import 'package:sesori_auth/src/client/http_api_client.dart' as _i542;
import 'package:sesori_auth/src/di/auth_module.dart' as _i992;
import 'package:sesori_auth/src/interfaces/auth_session.dart' as _i279;
import 'package:sesori_auth/src/interfaces/auth_token_provider.dart' as _i264;
import 'package:sesori_auth/src/interfaces/oauth_flow_provider.dart' as _i798;
import 'package:sesori_auth/src/platform/secure_storage.dart' as _i892;
import 'package:sesori_auth/src/storage/oauth_storage_service.dart' as _i765;
import 'package:sesori_auth/src/storage/token_storage_service.dart' as _i164;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final authModule = _$AuthModule();
    gh.lazySingleton<_i765.OAuthStorageService>(
      () => _i765.OAuthStorageService(gh<_i892.SecureStorage>()),
    );
    gh.lazySingleton<_i164.TokenStorageService>(
      () => _i164.TokenStorageService(gh<_i892.SecureStorage>()),
    );
    gh.lazySingleton<_i655.AuthManager>(
      () => _i655.AuthManager(
        gh<_i519.Client>(),
        gh<_i164.TokenStorageService>(),
        gh<_i765.OAuthStorageService>(),
      ),
    );
    gh.lazySingleton<_i542.HttpApiClient>(
      () => _i542.HttpApiClient(gh<_i519.Client>()),
    );
    gh.lazySingleton<_i264.AuthTokenProvider>(
      () => authModule.authTokenProvider(gh<_i655.AuthManager>()),
    );
    gh.lazySingleton<_i798.OAuthFlowProvider>(
      () => authModule.oAuthFlowProvider(gh<_i655.AuthManager>()),
    );
    gh.lazySingleton<_i279.AuthSession>(
      () => authModule.authSession(gh<_i655.AuthManager>()),
    );
    gh.lazySingleton<_i463.AuthenticatedHttpApiClient>(
      () => _i463.AuthenticatedHttpApiClient(
        gh<_i542.HttpApiClient>(),
        gh<_i655.AuthManager>(),
      ),
    );
    return this;
  }
}

class _$AuthModule extends _i992.AuthModule {}
