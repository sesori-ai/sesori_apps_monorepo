import "dart:async";

import "package:flutter/cupertino.dart" show CupertinoColors, CupertinoDynamicColor;
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:share_plus/share_plus.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";
import "../../core/analytics/analytics_event.dart";
import "../../core/analytics/analytics_reporter.dart";
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
import "widgets/project_tile.dart";

part "onboarding/onboarding_view.dart";
part "onboarding/why_bridge_info_sheet.dart";
part "widgets/bridge_offline_view.dart";
part "widgets/error_view.dart";

/// Enough placeholder rows to fill a phone screen while the first page loads.
const int _skeletonRows = 6;

class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProjectListCubit(
        getIt<ProjectRepository>(),
        getIt<ConnectionService>(),
        getIt<SseEventTracker>(),
        getIt<RouteSource>(),
        projectListService: getIt<ProjectListService>(),
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

  /// The scaffold's floating action for the current [state], with the
  /// placement that action is designed for: the add-project FAB in the
  /// trailing corner once projects exist, the onboarding "Need help?" support
  /// menu centred on the disconnected surfaces, and nothing otherwise — the
  /// connected-but-empty state anchors its own add-project call to action at
  /// the bottom ([_ConnectedEmptyView]), so a floating pill would collide.
  ({Widget? action, PregoFloatingActionAlignment alignment}) _floatingAction({
    required BuildContext context,
    required ProjectListState state,
  }) {
    if (state is ProjectListLoaded && state.projects.isNotEmpty) {
      return (
        action: PregoButtonsIconGlass(
          icon: TablerRegular.folder_plus,
          size: PregoButtonsIconGlassSize.xl,
          iconSize: 22,
          onPressed: () => showAddProjectDialog(context, context.read<ProjectListCubit>()),
        ),
        alignment: PregoFloatingActionAlignment.end,
      );
    }
    // The onboarding/recovery surfaces get the same pill but report distinct
    // analytics surfaces, so help-seeking is attributable to the funnel step.
    // It reads as the page's own closing call to action rather than a corner
    // affordance, so the design centres it under the setup steps.
    if (state is ProjectListBridgeDisconnected) {
      return (
        action: _NeedHelpMenu(
          surface: state.hasRegisteredBridges ? OnboardingSurface.bridgeOffline : OnboardingSurface.connectSetup,
        ),
        alignment: PregoFloatingActionAlignment.center,
      );
    }
    return (action: null, alignment: PregoFloatingActionAlignment.end);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<ProjectListCubit>().state;
    final isRefreshing = state is ProjectListLoaded && state.isRefreshing;
    // The connect-your-computer onboarding (no bridge ever registered, none
    // connected) trades the collapsing large title for the compact
    // back-leading block, whose subtitle row reports the connection the body
    // is waiting on. Its body is a fixed setup checklist with nothing to
    // scroll a large title away against, and the design gives the waiting
    // status the bar's second line. Every other state keeps the large title.
    final isConnectOnboarding = state is ProjectListBridgeDisconnected && !state.hasRegisteredBridges;
    final floatingAction = _floatingAction(context: context, state: state);

    return PregoGlassScaffold(
      title: loc.projectListTitle,
      titleMode: isConnectOnboarding
          ? PregoTopNavigationTitleMode.backLeading
          : PregoTopNavigationTitleMode.collapsing,
      // With no back button leading it, the block is the page's own title, so
      // it takes the design's prominent weight rather than the muted one the
      // sessions bar uses beside its back button.
      leadingTitleEmphasis: PregoNavLeadingTitleEmphasis.prominent,
      subtitle: isConnectOnboarding
          ? PregoNavSubtitle(
              text: loc.projectsOnboardingWaitingForBridge,
              icon: TablerRegular.broadcast_off,
              status: PregoNavStatus.error,
            )
          : null,
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
      // Floating action, resolved per state: the add-project FAB once projects
      // exist, the "Need help?" support menu on the onboarding and
      // bridge-offline surfaces, and nothing while loading/errored.
      floatingActionButton: floatingAction.action,
      floatingActionAlignment: floatingAction.alignment,
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
  /// A non-empty loaded list always hosts it. The empty list normally owns
  /// the screen full-screen (its "Connected" caption would contradict an
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
          child: PregoShimmer(
            semanticLabel: context.loc.projectListLoadingSemantics,
            child: Column(
              children: [
                for (var i = 0; i < _skeletonRows; i++) const ProjectTileSkeleton(),
              ],
            ),
          ),
        ),
      ],
      // No bridge has ever been registered → setup onboarding; a bridge exists
      // but isn't running → ask to turn it on. Both join the page scroll rather
      // than nesting one of their own, so the large title scrolls away and
      // collapses into the bar with them. hasScrollBody: false lets a body
      // shorter than the viewport sit still while a taller one — the offline
      // view with its install commands expanded — scrolls the page.
      // SafeArea(top: false) keeps the last box clear of the home indicator.
      ProjectListBridgeDisconnected(:final hasRegisteredBridges, :final bridges) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: SafeArea(
            top: false,
            child: hasRegisteredBridges ? _BridgeOfflineView(bridges: bridges) : const _ConnectBridgeChecklist(),
          ),
        ),
      ],
      ProjectListLoaded(:final projects, :final activityById, :final unseenByProjectId, :final bridges) => [
        if (isRefreshing) const SliverToBoxAdapter(child: LinearProgressIndicator()),
        if (projects.isEmpty)
          // Same shape as the disconnected bodies above: the empty state joins
          // the page scroll rather than nesting one of its own.
          SliverFillRemaining(
            hasScrollBody: false,
            child: SafeArea(
              top: false,
              child: _ConnectedEmptyView(bridges: bridges),
            ),
          )
        else ...[
          // The rows carry their own padding and hairline, and the design sets
          // them flush against each other.
          SliverList.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              // Keyed so a recycled element can't carry one project's revealed
              // swipe actions onto another project's row.
              return ProjectTile(
                key: ValueKey(project.id),
                project: project,
                activeSessions: activityById[project.id] ?? 0,
                unseen: unseenByProjectId[project.id] ?? project.hasUnseenChanges,
              );
            },
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
