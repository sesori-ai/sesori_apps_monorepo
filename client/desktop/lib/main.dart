import "dart:async";

import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

import "app.dart";
import "core/di/injection.dart";
import "core/platform/desktop_launch_arguments.dart";
import "core/routing/desktop_router.dart";

Future<void> main(List<String> arguments) async {
  logi("Desktop startup: entered Dart main");
  final bool hiddenLaunch = isDesktopHiddenLaunch(arguments: arguments);
  WidgetsFlutterBinding.ensureInitialized();
  configureDesktopDependencies(
    router: desktopRouter,
    routerReady: desktopRouterReady,
  );
  final DesktopStartupOrchestrator startupOrchestrator = getIt();
  logi("Desktop startup: claiming primary process");
  if (!await startupOrchestrator.preparePrimaryLaunch()) {
    return;
  }
  logi("Desktop startup: primary process claimed");
  setLogSink(sink: getIt<LogSink>());

  // Only the primary process renders UI; premium remains disabled.
  await LiquidGlassWidgets.initialize(warmUpMode: GlassWarmUpMode.never);

  logi("Desktop startup: reading appearance and input preferences");
  final AppearanceMode initialAppearance = await getIt<AppearanceStore>().read();
  final ChatInputMode initialChatInputMode = await getIt<ChatInputModeStore>().read();

  logi("Desktop startup: initializing the native window");
  try {
    await startupOrchestrator.initializeWindow(hidden: hiddenLaunch);
  } on Object catch (error, stackTrace) {
    try {
      await getIt.reset();
    } on Object catch (cleanupError, cleanupStackTrace) {
      logw("Failed to release desktop resources after window initialization failed", cleanupError, cleanupStackTrace);
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
  // The dispatcher must own the control event stream before any service can
  // spawn a helper, or its first bootstrap token request could go unread.
  logi("Desktop startup: starting the control dispatcher");
  await getIt<ControlMessageDispatcher>().start();
  // Root the shared relay client before the UI builds. Its auth-state listener
  // connects automatically when AuthGate restores or completes a login, and
  // no second reconnect driver is introduced in the desktop shell.
  logi("Desktop startup: initializing the relay client");
  getIt<ConnectionService>();
  // Desktop attention derives from the authenticated relay stream and must be
  // listening before a restored session can receive its first user prompt.
  logi("Desktop startup: starting desktop attention");
  await getIt<DesktopAttentionService>().start();
  // Start local analytics state before building. Authenticated reconciliation
  // waits until after the first frame so a slow server cannot blank startup;
  // Account reflects the service's synchronization state until it settles.
  final ProductAnalyticsService productAnalyticsService = getIt();
  logi("Desktop startup: loading analytics preferences");
  await productAnalyticsService.start();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_markProductAnalyticsReady(service: productAnalyticsService));
  });
  logi("Desktop startup: rendering the application");
  runApp(
    SesoriDesktopApp(
      hiddenLaunch: hiddenLaunch,
      initialAppearance: initialAppearance,
      initialChatInputMode: initialChatInputMode,
    ),
  );
  unawaited(startupOrchestrator.restoreBridgeDesiredState());
}

Future<void> _markProductAnalyticsReady({required ProductAnalyticsService service}) async {
  try {
    await service.markPostSplashReady();
  } on Object catch (error, stackTrace) {
    logw("Failed to reconcile product analytics after desktop startup", error, stackTrace);
  }
}
