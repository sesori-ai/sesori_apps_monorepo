import "dart:async";

import "package:cupertino_ui/cupertino_ui.dart" show CupertinoColors, CupertinoDynamicColor;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:share_plus/share_plus.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/bridge_install.dart";
import "../../core/di/injection.dart";
import "../../core/external_link.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/connection_graphic.dart";

part "onboarding/onboarding_view.dart";
part "onboarding/why_bridge_info_sheet.dart";
part "widgets/bridge_offline_view.dart";

/// Mobile composition for the shared project inventory.
///
/// The phone retains CLI install/share guidance and relay reconnection while
/// the shared view owns the inventory presentation itself.
class const ProjectListScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ProjectListCubit(
            getIt<ProjectRepository>(),
            getIt<ConnectionService>(),
            getIt<SseEventTracker>(),
            getIt<RouteSource>(),
            projectListService: getIt<ProjectListService>(),
            sessionUnseenTracker: getIt<SessionUnseenTracker>(),
            registeredBridgesService: getIt<RegisteredBridgesService>(),
            productAnalyticsService: getIt<ProductAnalyticsService>(),
            loadedStateAnalyticsReporter: LoadedStateAnalyticsReporter.projectInventory(
              productAnalyticsService: getIt<ProductAnalyticsService>(),
            ),
            failureReporter: getIt<FailureReporter>(),
            catalogRescanService: getIt<CatalogRescanService>(),
          ),
        ),
        BlocProvider(
          create: (_) => BridgeIdentityCubit(
            registeredBridgesService: getIt<RegisteredBridgesService>(),
            connectionService: getIt<ConnectionService>(),
          ),
        ),
      ],
      child: ProjectListView(
        onAddProject: _showAddProject,
        onOpenSettings: ({required context}) => context.pushRoute(const AppRoute.settings()),
        onOpenProject: ({required context, required project, required displayName}) {
          context.pushRoute(
            AppRoute.sessions(
              projectId: project.id,
              projectName: displayName,
            ),
          );
        },
        disconnectedViewBuilder: ({required context, required state, required bridge}) =>
            state.hasRegisteredBridges ? _BridgeOfflineView(bridge: bridge) : const _ConnectBridgeChecklist(),
        disconnectedActionBuilder: ({required context, required state}) => _NeedHelpMenu(
          surface: state.hasRegisteredBridges ? OnboardingSurface.bridgeOffline : OnboardingSurface.connectSetup,
        ),
        connectedEmptyViewBuilder: ({required context}) => _ConnectedEmptyView(
          onAddProject: () => _showAddProject(context: context),
        ),
        connectionBannerBuilder: ({required context}) => ConnectionBanner.maybeFor(context),
        onRefreshDisconnected: ({required context, required state}) =>
            context.read<ProjectListCubit>().reconnectBridge(),
      ),
    );
  }

  static void _showAddProject({required BuildContext context}) {
    unawaited(
      showAddProjectDialog(
        context: context,
        cubit: context.read<ProjectListCubit>(),
        connectionService: getIt<ConnectionService>(),
      ),
    );
  }
}
