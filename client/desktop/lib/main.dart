import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

import "app.dart";
import "core/di/injection.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDesktopDependencies();
  final DesktopStartupOrchestrator startupOrchestrator = getIt();
  if (!await startupOrchestrator.preparePrimaryLaunch()) {
    return;
  }

  try {
    await getIt<WindowHost>().initialize();
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
  getIt<ControlMessageDispatcher>().start();
  runApp(const SesoriDesktopApp());
  unawaited(startupOrchestrator.restoreBridgeDesiredState());
}
