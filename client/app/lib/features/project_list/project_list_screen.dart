import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:share_plus/share_plus.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";
import "../../core/bridge_install.dart";
import "../../core/constants.dart";
import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/extensions/remote_failure_x.dart";
import "../../core/extensions/text_style_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/connection_graphic.dart";
import "add_project_dialog.dart";
import "rename_project_dialog.dart";

part "onboarding/onboarding_view.dart";
part "widgets/bridge_offline_view.dart";
part "widgets/error_view.dart";
part "widgets/project_tile.dart";

class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProjectListCubit(
        getIt<ProjectService>(),
        getIt<ConnectionService>(),
        getIt<SseEventRepository>(),
        getIt<RouteSource>(),
        registeredBridgesService: getIt<RegisteredBridgesService>(),
        failureReporter: getIt<FailureReporter>(),
      ),
      child: const _ProjectListBody(),
    );
  }
}

class _ProjectListBody extends StatefulWidget {
  const _ProjectListBody();

  @override
  State<_ProjectListBody> createState() => _ProjectListBodyState();
}

class _ProjectListBodyState extends State<_ProjectListBody> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  void _showProjectMenu({required BuildContext context, required Project project}) {
    // Capture messenger and cubit before any Navigator.pop to avoid
    // post-pop context access.
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final cubit = context.read<ProjectListCubit>();
    final loc = context.loc;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(loc.rename),
              onTap: () {
                sheetContext.pop();
                showRenameProjectDialog(
                  context: context,
                  project: project,
                  cubit: cubit,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text(loc.hideProject),
              onTap: () {
                sheetContext.pop();
                cubit.hideProject(project.id);
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(loc.projectHidden),
                    duration: kSnackBarDuration,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<ProjectListCubit>().state;
    final isRefreshing = state is ProjectListLoaded && state.isRefreshing;

    return PregoGlassScaffold(
      title: loc.projectListTitle,
      actions: [
        PregoButtonsIconGlass(
          icon: VESPRSolid.gear,
          semanticLabel: loc.settingsTitle,
          onPressed: () => context.pushRoute(const AppRoute.settings()),
        ),
      ],
      // The FAB only makes sense once the bridge is connected with a non-empty
      // project list. It is absent from the not-connected onboarding and from
      // the connected-but-empty state, where the inline Step 3 folder button is
      // the add-project affordance.
      floatingActionButton: state is ProjectListLoaded && state.projects.isNotEmpty
          ? PregoButtonsIconGlass(
              icon: TablerRegular.folder_plus,
              size: PregoButtonsIconGlassSize.xl,
              iconSize: 22,
              onPressed: () => showAddProjectDialog(context, context.read<ProjectListCubit>()),
            )
          : null,
      // Pull-to-refresh re-fetches the project list once connected; the
      // disconnected states keep their own inner reconnect-on-pull.
      onRefresh: state is ProjectListLoaded ? () => _refreshProjects(context) : null,
      slivers: _buildContentSlivers(context: context, state: state, isRefreshing: isRefreshing),
    );
  }

  List<Widget> _buildContentSlivers({
    required BuildContext context,
    required ProjectListState state,
    required bool isRefreshing,
  }) {
    return switch (state) {
      ProjectListLoading() => const [
        SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator())),
      ],
      // No bridge has ever been registered → setup onboarding; a bridge exists
      // but isn't running → ask to turn it on. Both are full-screen views that
      // own their scroll and reconnect-on-pull, so they fill the body below the
      // bar rather than joining the outer scroll.
      ProjectListBridgeDisconnected(:final hasRegisteredBridges) => [
        SliverFillRemaining(
          hasScrollBody: true,
          child: hasRegisteredBridges ? const _BridgeOfflineView() : const _BridgeOnboardingView(),
        ),
      ],
      ProjectListLoaded(:final projects, :final activityById) => [
        if (isRefreshing) const SliverToBoxAdapter(child: LinearProgressIndicator()),
        if (projects.isEmpty)
          // Render the shared onboarding body directly (not its own scroll
          // view) so the scaffold's pull-to-refresh drives it. SafeArea(top:
          // false) keeps the bottom install box clear of the home indicator,
          // matching the disconnected onboarding view.
          const SliverFillRemaining(
            hasScrollBody: false,
            child: SafeArea(
              top: false,
              child: _OnboardingChecklist(connected: true),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            sliver: SliverList.builder(
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                return _ProjectTile(
                  project: project,
                  activeSessions: activityById[project.id] ?? 0,
                  onLongPress: () => _showProjectMenu(context: context, project: project),
                );
              },
            ),
          ),
          // Clear the floating folder FAB and the home indicator.
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 96)),
        ],
      ],
      ProjectListFailed(:final reason) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorView(
            reason: reason,
            onRetry: () => context.read<ProjectListCubit>().retryLoadProjects(),
          ),
        ),
      ],
    };
  }

  Future<void> _refreshProjects(BuildContext context) async {
    final loc = context.loc;
    final success = await context.read<ProjectListCubit>().refreshProjects();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? loc.projectListRefreshSuccess : loc.projectListRefreshFailed),
        duration: kSnackBarDuration,
      ),
    );
  }
}
