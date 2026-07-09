import "dart:async";

import "package:flutter/cupertino.dart" show CupertinoColors, CupertinoDynamicColor;
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
import "../../core/external_link.dart";
import "../../core/routing/app_router.dart";
import "../../core/support_links.dart";
import "../../core/widgets/connection_banner.dart";
import "../../core/widgets/connection_graphic.dart";
import "add_project_dialog.dart";
import "rename_project_dialog.dart";

part "onboarding/onboarding_view.dart";
part "onboarding/why_bridge_info_sheet.dart";
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
        sessionUnseenTracker: getIt<SessionUnseenTracker>(),
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
    // Same display-name resolution as _ProjectTile, so the sheet is titled
    // by the project it acts on.
    final lastSegment = project.id.split("/").last;
    final displayName = project.name ?? (lastSegment.isNotEmpty ? lastSegment : loc.projectListDefaultName);

    showPregoBottomSheet<void>(
      context: context,
      title: displayName,
      // Full-bleed tiles; each ListTile carries its own horizontal padding.
      contentPadding: EdgeInsetsDirectional.zero,
      builder: (sheetContext) => Material(
        // Transparent Material so the tiles' ink paints on top of the sheet
        // surface instead of behind it on the modal's transparent Material.
        type: MaterialType.transparency,
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

  /// The scaffold's bottom-right floating action for the current [state]: the
  /// add-project FAB once projects exist, the onboarding "Need help?" support
  /// menu in the two empty states (never-registered setup and connected-but-
  /// empty), and nothing otherwise.
  Widget? _floatingAction({required BuildContext context, required ProjectListState state}) {
    if (state is ProjectListLoaded && state.projects.isNotEmpty) {
      return PregoButtonsIconGlass(
        icon: TablerRegular.folder_plus,
        size: PregoButtonsIconGlassSize.xl,
        iconSize: 22,
        onPressed: () => showAddProjectDialog(context, context.read<ProjectListCubit>()),
      );
    }
    final isOnboarding =
        (state is ProjectListBridgeDisconnected && !state.hasRegisteredBridges) ||
        (state is ProjectListLoaded && state.projects.isEmpty);
    return isOnboarding ? const _NeedHelpMenu() : null;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<ProjectListCubit>().state;
    final isRefreshing = state is ProjectListLoaded && state.isRefreshing;
    // The connect-your-computer onboarding (no bridge ever registered, none
    // connected) titles the screen "Connect"; every other state keeps
    // "Projects".
    final isConnectOnboarding = state is ProjectListBridgeDisconnected && !state.hasRegisteredBridges;

    return PregoGlassScaffold(
      title: isConnectOnboarding ? loc.projectListConnectTitle : loc.projectListTitle,
      // A loaded list hosts the top-nav connection banner; the loading and
      // bridge-disconnected states own their messaging full-screen (setup
      // onboarding or the "turn on your bridge" design), so they suppress it.
      banner: _bannerFor(context: context, state: state),
      actions: [
        PregoButtonsIconGlass(
          icon: VESPRSolid.gear,
          semanticLabel: loc.settingsTitle,
          onPressed: () => context.pushRoute(const AppRoute.settings()),
        ),
      ],
      // Bottom-right floating action, resolved per state: the add-project FAB
      // once projects exist, the onboarding "Need help?" support menu in the two
      // empty states, and nothing while loading/offline/errored.
      floatingActionButton: _floatingAction(context: context, state: state),
      onRefresh: _refreshFor(context: context, state: state),
      slivers: _buildContentSlivers(context: context, state: state, isRefreshing: isRefreshing),
    );
  }

  /// The scaffold's pull-to-refresh action for [state], or `null` when there is
  /// nothing to pull for.
  ///
  /// A loaded list re-fetches its projects. The disconnected states re-attempt
  /// the bridge connection: escaping them is otherwise passive (they wait for a
  /// connection event), which can strand a bridge that never came up.
  Future<void> Function()? _refreshFor({required BuildContext context, required ProjectListState state}) {
    return switch (state) {
      ProjectListLoaded() => () => _refreshProjects(context),
      ProjectListBridgeDisconnected() => () => context.read<ProjectListCubit>().reconnectBridge(),
      ProjectListLoading() || ProjectListFailed() => null,
    };
  }

  /// The top-nav connection banner for [state], or `null` when it should be
  /// suppressed.
  ///
  /// A non-empty loaded list always hosts it. The empty onboarding list
  /// normally owns the screen full-screen (its checklist would contradict an
  /// offline banner, and a bridge-offline empty list transitions to the
  /// dedicated offline flow instead) — but a terminal `ConnectionLost` keeps
  /// the list loaded-empty with no other recovery surface, so surface the
  /// reconnect banner there too.
  Widget? _bannerFor({required BuildContext context, required ProjectListState state}) {
    if (state is! ProjectListLoaded) return null;
    final banner = ConnectionBanner.maybeFor(context);
    if (state.projects.isNotEmpty) return banner;
    // maybeFor already watched the connection cubit above, so a read here still
    // rebuilds reactively while surfacing only the connection-lost variant over
    // the onboarding checklist.
    return context.read<ConnectionOverlayCubit>().state is ConnectionOverlayConnectionLost ? banner : null;
  }

  List<Widget> _buildContentSlivers({
    required BuildContext context,
    required ProjectListState state,
    required bool isRefreshing,
  }) {
    return switch (state) {
      ProjectListLoading() => [
        SliverToBoxAdapter(
          child: PregoSkeletonList(semanticLabel: context.loc.projectListLoadingSemantics),
        ),
      ],
      // No bridge has ever been registered → setup onboarding; a bridge exists
      // but isn't running → ask to turn it on. Both join the page scroll rather
      // than nesting one of their own, so the large title scrolls away and
      // collapses into the bar with them. hasScrollBody: false lets a body
      // shorter than the viewport sit still while a taller one — the offline
      // view with its install commands expanded — scrolls the page.
      // SafeArea(top: false) keeps the last box clear of the home indicator.
      ProjectListBridgeDisconnected(:final hasRegisteredBridges) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: SafeArea(
            top: false,
            child: hasRegisteredBridges ? const _BridgeOfflineView() : const _ConnectBridgeChecklist(),
          ),
        ),
      ],
      ProjectListLoaded(:final projects, :final activityById, :final unseenByProjectId) => [
        if (isRefreshing) const SliverToBoxAdapter(child: LinearProgressIndicator()),
        if (projects.isEmpty)
          // Same shape as the disconnected bodies above: the onboarding joins
          // the page scroll rather than nesting one of its own.
          const SliverFillRemaining(
            hasScrollBody: false,
            child: SafeArea(
              top: false,
              child: _OnboardingChecklist(),
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
                  unseen: unseenByProjectId[project.id] ?? project.hasUnseenChanges,
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
