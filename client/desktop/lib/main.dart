import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

import "app.dart";
import "core/di/injection.dart";
import "core/platform/desktop_launch_arguments.dart";

Future<void> main(List<String> arguments) async {
  final bool hiddenLaunch = isDesktopHiddenLaunch(arguments: arguments);
  WidgetsFlutterBinding.ensureInitialized();
  configureDesktopDependencies();
  final DesktopStartupOrchestrator startupOrchestrator = getIt();
  if (!await startupOrchestrator.preparePrimaryLaunch()) {
    return;
  }

  final AppearanceMode initialAppearance = await getIt<AppearanceStore>().read();
  final ChatInputMode initialChatInputMode = await getIt<ChatInputModeStore>().read();

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
  await getIt<ControlMessageDispatcher>().start();
  // Root the shared relay client before the UI builds. Its auth-state listener
  // connects automatically when AuthGate restores or completes a login, and
  // no second reconnect driver is introduced in the desktop shell.
  getIt<ConnectionService>();
  // Start local analytics state before building. Authenticated reconciliation
  // waits until after the first frame so a slow server cannot blank startup;
  // Profile reflects the service's synchronization state until it settles.
  final ProductAnalyticsService productAnalyticsService = getIt();
  await productAnalyticsService.start();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_markProductAnalyticsReady(service: productAnalyticsService));
  });
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
