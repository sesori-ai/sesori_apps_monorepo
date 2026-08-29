import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/di/injection.dart";
import "package:sesori_desktop/core/platform/no_op_analytics_client.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await getIt.reset();
  });

  test("4-phase DI bootstrap lets LoginCubit be constructed with no missing registrations", () async {
    configureDesktopDependencies();

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
    expect(getIt.isRegistered<BridgeProcessLogStorage>(), isTrue);
    expect(getIt.isRegistered<BridgeProcessService>(), isTrue);
    expect(getIt.isRegistered<ControlCommandService>(), isTrue);
    expect(getIt.isRegistered<SystemTray>(), isTrue);
    expect(getIt.isRegistered<WindowHost>(), isTrue);
    expect(getIt.isRegistered<DesktopApplicationTerminator>(), isTrue);
    expect(getIt.isRegistered<BridgeProcessLogRepository>(), isTrue);
    expect(getIt.isRegistered<DesktopLogoutOrchestrator>(), isTrue);
    expect(getIt.isRegistered<DesktopStartupOrchestrator>(), isTrue);
    expect(getIt.isRegistered<DesktopInstanceService>(), isTrue);
    expect(getIt.isRegistered<BridgeControlCubit>(), isFalse);
    expect(getIt<BridgeProcessService>().state, isA<BridgeProcessStopped>());
    expect(getIt<ControlCommandService>(), isA<ControlCommandService>());
  });

  test("desktop bootstrap leaves the mobile thumbnail cache unbound and unresolved", () {
    configureDesktopDependencies();

    expect(getIt.isRegistered<AttachmentThumbnailStorage>(), isFalse);
    expect(getIt.isRegistered<MessageThumbnailCacheService>(), isTrue);
    expect(
      getIt.checkLazySingletonInstanceExists<MessageThumbnailCacheService>(),
      isFalse,
    );
    expect(
      getIt.checkLazySingletonInstanceExists<MessageImageRepository>(),
      isFalse,
    );
  });
}
