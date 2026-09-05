import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";

typedef DesktopProjectOpened = void Function({required String projectId, required String projectName});

/// Desktop composition for the shared project inventory.
///
/// Unlike mobile, both disconnected states recover by starting the supervised
/// local bridge and never expose CLI installation commands.
class const DesktopProjectListScreen({
  super.key,
  required final VoidCallback onOpenSettings,
  required final DesktopProjectOpened onOpenProject,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Future<void> recover({required BuildContext context}) => context.read<BridgeControlCubit>().recoverConnection();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => createProjectListCubit(locator: getIt),
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
        onOpenSettings: ({required context}) => onOpenSettings(),
        onOpenProject: ({required context, required project, required displayName}) =>
            onOpenProject(projectId: project.id, projectName: displayName),
        disconnectedViewBuilder: ({required context, required state, required bridge}) => DesktopBridgeRecoveryView(
          bridge: bridge,
          onStartBridge: () => recover(context: context),
        ),
        disconnectedActionBuilder: ({required context, required state}) => null,
        connectedEmptyViewBuilder: ({required context}) => _DesktopConnectedEmptyView(
          onAddProject: () => _showAddProject(context: context),
        ),
        connectionBannerBuilder: ({required context}) => null,
        onRefreshDisconnected: ({required context, required state}) => recover(context: context),
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

/// Desktop-owned supervised recovery shown for both unregistered and offline bridges.
class const DesktopBridgeRecoveryView({
  super.key,
  required final BridgeSummary? bridge,
  required final Future<void> Function() onStartBridge,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controlState = context.watch<BridgeControlCubit>().state;
    final bridge = this.bridge;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(PregoSpacing.x2l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                TablerRegular.device_laptop,
                size: 48,
                color: context.prego.colors.textTertiary,
              ),
              const SizedBox(height: PregoSpacing.lg),
              if (bridge != null) ...[
                Text(
                  bridge.name,
                  textAlign: TextAlign.center,
                  style: context.prego.textTheme.textLg.bold,
                ),
                const SizedBox(height: PregoSpacing.xs),
              ],
              Text(
                context.loc.projectsBridgeOfflineDisconnected,
                textAlign: TextAlign.center,
                style: context.prego.textTheme.textSm.regular.copyWith(
                  color: context.prego.colors.textSecondary,
                ),
              ),
              const SizedBox(height: PregoSpacing.x2l),
              Text(
                context.loc.projectsDesktopStartBridgeInfo,
                textAlign: TextAlign.center,
                style: context.prego.textTheme.textSm.regular,
              ),
              const SizedBox(height: PregoSpacing.xl),
              PregoButtonsSolid(
                label: context.loc.projectsDesktopStartBridge,
                leadingIcon: TablerRegular.player_play,
                hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                size: PregoButtonsSolidSize.xl,
                fullWidth: true,
                isLoading: controlState.activity == BridgeControlActivity.toggling,
                onPressed: controlState.activity.locksCommands ? null : () => unawaited(onStartBridge()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class const _DesktopConnectedEmptyView({required final VoidCallback onAddProject}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              TablerRegular.folder,
              size: 48,
              color: context.prego.colors.textTertiary,
            ),
            const SizedBox(height: PregoSpacing.lg),
            Text(
              context.loc.projectsEmptyMessage,
              textAlign: TextAlign.center,
              style: context.prego.textTheme.textSm.regular,
            ),
            const SizedBox(height: PregoSpacing.xl),
            PregoButtonsSolid(
              label: context.loc.projectsEmptyAddProject,
              leadingIcon: TablerRegular.folder_plus,
              hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
              size: PregoButtonsSolidSize.xl,
              onPressed: onAddProject,
            ),
          ],
        ),
      ),
    );
  }
}
