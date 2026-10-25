import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";
import "../../core/routing/app_router.dart";
import "../home/onboarding/bridge_onboarding.dart";

/// Mobile composition for the shared project inventory.
///
/// The phone retains CLI install/share guidance and relay reconnection while
/// the shared view owns the inventory presentation itself.
class const ProjectListScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // The inventories and the project list come from the signed-in SessionScope.
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => RecentSessionsCubit(inventoryService: context.read<RecentSessionInventoryService>()),
        ),
        BlocProvider(
          create: (_) => BridgeIdentityCubit(
            registeredBridgesService: getIt<RegisteredBridgesService>(),
            connectionService: getIt<ConnectionService>(),
            selectedComputerService: getIt<SelectedComputerService>(),
          ),
        ),
        BlocProvider(
          create: (_) => ComputerSwitcherCubit(
            registeredBridgesService: getIt<RegisteredBridgesService>(),
            connectionService: getIt<ConnectionService>(),
            selectedComputerService: getIt<SelectedComputerService>(),
            activeBridgeLocality: getIt<ActiveBridgeLocality>(),
          ),
        ),
      ],
      child: ProjectListView(
        onAddProject: _showAddProject,
        onOpenSettings: ({required context}) => context.pushRoute(const AppRoute.settings()),
        // Settings goes under the page so Back from Computers lands there.
        onManageComputers: ({required context}) {
          context.pushRoute(const AppRoute.settings());
          context.pushRoute(const AppRoute.settingsComputers());
        },
        onOpenSession: ({required context, required project, required displayName, required session}) {
          context.pushRoute(
            AppRoute.sessionDetail(
              projectId: project.id,
              projectName: displayName,
              sessionId: session.id,
              sessionTitle: session.title,
              readOnly: false,
              fromLaunch: false,
            ),
          );
        },
        onOpenProject: _openProject,
        disconnectedViewBuilder: ({required context, required state, required bridge}) => state.hasRegisteredBridges
            ? BridgeOfflineView(bridge: bridge, onSwitchComputer: switchComputer)
            : const ConnectBridgeChecklist(),
        disconnectedActionBuilder: ({required context, required state}) => NeedHelpMenu(
          surface: state.hasRegisteredBridges ? OnboardingSurface.bridgeOffline : OnboardingSurface.connectSetup,
          // The offline fix is the command above, so help stays a quiet link.
          quiet: state.hasRegisteredBridges,
        ),
        connectedEmptyViewBuilder: ({required context}) => ConnectedEmptyView(
          onAddProject: () => _showAddProject(context: context),
        ),
        connectionBannerBuilder: ({required context}) => ConnectionBanner.maybeFor(context),
        onRefreshDisconnected: ({required context, required state}) =>
            context.read<ProjectListCubit>().reconnectBridge(),
        onSwitchComputer: switchComputer,
      ),
    );
  }

  static void _showAddProject({required BuildContext context}) {
    unawaited(
      showAddProjectDialog(context: context, onProjectAdded: _openProject),
    );
  }

  static void _openProject({
    required BuildContext context,
    required ProjectSummary project,
    required String displayName,
  }) {
    context.pushRoute(AppRoute.projectSessions(projectId: project.id, projectName: displayName));
  }
}
