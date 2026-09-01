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
    await getIt<WindowHost>().initialize(hidden: hiddenLaunch);
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
  // Profile owns the shared analytics preference control, so synchronize the
  // service before that route can render instead of leaving it in Loading.
  final ProductAnalyticsService productAnalyticsService = getIt();
  await productAnalyticsService.start();
  await productAnalyticsService.markPostSplashReady();
  runApp(
    SesoriDesktopApp(
      hiddenLaunch: hiddenLaunch,
      initialAppearance: initialAppearance,
      initialChatInputMode: initialChatInputMode,
    ),
  );
  unawaited(startupOrchestrator.restoreBridgeDesiredState());
}
