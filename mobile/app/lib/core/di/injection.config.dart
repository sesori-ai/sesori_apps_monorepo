// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:firebase_crashlytics/firebase_crashlytics.dart' as _i141;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as _i163;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:http/http.dart' as _i519;
import 'package:injectable/injectable.dart' as _i526;
import 'package:record/record.dart' as _i1039;
import 'package:sesori_dart_core/sesori_dart_core.dart' as _i948;
import 'package:sesori_mobile/capabilities/voice/audio_format_config.dart'
    as _i430;
import 'package:sesori_mobile/capabilities/voice/recording_file_provider.dart'
    as _i62;
import 'package:sesori_mobile/capabilities/voice/voice_transcription_service.dart'
    as _i1038;
import 'package:sesori_mobile/capabilities/voice/wake_lock_service.dart'
    as _i511;
import 'package:sesori_mobile/core/di/register_module.dart' as _i124;
import 'package:sesori_mobile/core/platform/app_lifecycle_observer.dart'
    as _i875;
import 'package:sesori_mobile/core/platform/crashlytics_failure_reporter.dart'
    as _i534;
import 'package:sesori_mobile/core/platform/firebase_push_messaging_source.dart'
    as _i1042;
import 'package:sesori_mobile/core/platform/flutter_local_notification_client.dart'
    as _i636;
import 'package:sesori_mobile/core/platform/flutter_secure_storage_adapter.dart'
    as _i816;
import 'package:sesori_mobile/core/platform/flutter_url_launcher.dart' as _i10;
import 'package:sesori_mobile/core/platform/go_router_route_dispatcher.dart'
    as _i610;
import 'package:sesori_mobile/core/platform/go_router_route_source.dart'
    as _i597;
import 'package:sesori_mobile/core/routing/deep_link_service.dart' as _i901;
import 'package:sesori_mobile/core/routing/deep_link_source.dart' as _i919;
import 'package:sesori_shared/sesori_shared.dart' as _i553;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    gh.lazySingleton<_i430.AudioFormatConfig>(() => _i430.AudioFormatConfig());
    gh.lazySingleton<_i511.WakeLockService>(() => _i511.WakeLockService());
    gh.lazySingleton<_i519.Client>(() => registerModule.httpClient);
    gh.lazySingleton<_i553.RelayCryptoService>(
      () => registerModule.relayCryptoService,
    );
    gh.lazySingleton<_i1039.AudioRecorder>(() => registerModule.audioRecorder);
    gh.lazySingleton<_i163.FlutterLocalNotificationsPlugin>(
      () => registerModule.flutterLocalNotificationsPlugin,
    );
    gh.lazySingleton<_i558.FlutterSecureStorage>(
      () => registerModule.secureStorage,
    );
    gh.lazySingleton<_i141.FirebaseCrashlytics>(
      () => registerModule.firebaseCrashlytics,
    );
    gh.singleton<_i948.LifecycleSource>(() => _i875.AppLifecycleObserver());
    gh.singleton<_i948.RouteSource>(() => _i597.GoRouterRouteSource());
    gh.lazySingleton<_i948.LocalNotificationClient>(
      () => _i636.FlutterLocalNotificationClient(
        plugin: gh<_i163.FlutterLocalNotificationsPlugin>(),
      ),
    );
    gh.lazySingleton<_i948.NotificationCanceller>(
      () => registerModule.notificationCanceller(
        gh<_i948.LocalNotificationClient>(),
      ),
    );
    gh.lazySingleton<_i948.RouteDispatcher>(
      () => _i610.GoRouterRouteDispatcher(),
    );
    gh.lazySingleton<_i948.DeepLinkSource>(
      () => _i919.AppLinksDeepLinkSource(),
    );
    gh.lazySingleton<_i62.RecordingFileProvider>(
      () => _i62.RecordingFileProvider(gh<_i430.AudioFormatConfig>()),
    );
    gh.lazySingleton<_i948.PushMessagingSource>(
      () => _i1042.FirebasePushMessagingSource(),
    );
    gh.lazySingleton<_i948.SecureStorage>(
      () => _i816.FlutterSecureStorageAdapter(gh<_i558.FlutterSecureStorage>()),
    );
    gh.lazySingleton<_i948.UrlLauncher>(() => _i10.FlutterUrlLauncher());
    gh.lazySingleton<_i553.FailureReporter>(
      () => _i534.CrashlyticsFailureReporter(gh<_i141.FirebaseCrashlytics>()),
    );
    gh.lazySingleton<_i1038.VoiceTranscriptionService>(
      () => _i1038.VoiceTranscriptionService(
        gh<_i948.VoiceApi>(),
        gh<_i1039.AudioRecorder>(),
        gh<_i62.RecordingFileProvider>(),
        gh<_i511.WakeLockService>(),
        gh<_i430.AudioFormatConfig>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i901.DeepLinkService>(
      () => _i901.DeepLinkService(
        gh<_i948.OAuthCallbackDispatcher>(),
        gh<_i948.DeepLinkSource>(),
      ),
      dispose: (i) => i.dispose(),
    );
    return this;
  }
}

class _$RegisterModule extends _i124.RegisterModule {}
