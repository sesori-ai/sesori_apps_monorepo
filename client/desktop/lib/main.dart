import "package:material_ui/material_ui.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

import "app.dart";
import "core/di/injection.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDesktopDependencies();
  await getIt<WindowHost>().initialize();
  // The dispatcher must own the control event stream before any service can
  // spawn a helper, or its first bootstrap token request could go unread.
  getIt<ControlMessageDispatcher>().start();
  runApp(const SesoriDesktopApp());
}
