import "package:material_ui/material_ui.dart";

import "app.dart";
import "core/di/injection.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDesktopDependencies();
  runApp(const SesoriDesktopApp());
}
