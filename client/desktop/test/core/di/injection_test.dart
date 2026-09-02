import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/di/injection.dart";
import "package:sesori_desktop/core/platform/desktop_attachment_thumbnail_storage.dart";
import "package:sesori_desktop/core/platform/desktop_composer_image_picker.dart";
import "package:sesori_desktop/core/platform/desktop_failure_reporter.dart";
import "package:sesori_desktop/core/platform/desktop_file_image_saver.dart";
import "package:sesori_desktop/core/platform/desktop_image_clipboard.dart";
import "package:sesori_desktop/core/platform/desktop_image_sharer.dart";
import "package:sesori_desktop/core/platform/desktop_route_source.dart";
import "package:sesori_desktop/core/platform/no_op_analytics_client.dart";
import "package:sesori_desktop/core/routing/desktop_router.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";

class _InMemorySecureStorage() implements SecureStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> write({required String key, required String value}) async => _values[key] = value;

  @override
  Future<void> delete({required String key}) async => _values.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await getIt.reset();
  });

  test("4-phase DI bootstrap lets LoginCubit be constructed with no missing registrations", () async {
    configureDesktopDependencies(
      router: desktopRouter,
      routerReady: Future<void>.value(),
    );
    getIt.unregister<SecureStorage>();
    getIt.registerLazySingleton<SecureStorage>(_InMemorySecureStorage.new);

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
    expect(getIt.isRegistered<DesktopApplicationSupportDirectory>(), isTrue);
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
    expect(getIt<DesktopRelayConnectionService>(), isA<DesktopRelayConnectionService>());
    expect(getIt.isRegistered<DesktopInstanceService>(), isTrue);
    expect(getIt.isRegistered<BridgeControlCubit>(), isFalse);
    expect(getIt<BridgeProcessService>().state, isA<BridgeProcessStopped>());
    expect(getIt<ControlCommandService>(), isA<ControlCommandService>());
  });

  test("desktop bootstrap resolves the complete image dependency graph", () {
    configureDesktopDependencies(
      router: desktopRouter,
      routerReady: Future<void>.value(),
    );

    expect(getIt<ComposerImagePicker>(), isA<DesktopComposerImagePicker>());
    expect(getIt<ComposerAttachmentDispatcher>(), isA<ComposerAttachmentDispatcher>());
    expect(getIt<AttachmentThumbnailStorage>(), isA<DesktopAttachmentThumbnailStorage>());
    expect(getIt<MessageThumbnailCacheService>(), isA<MessageThumbnailCacheService>());
    expect(getIt<MessageImageRepository>(), isA<MessageImageRepository>());
  });
}
