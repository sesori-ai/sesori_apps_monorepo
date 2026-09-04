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
import 'package:sesori_auth/sesori_auth.dart' as _i442;
import 'package:sesori_dart_core/src/api/analytics_api.dart' as _i727;
import 'package:sesori_dart_core/src/api/analytics_release_cutoff_api.dart'
    as _i649;
import 'package:sesori_dart_core/src/api/attribution_api.dart' as _i556;
import 'package:sesori_dart_core/src/api/bridge_api.dart' as _i384;
import 'package:sesori_dart_core/src/api/bridge_settings_api.dart' as _i415;
import 'package:sesori_dart_core/src/api/client/relay_http_client.dart'
    as _i857;
import 'package:sesori_dart_core/src/api/filesystem_api.dart' as _i1068;
import 'package:sesori_dart_core/src/api/installed_app_build_api.dart' as _i258;
import 'package:sesori_dart_core/src/api/legal_api.dart' as _i835;
import 'package:sesori_dart_core/src/api/message_image_api.dart' as _i938;
import 'package:sesori_dart_core/src/api/notification_api.dart' as _i400;
import 'package:sesori_dart_core/src/api/notification_preferences_api.dart'
    as _i396;
import 'package:sesori_dart_core/src/api/permission_api.dart' as _i231;
import 'package:sesori_dart_core/src/api/plugin_api.dart' as _i546;
import 'package:sesori_dart_core/src/api/plugin_preference_api.dart' as _i958;
import 'package:sesori_dart_core/src/api/product_analytics_preference_api.dart'
    as _i560;
import 'package:sesori_dart_core/src/api/project_api.dart' as _i733;
import 'package:sesori_dart_core/src/api/session_api.dart' as _i603;
import 'package:sesori_dart_core/src/api/storage/composer_draft_storage.dart'
    as _i64;
import 'package:sesori_dart_core/src/api/storage/notification_preferences_device_id_storage.dart'
    as _i407;
import 'package:sesori_dart_core/src/api/storage/product_analytics_preference_storage.dart'
    as _i197;
import 'package:sesori_dart_core/src/api/view_declaration_api.dart' as _i37;
import 'package:sesori_dart_core/src/capabilities/relay/room_key_storage.dart'
    as _i895;
import 'package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart'
    as _i369;
import 'package:sesori_dart_core/src/capabilities/voice/voice_api.dart'
    as _i176;
import 'package:sesori_dart_core/src/foundation/models/product_analytics/analytics_runtime_capability.dart'
    as _i684;
import 'package:sesori_dart_core/src/foundation/platform/analytics_client.dart'
    as _i791;
import 'package:sesori_dart_core/src/foundation/platform/analytics_release_cutoff_source.dart'
    as _i345;
import 'package:sesori_dart_core/src/foundation/platform/attachment_thumbnail_storage.dart'
    as _i894;
import 'package:sesori_dart_core/src/foundation/platform/attribution_claim_storage.dart'
    as _i275;
import 'package:sesori_dart_core/src/foundation/platform/attribution_client.dart'
    as _i14;
import 'package:sesori_dart_core/src/foundation/platform/composer_image_picker.dart'
    as _i65;
import 'package:sesori_dart_core/src/foundation/platform/installed_app_build_source.dart'
    as _i957;
import 'package:sesori_dart_core/src/platform/lifecycle_source.dart' as _i903;
import 'package:sesori_dart_core/src/platform/local_notification_client.dart'
    as _i1037;
import 'package:sesori_dart_core/src/platform/push_messaging_source.dart'
    as _i330;
import 'package:sesori_dart_core/src/platform/route_dispatcher.dart' as _i951;
import 'package:sesori_dart_core/src/platform/route_source.dart' as _i366;
import 'package:sesori_dart_core/src/platform/voice_capture.dart' as _i359;
import 'package:sesori_dart_core/src/repositories/analytics_release_cutoff_repository.dart'
    as _i672;
import 'package:sesori_dart_core/src/repositories/analytics_repository.dart'
    as _i274;
import 'package:sesori_dart_core/src/repositories/appearance_store.dart'
    as _i209;
import 'package:sesori_dart_core/src/repositories/attribution_repository.dart'
    as _i993;
import 'package:sesori_dart_core/src/repositories/bridge_repository.dart'
    as _i205;
import 'package:sesori_dart_core/src/repositories/bridge_settings_repository.dart'
    as _i102;
import 'package:sesori_dart_core/src/repositories/chat_input_mode_store.dart'
    as _i901;
import 'package:sesori_dart_core/src/repositories/composer_draft_repository.dart'
    as _i198;
import 'package:sesori_dart_core/src/repositories/installed_app_build_repository.dart'
    as _i507;
import 'package:sesori_dart_core/src/repositories/legal_repository.dart'
    as _i933;
import 'package:sesori_dart_core/src/repositories/message_image_repository.dart'
    as _i531;
import 'package:sesori_dart_core/src/repositories/notification_preferences_repository.dart'
    as _i458;
import 'package:sesori_dart_core/src/repositories/notification_repository.dart'
    as _i471;
import 'package:sesori_dart_core/src/repositories/permission_repository.dart'
    as _i679;
import 'package:sesori_dart_core/src/repositories/plugin_preference_repository.dart'
    as _i594;
import 'package:sesori_dart_core/src/repositories/plugin_repository.dart'
    as _i337;
import 'package:sesori_dart_core/src/repositories/product_analytics_preference_repository.dart'
    as _i804;
import 'package:sesori_dart_core/src/repositories/project_repository.dart'
    as _i80;
import 'package:sesori_dart_core/src/repositories/registered_bridges_store.dart'
    as _i217;
import 'package:sesori_dart_core/src/repositories/session_repository.dart'
    as _i7;
import 'package:sesori_dart_core/src/repositories/view_declaration_repository.dart'
    as _i143;
import 'package:sesori_dart_core/src/repositories/voice_repository.dart'
    as _i107;
import 'package:sesori_dart_core/src/routing/analytics_route_listener.dart'
    as _i888;
import 'package:sesori_dart_core/src/routing/notification_open_dispatcher.dart'
    as _i516;
import 'package:sesori_dart_core/src/services/analytics_crawl_gate_service.dart'
    as _i317;
import 'package:sesori_dart_core/src/services/attribution_service.dart'
    as _i492;
import 'package:sesori_dart_core/src/services/catalog_rescan_service.dart'
    as _i572;
import 'package:sesori_dart_core/src/services/composer_attachment_dispatcher.dart'
    as _i705;
import 'package:sesori_dart_core/src/services/foreground_notification_dispatcher.dart'
    as _i101;
import 'package:sesori_dart_core/src/services/installation_analytics_service.dart'
    as _i285;
import 'package:sesori_dart_core/src/services/message_thumbnail_cache_service.dart'
    as _i72;
import 'package:sesori_dart_core/src/services/new_session_options_service.dart'
    as _i74;
import 'package:sesori_dart_core/src/services/new_session_plugin_service.dart'
    as _i177;
import 'package:sesori_dart_core/src/services/new_session_selection_tracker.dart'
    as _i913;
import 'package:sesori_dart_core/src/services/notification_preferences_service.dart'
    as _i906;
import 'package:sesori_dart_core/src/services/notification_registration_service.dart'
    as _i659;
import 'package:sesori_dart_core/src/services/plugin_management_service.dart'
    as _i110;
import 'package:sesori_dart_core/src/services/product_analytics_preference_service.dart'
    as _i555;
import 'package:sesori_dart_core/src/services/product_analytics_service.dart'
    as _i204;
import 'package:sesori_dart_core/src/services/project_list_service.dart'
    as _i703;
import 'package:sesori_dart_core/src/services/project_viewing_service.dart'
    as _i413;
import 'package:sesori_dart_core/src/services/registered_bridges_service.dart'
    as _i699;
import 'package:sesori_dart_core/src/services/session_activity_calculator.dart'
    as _i84;
import 'package:sesori_dart_core/src/services/session_detail_load_service.dart'
    as _i709;
import 'package:sesori_dart_core/src/services/session_list_service.dart'
    as _i763;
import 'package:sesori_dart_core/src/services/session_unseen_tracker.dart'
    as _i28;
import 'package:sesori_dart_core/src/services/session_viewing_service.dart'
    as _i18;
import 'package:sesori_dart_core/src/services/sse_event_tracker.dart' as _i508;
import 'package:sesori_dart_core/src/services/voice_transcription_service.dart'
    as _i680;
import 'package:sesori_shared/sesori_shared.dart' as _i553;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.lazySingleton<_i64.ComposerDraftStorage>(
      () => _i64.ComposerDraftStorage(),
    );
    gh.lazySingleton<_i913.NewSessionSelectionTracker>(
      () => _i913.NewSessionSelectionTracker(),
    );
    gh.lazySingleton<_i84.SessionActivityCalculator>(
      () => const _i84.SessionActivityCalculator(),
    );
    gh.lazySingleton<_i176.VoiceApi>(
      () => _i176.VoiceApi(gh<_i442.AuthenticatedHttpApiClient>()),
    );
    gh.lazySingleton<_i705.ComposerAttachmentDispatcher>(
      () => _i705.ComposerAttachmentDispatcher(
        imagePicker: gh<_i65.ComposerImagePicker>(),
      ),
    );
    gh.lazySingleton<_i384.BridgeApi>(
      () => _i384.BridgeApi(client: gh<_i442.AuthenticatedHttpApiClient>()),
    );
    gh.lazySingleton<_i400.NotificationApi>(
      () =>
          _i400.NotificationApi(client: gh<_i442.AuthenticatedHttpApiClient>()),
    );
    gh.lazySingleton<_i396.NotificationPreferencesApi>(
      () => _i396.NotificationPreferencesApi(
        client: gh<_i442.AuthenticatedHttpApiClient>(),
      ),
    );
    gh.lazySingleton<_i560.ProductAnalyticsPreferenceApi>(
      () => _i560.ProductAnalyticsPreferenceApi(
        client: gh<_i442.AuthenticatedHttpApiClient>(),
      ),
    );
    gh.lazySingleton<_i727.AnalyticsApi>(
      () => _i727.AnalyticsApi(client: gh<_i791.AnalyticsClient>()),
    );
    gh.lazySingleton<_i107.VoiceRepository>(
      () => _i107.VoiceRepository(api: gh<_i176.VoiceApi>()),
    );
    gh.lazySingleton<_i198.ComposerDraftRepository>(
      () => _i198.ComposerDraftRepository(
        storage: gh<_i64.ComposerDraftStorage>(),
      ),
    );
    gh.lazySingleton<_i209.AppearanceStore>(
      () => _i209.AppearanceStore(secureStorage: gh<_i442.SecureStorage>()),
    );
    gh.lazySingleton<_i901.ChatInputModeStore>(
      () => _i901.ChatInputModeStore(secureStorage: gh<_i442.SecureStorage>()),
    );
    gh.lazySingleton<_i258.InstalledAppBuildApi>(
      () => _i258.InstalledAppBuildApi(
        source: gh<_i957.InstalledAppBuildSource>(),
      ),
    );
    gh.lazySingleton<_i556.AttributionApi>(
      () => _i556.AttributionApi(client: gh<_i14.AttributionClient>()),
    );
    gh.lazySingleton<_i938.MessageImageApi>(
      () => _i938.MessageImageApi(client: gh<_i519.Client>()),
    );
    gh.lazySingleton<_i835.LegalApi>(
      () => _i835.LegalApi(client: gh<_i442.HttpApiClient>()),
    );
    gh.lazySingleton<_i274.AnalyticsRepository>(
      () => _i274.AnalyticsRepository(api: gh<_i727.AnalyticsApi>()),
    );
    gh.lazySingleton<_i958.PluginPreferenceApi>(
      () => _i958.PluginPreferenceApi(storage: gh<_i442.SecureStorage>()),
    );
    gh.lazySingleton<_i407.NotificationPreferencesDeviceIdStorage>(
      () => _i407.NotificationPreferencesDeviceIdStorage(
        storage: gh<_i442.SecureStorage>(),
      ),
    );
    gh.lazySingleton<_i197.ProductAnalyticsPreferenceStorage>(
      () => _i197.ProductAnalyticsPreferenceStorage(
        storage: gh<_i442.SecureStorage>(),
      ),
    );
    gh.lazySingleton<_i516.NotificationOpenDispatcher>(
      () => _i516.NotificationOpenDispatcher(
        authSession: gh<_i442.AuthSession>(),
        pushMessagingSource: gh<_i330.PushMessagingSource>(),
        localNotificationClient: gh<_i1037.LocalNotificationClient>(),
        routeDispatcher: gh<_i951.RouteDispatcher>(),
        routeSource: gh<_i366.RouteSource>(),
      ),
    );
    gh.lazySingleton<_i507.InstalledAppBuildRepository>(
      () => _i507.InstalledAppBuildRepository(
        api: gh<_i258.InstalledAppBuildApi>(),
      ),
    );
    gh.lazySingleton<_i649.AnalyticsReleaseCutoffApi>(
      () => _i649.AnalyticsReleaseCutoffApi(
        source: gh<_i345.AnalyticsReleaseCutoffSource>(),
      ),
    );
    gh.lazySingleton<_i895.RoomKeyStorage>(
      () => _i895.RoomKeyStorage(gh<_i442.SecureStorage>()),
    );
    gh.lazySingleton<_i205.BridgeRepository>(
      () => _i205.BridgeRepository(api: gh<_i384.BridgeApi>()),
    );
    gh.lazySingleton<_i217.RegisteredBridgesStore>(
      () => _i217.RegisteredBridgesStore(
        secureStorage: gh<_i442.SecureStorage>(),
        authSession: gh<_i442.AuthSession>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i369.ConnectionService>(
      () => _i369.ConnectionService(
        gh<_i553.RelayCryptoService>(),
        gh<_i895.RoomKeyStorage>(),
        gh<_i442.AuthTokenProvider>(),
        gh<_i442.AuthSession>(),
        gh<_i903.LifecycleSource>(),
        gh<_i553.FailureReporter>(),
      ),
    );
    gh.lazySingleton<_i933.LegalRepository>(
      () => _i933.LegalRepository(api: gh<_i835.LegalApi>()),
    );
    gh.lazySingleton<_i594.PluginPreferenceRepository>(
      () => _i594.PluginPreferenceRepository(
        api: gh<_i958.PluginPreferenceApi>(),
      ),
    );
    gh.lazySingleton<_i471.NotificationRepository>(
      () => _i471.NotificationRepository(
        api: gh<_i400.NotificationApi>(),
        deviceIdStorage: gh<_i407.NotificationPreferencesDeviceIdStorage>(),
      ),
    );
    gh.lazySingleton<_i804.ProductAnalyticsPreferenceRepository>(
      () => _i804.ProductAnalyticsPreferenceRepository(
        api: gh<_i560.ProductAnalyticsPreferenceApi>(),
        storage: gh<_i197.ProductAnalyticsPreferenceStorage>(),
      ),
    );
    gh.lazySingleton<_i993.AttributionRepository>(
      () => _i993.AttributionRepository(
        api: gh<_i556.AttributionApi>(),
        claimStorage: gh<_i275.AttributionClaimStorage>(),
      ),
    );
    gh.lazySingleton<_i37.ViewDeclarationApi>(
      () => _i37.ViewDeclarationApi(
        connectionService: gh<_i369.ConnectionService>(),
      ),
    );
    gh.lazySingleton<_i555.ProductAnalyticsPreferenceService>(
      () => _i555.ProductAnalyticsPreferenceService(
        capability: gh<_i684.AnalyticsRuntimeCapability>(),
        authSession: gh<_i442.AuthSession>(),
        preferenceRepository: gh<_i804.ProductAnalyticsPreferenceRepository>(),
      ),
    );
    gh.lazySingleton<_i458.NotificationPreferencesRepository>(
      () => _i458.NotificationPreferencesRepository(
        api: gh<_i396.NotificationPreferencesApi>(),
        deviceIdStorage: gh<_i407.NotificationPreferencesDeviceIdStorage>(),
      ),
    );
    gh.lazySingleton<_i659.NotificationRegistrationService>(
      () => _i659.NotificationRegistrationService(
        repository: gh<_i471.NotificationRepository>(),
        authSession: gh<_i442.AuthSession>(),
        pushMessagingSource: gh<_i330.PushMessagingSource>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i906.NotificationPreferencesService>(
      () => _i906.NotificationPreferencesService(
        authSession: gh<_i442.AuthSession>(),
        repository: gh<_i458.NotificationPreferencesRepository>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i672.AnalyticsReleaseCutoffRepository>(
      () => _i672.AnalyticsReleaseCutoffRepository(
        api: gh<_i649.AnalyticsReleaseCutoffApi>(),
      ),
    );
    gh.lazySingleton<_i101.ForegroundNotificationDispatcher>(
      () => _i101.ForegroundNotificationDispatcher(
        notificationPreferencesService:
            gh<_i906.NotificationPreferencesService>(),
        localNotificationClient: gh<_i1037.LocalNotificationClient>(),
        pushMessagingSource: gh<_i330.PushMessagingSource>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i28.SessionUnseenTracker>(
      () => _i28.SessionUnseenTracker(
        gh<_i369.ConnectionService>(),
        failureReporter: gh<_i553.FailureReporter>(),
      ),
    );
    gh.lazySingleton<_i857.RelayHttpApiClient>(
      () => _i857.RelayHttpApiClient(gh<_i369.ConnectionService>()),
    );
    gh.lazySingleton<_i317.AnalyticsCrawlGateService>(
      () => _i317.AnalyticsCrawlGateService(
        authSession: gh<_i442.AuthSession>(),
        releaseCutoffRepository: gh<_i672.AnalyticsReleaseCutoffRepository>(),
        installedAppBuildRepository: gh<_i507.InstalledAppBuildRepository>(),
      ),
    );
    gh.lazySingleton<_i415.BridgeSettingsApi>(
      () => _i415.BridgeSettingsApi(client: gh<_i857.RelayHttpApiClient>()),
    );
    gh.lazySingleton<_i1068.FilesystemApi>(
      () => _i1068.FilesystemApi(client: gh<_i857.RelayHttpApiClient>()),
    );
    gh.lazySingleton<_i231.PermissionApi>(
      () => _i231.PermissionApi(client: gh<_i857.RelayHttpApiClient>()),
    );
    gh.lazySingleton<_i546.PluginApi>(
      () => _i546.PluginApi(client: gh<_i857.RelayHttpApiClient>()),
    );
    gh.lazySingleton<_i733.ProjectApi>(
      () => _i733.ProjectApi(client: gh<_i857.RelayHttpApiClient>()),
    );
    gh.lazySingleton<_i603.SessionApi>(
      () => _i603.SessionApi(client: gh<_i857.RelayHttpApiClient>()),
    );
    gh.lazySingleton<_i143.ViewDeclarationRepository>(
      () => _i143.ViewDeclarationRepository(api: gh<_i37.ViewDeclarationApi>()),
    );
    gh.lazySingleton<_i508.SseEventTracker>(
      () => _i508.SseEventTracker(
        gh<_i369.ConnectionService>(),
        failureReporter: gh<_i553.FailureReporter>(),
      ),
    );
    gh.lazySingleton<_i699.RegisteredBridgesService>(
      () => _i699.RegisteredBridgesService(
        bridgeRepository: gh<_i205.BridgeRepository>(),
        registeredBridgesStore: gh<_i217.RegisteredBridgesStore>(),
        connectionService: gh<_i369.ConnectionService>(),
        authSession: gh<_i442.AuthSession>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i204.ProductAnalyticsService>(
      () => _i204.ProductAnalyticsService(
        analyticsRepository: gh<_i274.AnalyticsRepository>(),
        attributionRepository: gh<_i993.AttributionRepository>(),
        preferenceService: gh<_i555.ProductAnalyticsPreferenceService>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i285.InstallationAnalyticsService>(
      () => _i285.InstallationAnalyticsService(
        capability: gh<_i684.AnalyticsRuntimeCapability>(),
        repository: gh<_i274.AnalyticsRepository>(),
        attributionRepository: gh<_i993.AttributionRepository>(),
      ),
    );
    gh.lazySingleton<_i492.AttributionService>(
      () => _i492.AttributionService(
        repository: gh<_i993.AttributionRepository>(),
        connectionService: gh<_i369.ConnectionService>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i7.SessionRepository>(
      () => _i7.SessionRepository(api: gh<_i603.SessionApi>()),
    );
    gh.lazySingleton<_i337.PluginRepository>(
      () => _i337.PluginRepository(api: gh<_i546.PluginApi>()),
    );
    gh.lazySingleton<_i413.ProjectViewingService>(
      () => _i413.ProjectViewingService(
        viewRepository: gh<_i143.ViewDeclarationRepository>(),
        lifecycleSource: gh<_i903.LifecycleSource>(),
        connectionService: gh<_i369.ConnectionService>(),
        routeSource: gh<_i366.RouteSource>(),
      ),
    );
    gh.lazySingleton<_i102.BridgeSettingsRepository>(
      () => _i102.BridgeSettingsRepository(
        bridgeSettingsApi: gh<_i415.BridgeSettingsApi>(),
      ),
    );
    gh.lazySingleton<_i74.NewSessionOptionsService>(
      () => _i74.NewSessionOptionsService(
        sessionRepository: gh<_i7.SessionRepository>(),
      ),
    );
    gh.lazySingleton<_i18.SessionViewingService>(
      () => _i18.SessionViewingService(
        viewRepository: gh<_i143.ViewDeclarationRepository>(),
        lifecycleSource: gh<_i903.LifecycleSource>(),
      ),
    );
    gh.lazySingleton<_i531.MessageImageRepository>(
      () => _i531.MessageImageRepository(
        api: gh<_i938.MessageImageApi>(),
        sessionApi: gh<_i603.SessionApi>(),
        authSession: gh<_i442.AuthSession>(),
        attachmentThumbnailStorage: gh<_i894.AttachmentThumbnailStorage>(),
      ),
    );
    gh.lazySingleton<_i679.PermissionRepository>(
      () => _i679.PermissionRepository(api: gh<_i231.PermissionApi>()),
    );
    gh.lazySingleton<_i80.ProjectRepository>(
      () => _i80.ProjectRepository(
        api: gh<_i733.ProjectApi>(),
        filesystemApi: gh<_i1068.FilesystemApi>(),
        sessionApi: gh<_i603.SessionApi>(),
      ),
    );
    gh.lazySingleton<_i177.NewSessionPluginService>(
      () => _i177.NewSessionPluginService(
        pluginRepository: gh<_i337.PluginRepository>(),
        pluginPreferenceRepository: gh<_i594.PluginPreferenceRepository>(),
      ),
    );
    gh.lazySingleton<_i703.ProjectListService>(
      () => _i703.ProjectListService(
        repository: gh<_i80.ProjectRepository>(),
        activityCalculator: gh<_i84.SessionActivityCalculator>(),
      ),
    );
    gh.lazySingleton<_i763.SessionListService>(
      () => _i763.SessionListService(
        repository: gh<_i80.ProjectRepository>(),
        activityCalculator: gh<_i84.SessionActivityCalculator>(),
      ),
    );
    gh.lazySingleton<_i888.AnalyticsRouteListener>(
      () => _i888.AnalyticsRouteListener(
        routeSource: gh<_i366.RouteSource>(),
        analyticsService: gh<_i204.ProductAnalyticsService>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i680.VoiceTranscriptionService>(
      () => _i680.VoiceTranscriptionService(
        repository: gh<_i107.VoiceRepository>(),
        projectRepository: gh<_i80.ProjectRepository>(),
        capture: gh<_i359.VoiceCapture>(),
      ),
    );
    gh.lazySingleton<_i110.PluginManagementService>(
      () => _i110.PluginManagementService(
        pluginRepository: gh<_i337.PluginRepository>(),
        connectionService: gh<_i369.ConnectionService>(),
        productAnalyticsService: gh<_i204.ProductAnalyticsService>(),
      ),
    );
    gh.lazySingleton<_i709.SessionDetailLoadService>(
      () => _i709.SessionDetailLoadService(
        repository: gh<_i7.SessionRepository>(),
        projectRepository: gh<_i80.ProjectRepository>(),
        pluginRepository: gh<_i337.PluginRepository>(),
        connectionService: gh<_i369.ConnectionService>(),
      ),
    );
    gh.lazySingleton<_i72.MessageThumbnailCacheService>(
      () => _i72.MessageThumbnailCacheService(
        repository: gh<_i531.MessageImageRepository>(),
        authSession: gh<_i442.AuthSession>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i572.CatalogRescanService>(
      () => _i572.CatalogRescanService(
        pluginRepository: gh<_i337.PluginRepository>(),
        managementService: gh<_i110.PluginManagementService>(),
        connectionService: gh<_i369.ConnectionService>(),
      ),
    );
    return this;
  }
}
