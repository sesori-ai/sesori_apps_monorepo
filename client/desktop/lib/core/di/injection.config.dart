// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:device_info_plus/device_info_plus.dart' as _i833;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:http/http.dart' as _i519;
import 'package:injectable/injectable.dart' as _i526;
import 'package:sesori_dart_core/sesori_dart_core.dart' as _i948;
import 'package:sesori_desktop/core/di/register_module.dart' as _i893;
import 'package:sesori_desktop/core/platform/desktop_lifecycle_observer.dart'
    as _i670;
import 'package:sesori_desktop/core/platform/desktop_oauth_device_descriptor_provider.dart'
    as _i20;
import 'package:sesori_desktop/core/platform/desktop_secure_storage_adapter.dart'
    as _i757;
import 'package:sesori_desktop/core/platform/desktop_url_launcher.dart'
    as _i137;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    gh.lazySingleton<_i519.Client>(() => registerModule.httpClient);
    gh.lazySingleton<_i833.DeviceInfoPlugin>(
      () => registerModule.deviceInfoPlugin,
    );
    gh.lazySingleton<_i558.FlutterSecureStorage>(
      () => registerModule.secureStorage,
    );
    gh.lazySingleton<_i948.SecureStorage>(
      () => _i757.DesktopSecureStorageAdapter(gh<_i558.FlutterSecureStorage>()),
    );
    gh.singleton<_i948.LifecycleSource>(() => _i670.DesktopLifecycleObserver());
    gh.lazySingleton<_i948.UrlLauncher>(() => _i137.DesktopUrlLauncher());
    gh.lazySingleton<_i948.OAuthDeviceDescriptorProvider>(
      () => _i20.DesktopOAuthDeviceDescriptorProvider(
        gh<_i833.DeviceInfoPlugin>(),
      ),
    );
    return this;
  }
}

class _$RegisterModule extends _i893.RegisterModule {}
