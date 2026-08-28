// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:device_info_plus/device_info_plus.dart' as _i833;
import 'package:firebase_analytics/firebase_analytics.dart' as _i398;
import 'package:firebase_core/firebase_core.dart' as _i982;
import 'package:firebase_crashlytics/firebase_crashlytics.dart' as _i141;
import 'package:firebase_messaging/firebase_messaging.dart' as _i892;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as _i163;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:http/http.dart' as _i519;
import 'package:image_picker/image_picker.dart' as _i183;
import 'package:injectable/injectable.dart' as _i526;
import 'package:sesori_dart_core/sesori_dart_core.dart' as _i948;
import 'package:sesori_mobile/capabilities/media/composer_image_picker.dart'
    as _i140;
import 'package:sesori_mobile/capabilities/voice/audio_format_config.dart'
    as _i430;
import 'package:sesori_mobile/capabilities/voice/recorder_prewarm_client.dart'
    as _i361;
import 'package:sesori_mobile/capabilities/voice/recording_file_provider.dart'
    as _i62;
import 'package:sesori_mobile/capabilities/voice/wake_lock_service.dart'
    as _i511;
import 'package:sesori_mobile/core/di/firebase_register_module.dart' as _i677;
import 'package:sesori_mobile/core/di/register_module.dart' as _i124;
import 'package:sesori_mobile/core/platform/app_lifecycle_observer.dart'
    as _i875;
import 'package:sesori_mobile/core/platform/crashlytics_failure_reporter.dart'
    as _i534;
import 'package:sesori_mobile/core/platform/file_save_client.dart' as _i223;
import 'package:sesori_mobile/core/platform/firebase/firebase_messaging_static_adapter.dart'
    as _i178;
import 'package:sesori_mobile/core/platform/firebase/no_op_analytics_client.dart'
    as _i901;
import 'package:sesori_mobile/core/platform/firebase/no_op_failure_reporter.dart'
    as _i52;
import 'package:sesori_mobile/core/platform/firebase/no_op_push_messaging_source.dart'
    as _i483;
import 'package:sesori_mobile/core/platform/firebase_analytics_client.dart'
    as _i326;
import 'package:sesori_mobile/core/platform/firebase_analytics_startup.dart'
    as _i950;
import 'package:sesori_mobile/core/platform/firebase_push_messaging_source.dart'
    as _i1042;
import 'package:sesori_mobile/core/platform/flutter_attachment_thumbnail_storage.dart'
    as _i963;
import 'package:sesori_mobile/core/platform/flutter_image_clipboard.dart'
    as _i274;
import 'package:sesori_mobile/core/platform/flutter_image_sharer.dart' as _i617;
import 'package:sesori_mobile/core/platform/flutter_local_notification_client.dart'
    as _i636;
import 'package:sesori_mobile/core/platform/flutter_oauth_device_descriptor_provider.dart'
    as _i363;
import 'package:sesori_mobile/core/platform/flutter_secure_storage_adapter.dart'
    as _i816;
import 'package:sesori_mobile/core/platform/flutter_url_launcher.dart' as _i10;
import 'package:sesori_mobile/core/platform/flutter_voice_capture.dart'
    as _i698;
import 'package:sesori_mobile/core/platform/gal_client.dart' as _i227;
import 'package:sesori_mobile/core/platform/go_router_route_dispatcher.dart'
    as _i610;
import 'package:sesori_mobile/core/platform/go_router_route_source.dart'
    as _i597;
import 'package:sesori_mobile/core/platform/io_realtime_websocket_connector.dart'
    as _i292;
import 'package:sesori_mobile/core/platform/pasteboard_client.dart' as _i748;
import 'package:sesori_mobile/core/platform/share_plus_client.dart' as _i1019;
import 'package:sesori_mobile/core/platform/singular/singular_attribution_client.dart'
    as _i681;
import 'package:sesori_mobile/core/platform/singular/singular_static_adapter.dart'
    as _i776;
import 'package:sesori_mobile/core/platform/singular_attribution_startup.dart'
    as _i853;
import 'package:sesori_mobile/core/platform/temporary_directory_client.dart'
    as _i908;
import 'package:sesori_mobile/core/routing/deep_link_service.dart' as _i902;
import 'package:sesori_mobile/core/routing/deep_link_source.dart' as _i919;
import 'package:sesori_shared/sesori_shared.dart' as _i553;

const String _firebaseEnabled = 'firebaseEnabled';
const String _firebaseDisabled = 'firebaseDisabled';

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    final firebaseRegisterModule = _$FirebaseRegisterModule();
    gh.lazySingleton<_i430.AudioFormatConfig>(() => _i430.AudioFormatConfig());
    gh.lazySingleton<_i361.RecorderPrewarmClient>(
      () => _i361.RecorderPrewarmClient(),
    );
    gh.lazySingleton<_i511.WakeLockService>(() => _i511.WakeLockService());
    gh.lazySingleton<_i519.Client>(() => registerModule.httpClient);
    gh.lazySingleton<_i553.RelayCryptoService>(
      () => registerModule.relayCryptoService,
    );
    gh.lazySingleton<_i183.ImagePicker>(() => registerModule.imagePicker);
    gh.lazySingleton<_i163.FlutterLocalNotificationsPlugin>(
      () => registerModule.flutterLocalNotificationsPlugin,
    );
    gh.lazySingleton<_i833.DeviceInfoPlugin>(
      () => registerModule.deviceInfoPlugin,
    );
    gh.lazySingleton<_i558.FlutterSecureStorage>(
      () => registerModule.secureStorage,
    );
    gh.lazySingleton<_i223.FileSaveClient>(() => _i223.FileSaveClient());
    gh.lazySingleton<_i227.GalClient>(() => _i227.GalClient());
    gh.lazySingleton<_i292.IoRealtimeWebSocketClient>(
      () => _i292.IoRealtimeWebSocketClient(),
    );
    gh.lazySingleton<_i748.PasteboardClient>(() => _i748.PasteboardClient());
    gh.lazySingleton<_i1019.SharePlusClient>(() => _i1019.SharePlusClient());
    gh.lazySingleton<_i776.SingularStaticAdapter>(
      () => _i776.SingularStaticAdapter(),
    );
    gh.lazySingleton<_i908.TemporaryDirectoryClient>(
      () => _i908.TemporaryDirectoryClient(),
    );
    gh.lazySingleton<_i948.OAuthDeviceDescriptorProvider>(
      () => _i363.FlutterOAuthDeviceDescriptorProvider(
        gh<_i833.DeviceInfoPlugin>(),
      ),
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
    gh.lazySingleton<_i948.SecureStorage>(
      () => _i816.FlutterSecureStorageAdapter(gh<_i558.FlutterSecureStorage>()),
    );
    gh.lazySingleton<_i948.DeepLinkSource>(
      () => _i919.AppLinksDeepLinkSource(),
    );
    gh.lazySingleton<_i140.ComposerImagePicker>(
      () => _i140.ComposerImagePicker(picker: gh<_i183.ImagePicker>()),
    );
    gh.lazySingleton<_i948.UrlLauncher>(() => _i10.FlutterUrlLauncher());
    gh.lazySingleton<_i982.FirebaseApp>(
      () => firebaseRegisterModule.enabledFirebaseApp,
      registerFor: {_firebaseEnabled},
    );
    gh.lazySingleton<_i892.FirebaseMessaging>(
      () => firebaseRegisterModule.enabledFirebaseMessaging,
      registerFor: {_firebaseEnabled},
    );
    gh.lazySingleton<_i398.FirebaseAnalytics>(
      () => firebaseRegisterModule.enabledFirebaseAnalytics,
      registerFor: {_firebaseEnabled},
    );
    gh.lazySingleton<_i141.FirebaseCrashlytics>(
      () => firebaseRegisterModule.enabledFirebaseCrashlytics,
      registerFor: {_firebaseEnabled},
    );
    gh.lazySingleton<_i178.FirebaseMessagingStaticAdapter>(
      () => firebaseRegisterModule.enabledFirebaseMessagingStaticAdapter,
      registerFor: {_firebaseEnabled},
    );
    gh.lazySingleton<_i178.FirebaseMessagingStaticAdapter>(
      () => firebaseRegisterModule.disabledFirebaseMessagingStaticAdapter,
      registerFor: {_firebaseDisabled},
    );
    gh.lazySingleton<_i853.SingularAttributionStartup>(
      () => _i853.SingularAttributionStartup(
        singular: gh<_i776.SingularStaticAdapter>(),
      ),
    );
    gh.lazySingleton<_i948.AnalyticsClient>(
      () => _i901.NoOpAnalyticsClient(),
      registerFor: {_firebaseDisabled},
    );
    gh.lazySingleton<_i950.FirebaseAnalyticsStartup>(
      () => _i950.FirebaseAnalyticsStartup(
        analytics: gh<_i398.FirebaseAnalytics>(),
      ),
      registerFor: {_firebaseEnabled},
    );
    gh.lazySingleton<_i948.AttachmentThumbnailStorage>(
      () => _i963.FlutterAttachmentThumbnailStorage(
        temporaryDirectoryClient: gh<_i908.TemporaryDirectoryClient>(),
      ),
    );
    gh.lazySingleton<_i553.FailureReporter>(
      () => _i534.CrashlyticsFailureReporter(gh<_i141.FirebaseCrashlytics>()),
      registerFor: {_firebaseEnabled},
    );
    gh.lazySingleton<_i948.AnalyticsClient>(
      () => _i326.FirebaseAnalyticsClient(
        analytics: gh<_i398.FirebaseAnalytics>(),
        capability: gh<_i948.AnalyticsRuntimeCapability>(),
        startup: gh<_i950.FirebaseAnalyticsStartup>(),
      ),
      registerFor: {_firebaseEnabled},
    );
    gh.lazySingleton<_i948.PushMessagingSource>(
      () => _i483.NoOpPushMessagingSource(),
      registerFor: {_firebaseDisabled},
    );
    gh.lazySingleton<_i948.ImageSaver>(
      () => registerModule.imageSaver(
        galClient: gh<_i227.GalClient>(),
        fileSaveClient: gh<_i223.FileSaveClient>(),
      ),
    );
    gh.lazySingleton<_i948.PushMessagingSource>(
      () => _i1042.FirebasePushMessagingSource(
        messaging: gh<_i892.FirebaseMessaging>(),
        staticAdapter: gh<_i178.FirebaseMessagingStaticAdapter>(),
      ),
      registerFor: {_firebaseEnabled},
    );
    gh.lazySingleton<_i62.RecordingFileProvider>(
      () => _i62.RecordingFileProvider(
        audioFormat: gh<_i430.AudioFormatConfig>(),
        temporaryDirectoryClient: gh<_i908.TemporaryDirectoryClient>(),
      ),
    );
    gh.lazySingleton<_i948.RealtimeWebSocketConnector>(
      () => _i292.IoRealtimeWebSocketConnector(
        client: gh<_i292.IoRealtimeWebSocketClient>(),
      ),
    );
    gh.lazySingleton<_i948.ImageClipboard>(
      () => _i274.FlutterImageClipboard(
        pasteboardClient: gh<_i748.PasteboardClient>(),
      ),
    );
    gh.lazySingleton<_i948.ImageSharer>(
      () => _i617.FlutterImageSharer(
        sharePlusClient: gh<_i1019.SharePlusClient>(),
      ),
    );
    gh.lazySingleton<_i553.FailureReporter>(
      () => _i52.NoOpFailureReporter(),
      registerFor: {_firebaseDisabled},
    );
    gh.lazySingleton<_i902.DeepLinkService>(
      () => _i902.DeepLinkService(gh<_i948.DeepLinkSource>()),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i948.AttributionClient>(
      () => _i681.SingularAttributionClient(
        startup: gh<_i853.SingularAttributionStartup>(),
        singular: gh<_i776.SingularStaticAdapter>(),
      ),
    );
    gh.lazySingleton<_i948.VoiceCapture>(
      () => _i698.FlutterVoiceCapture(
        recorderPrewarmClient: gh<_i361.RecorderPrewarmClient>(),
        fileProvider: gh<_i62.RecordingFileProvider>(),
        wakeLockService: gh<_i511.WakeLockService>(),
        audioFormat: gh<_i430.AudioFormatConfig>(),
      ),
    );
    return this;
  }
}

class _$RegisterModule extends _i124.RegisterModule {}

class _$FirebaseRegisterModule extends _i677.FirebaseRegisterModule {}
