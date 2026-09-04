import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";

/// Desktop-shell composition for shared harness management.
class const DesktopHarnessesSettingsScreen({
  super.key,
  required final HarnessSettingsPresentation presentation,
  required final VoidCallback onClose,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PluginManagementCubit(
        service: getIt<PluginManagementService>(),
        urlLauncher: getIt<UrlLauncher>(),
        catalogRescanService: getIt<CatalogRescanService>(),
      ),
      child: HarnessesSettingsView(
        presentation: presentation,
        connectionBanner: null,
        onModalClose: onClose,
      ),
    );
  }
}
