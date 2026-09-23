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
import "desktop_file_access_card.dart";

/// Home presentation consumes the cockpit's project inventory, never another list.
class const DesktopHomePane({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectListCubit>().state;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SafeArea(bottom: false, child: DesktopFileAccessCard())),
          SliverFillRemaining(
            hasScrollBody: false,
            child: SafeArea(
              child: switch (state) {
                ProjectListLoading() => Center(
                  child: Semantics(
                    label: context.loc.projectListLoadingSemantics,
                    child: const PregoAiLoader(size: 32),
                  ),
                ),
                ProjectListFailed(:final reason) => RemoteFailureView(
                  reason: reason,
                  title: context.loc.projectListErrorTitle,
                  retryLabel: context.loc.projectListRetry,
                  onRetry: () => context.read<ProjectListCubit>().retryLoadProjects(),
                ),
                ProjectListBridgeDisconnected() => BlocProvider(
                  create: (_) => BridgeIdentityCubit(
                    registeredBridgesService: getIt<RegisteredBridgesService>(),
                    connectionService: getIt<ConnectionService>(),
                  ),
                  child: Builder(
                    builder: (context) => DesktopBridgeRecoveryView(
                      bridge: switch (context.watch<BridgeIdentityCubit>().state) {
                        BridgeIdentityNamed(:final bridge) => bridge,
                        BridgeIdentityPending() || BridgeIdentityUnnamed() => null,
                      },
                      onStartBridge: context.read<BridgeControlCubit>().recoverConnection,
                    ),
                  ),
                ),
                ProjectListLoaded(:final projects) => _DesktopHomeEmptyView(
                  hasProjects: projects.isNotEmpty,
                  onAddProject: () => _showAddProject(context: context),
                ),
              },
            ),
          ),
        ],
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
              // An illustration, not a glyph: no icon token applies.
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

class const _DesktopHomeEmptyView({
  required final bool hasProjects,
  required final VoidCallback onAddProject,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(PregoSpacing.x2l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // An illustration, not a glyph: no icon token applies.
              Icon(
                hasProjects ? TablerRegular.layout_sidebar_left_expand : TablerRegular.folder,
                size: 48,
                color: context.prego.colors.textTertiary,
              ),
              const SizedBox(height: PregoSpacing.lg),
              Text(
                hasProjects ? context.loc.desktopHomePickSession : context.loc.projectsEmptyMessage,
                textAlign: TextAlign.center,
                style: context.prego.textTheme.textMd.medium,
              ),
              if (!hasProjects) ...[
                const SizedBox(height: PregoSpacing.xl),
                PregoButtonsSolid(
                  label: context.loc.projectsEmptyAddProject,
                  leadingIcon: TablerRegular.folder_plus,
                  hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                  size: PregoButtonsSolidSize.xl,
                  onPressed: onAddProject,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
