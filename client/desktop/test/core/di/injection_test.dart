import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/di/injection.dart";
import "package:sesori_desktop/core/platform/desktop_active_bridge_locality.dart";
import "package:sesori_desktop/core/platform/desktop_composer_image_picker.dart";
import "package:sesori_desktop/core/platform/desktop_failure_reporter.dart";
import "package:sesori_desktop/core/platform/desktop_file_image_saver.dart";
import "package:sesori_desktop/core/platform/desktop_image_clipboard.dart";
import "package:sesori_desktop/core/platform/desktop_image_sharer.dart";
import "package:sesori_desktop/core/platform/desktop_route_source.dart";
import "package:sesori_desktop/core/platform/no_op_analytics_client.dart";
import "package:sesori_desktop/core/platform/no_op_feedback_prompt_config_source.dart";
import "package:sesori_desktop/core/platform/path_provider_temporary_directory_provider.dart";
import "package:sesori_desktop/core/routing/desktop_router.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:sesori_shared/sesori_shared.dart";

class _FixtureDirectory({required final Directory root}) implements PersistenceDirectory {
  @override
  Future<Directory> resolve() async => root;
}

class _FixtureMasterStore() implements MasterKeyStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write({required String value}) async => this.value = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp("sesori-desktop-di-");
    getIt.skipDoubleRegistration = true;
    getIt.registerSingleton<PersistenceDirectory>(_FixtureDirectory(root: root));
    getIt.registerSingleton<MasterKeyStore>(_FixtureMasterStore());
  });
  tearDown(() async {
    await getIt.reset();
    getIt.skipDoubleRegistration = false;
    await root.delete(recursive: true);
  });

  test("5-phase DI bootstrap lets LoginCubit be constructed with no missing registrations", () async {
    configureDesktopDependencies(
      router: desktopRouter,
      routerReady: Future<void>.value(),
    );
    // Acceptance for the platform-adapter slice: every LoginCubit dependency
    // resolves through getIt, while the cubit itself stays out of DI.
    final LoginCubit cubit = LoginCubit(
      oAuthFlowProvider: getIt(),
      urlLauncher: getIt(),
      authSession: getIt(),
      lifecycleSource: getIt(),
      installationAnalyticsService: getIt(),
    );
    addTearDown(cubit.close);

    expect(getIt.isRegistered<LoginCubit>(), isFalse);
    expect(getIt<AnalyticsClient>(), isA<NoOpAnalyticsClient>());
    expect(getIt<AnalyticsRuntimeCapability>().isEnabled, isFalse);
    expect(getIt<ProductAnalyticsService>(), isA<ProductAnalyticsService>());
    expect(getIt<FeedbackPromptConfigSource>(), isA<NoOpFeedbackPromptConfigSource>());
    expect(getIt<FeedbackPromptService>(), isA<FeedbackPromptService>());
    expect(getIt.isRegistered<DesktopApplicationSupportDirectory>(), isTrue);
    expect(getIt.isRegistered<PersistenceDatabase>(), isTrue);
    expect(getIt.isRegistered<MasterKeyStore>(), isTrue);
    expect(getIt.isRegistered<PersisterRepository>(), isTrue);
    expect(getIt.checkLazySingletonInstanceExists<LegacyNativeStorageMigrationService>(), isFalse);
    expect(getIt.isRegistered<BridgeExecutablePathResolver>(), isTrue);
    expect(getIt.isRegistered<BridgeProcessEnvironment>(), isTrue);
    expect(getIt.isRegistered<BridgeProcessLogStorage>(), isTrue);
    expect(getIt.isRegistered<BridgeProcessService>(), isTrue);
    expect(getIt.isRegistered<ControlCommandService>(), isTrue);
    expect(getIt.isRegistered<SystemTray>(), isTrue);
    expect(getIt.isRegistered<LaunchAtLogin>(), isTrue);
    expect(getIt.isRegistered<WindowHost>(), isTrue);
    expect(getIt.isRegistered<DesktopApplicationTerminator>(), isTrue);
    expect(getIt.isRegistered<BridgeProcessLogRepository>(), isTrue);
    expect(getIt.isRegistered<DesktopLogoutOrchestrator>(), isTrue);
    expect(getIt.isRegistered<DesktopStartupOrchestrator>(), isTrue);
    expect(getIt<RelayCryptoService>(), isA<RelayCryptoService>());
    expect(getIt<FailureReporter>(), isA<DesktopFailureReporter>());
    expect(getIt<ImageSaver>(), isA<DesktopFileImageSaver>());
    expect(getIt<ImageClipboard>(), isA<DesktopImageClipboard>());
    expect(getIt<ImageSharer>(), isA<DesktopImageSharer>());
    expect(getIt<RouteSource>(), isA<DesktopRouteSource>());
    final ConnectionService connectionService = getIt<ConnectionService>();
    expect(connectionService.currentStatus, isA<ConnectionDisconnected>());
    expect(getIt<RegisteredBridgesService>(), isA<RegisteredBridgesService>());
    expect(getIt<ActiveBridgeLocality>(), isA<DesktopActiveBridgeLocality>());
    expect(getIt<PluginAuthenticationBrowser>(), isA<PluginAuthenticationBrowser>());
    expect(getIt<PluginAuthenticationBrowserService>(), isA<PluginAuthenticationBrowserService>());
    expect(getIt<PluginManagementService>(), isA<PluginManagementService>());
    expect(getIt<DesktopRelayConnectionService>(), isA<DesktopRelayConnectionService>());
    expect(getIt.isRegistered<DesktopInstanceService>(), isTrue);
    expect(getIt.isRegistered<BridgeControlCubit>(), isFalse);
    expect(getIt<BridgeProcessService>().state, isA<BridgeProcessStopped>());
    expect(getIt<ControlCommandService>(), isA<ControlCommandService>());
    expect(await getIt<RegisteredBridgesStore>().hasRegisteredBridges(), isFalse);
    await getIt<AppearanceStore>().write(mode: AppearanceMode.dark);
    expect(await getIt<AppearanceStore>().read(), AppearanceMode.dark);
    expect(await getIt<AuthSession>().restoreLocalSession(), isFalse);
  });

  test("desktop bootstrap resolves the complete image dependency graph", () {
    configureDesktopDependencies(
      router: desktopRouter,
      routerReady: Future<void>.value(),
    );

    expect(getIt<ComposerImagePicker>(), isA<DesktopComposerImagePicker>());
    expect(getIt<ComposerAttachmentDispatcher>(), isA<ComposerAttachmentDispatcher>());
    expect(getIt<TemporaryDirectoryProvider>(), isA<PathProviderTemporaryDirectoryProvider>());
    expect(getIt<AttachmentThumbnailStorage>(), isA<FileAttachmentThumbnailStorage>());
    expect(getIt<MessageThumbnailCacheService>(), isA<MessageThumbnailCacheService>());
    expect(getIt<MessageImageRepository>(), isA<MessageImageRepository>());
  });
}
