import "dart:async";
import "dart:ui" as ui;

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
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

part "onboarding/onboarding_hero.dart";
part "onboarding/onboarding_view.dart";
part "widgets/bridge_offline_view.dart";
part "widgets/command_block.dart";
part "widgets/connected_empty_view.dart";
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
        bridgeRepository: getIt<BridgeRepository>(),
        registeredBridgesStore: getIt<RegisteredBridgesStore>(),
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
    final prego = context.prego;

    return Scaffold(
      backgroundColor: prego.colors.bgSecondary,
      // TODO: we need to have app wide navigation bar component
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleSpacing: PregoSpacing.xl,
        title: Text(
          loc.projectListTitle,
          style: prego.textTheme.textXl.medium.copyWith(color: prego.colors.textPrimary),
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: PregoSpacing.xl),
            child: PregoButtonsIconGlass(
              icon: VESPRSolid.gear,
              semanticLabel: loc.settingsTitle,
              onPressed: () => context.pushRoute(const AppRoute.settings()),
            ),
          ),
        ],
      ),

      // The FAB only makes sense once the bridge is connected with a non-empty
      // project list. It is absent from the not-connected onboarding and from
      // the connected-but-empty state, where the inline Step 3 folder button is
      // the add-project affordance.
      floatingActionButton: state is ProjectListLoaded && state.projects.isNotEmpty
          ? PregoButtonsIconGlass(
              icon: TablerRegular.folder_plus,
              size: PregoButtonsIconGlassSize.lg,
              iconSize: 22,
              onPressed: () => showAddProjectDialog(context, context.read<ProjectListCubit>()),
            )
          : null,
      body: switch (state) {
        ProjectListLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        // No bridge has ever been registered → walk through the setup
        // onboarding; a bridge exists but isn't running → ask to turn it on.
        ProjectListBridgeDisconnected(:final hasRegisteredBridges) =>
          hasRegisteredBridges ? const _BridgeOfflineView() : const _BridgeOnboardingView(),
        ProjectListLoaded(:final projects, :final activityById, :final isRefreshing) => Column(
          children: [
            if (isRefreshing) const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final success = await context.read<ProjectListCubit>().refreshProjects();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? loc.projectListRefreshSuccess : loc.projectListRefreshFailed),
                      duration: kSnackBarDuration,
                    ),
                  );
                },
                child: projects.isEmpty
                    ? _ConnectedEmptyView(
                        onAddProject: () => showAddProjectDialog(context, context.read<ProjectListCubit>()),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
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
            ),
          ],
        ),
        ProjectListFailed(:final reason) => _ErrorView(
          reason: reason,
          onRetry: () => context.read<ProjectListCubit>().retryLoadProjects(),
        ),
      },
    );
  }
}
