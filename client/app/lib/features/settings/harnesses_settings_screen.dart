import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/routing/app_router.dart";

/// Mobile-shell composition for shared harness management.
class const HarnessesSettingsScreen({
  super.key,
  required final HarnessSettingsPresentation presentation,
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
        connectionBanner: ConnectionBanner.maybeFor(context),
        // A modal normally pops to its opener. A direct deep link has no
        // opener and therefore falls back to the mobile signed-in home.
        onModalClose: () => context.canPop() ? context.pop() : context.goRoute(const AppRoute.projects()),
      ),
    );
  }
}
