import "dart:async";

import "package:cupertino_ui/cupertino_ui.dart" show CupertinoColors, CupertinoDynamicColor;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:share_plus/share_plus.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/bridge_install.dart";
import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/extensions/text_style_x.dart";
import "../../core/external_link.dart";
import "../../core/routing/app_router.dart";
import "../../core/support_links.dart";
import "../../core/utils/copy_text_to_clipboard.dart";
import "../../core/widgets/catalog_scan_row.dart";
import "../../core/widgets/connection_banner.dart";
import "../../core/widgets/connection_graphic.dart";
import "../../core/widgets/remote_failure_view.dart";
import "add_project_dialog.dart";
import "widgets/project_tile.dart";

part "onboarding/onboarding_view.dart";
part "onboarding/why_bridge_info_sheet.dart";
part "widgets/bridge_offline_view.dart";

/// Enough placeholder rows to fill a phone screen while the first page loads.
const int _skeletonRows = 6;

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
        // The machine this account is paired with, resolved independently of the
        // project list: the bar names it in every state, and the bridge-offline
        // body says it is the machine it is trying to reach.
        BlocProvider(
          create: (_) => BridgeIdentityCubit(
            registeredBridgesService: getIt<RegisteredBridgesService>(),
            connectionService: getIt<ConnectionService>(),
          ),
        ),
      ],
      child: const _ProjectListBody(),
    );
  }
}

class const _ProjectListBody() extends StatefulWidget {
  @override
  State<_ProjectListBody> createState() => _ProjectListBodyState();
}

class _ProjectListBodyState() extends State<_ProjectListBody> {
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
  /// connected-but-empty state carries its own add-project call to action
  /// ([_ConnectedEmptyView]), which a floating pill would only duplicate.
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
    // The machine this account is paired with, resolved independently of the
    // list (see [BridgeIdentityCubit]): the bar's subtitle row names it and the
    // bridge-offline body reports it as the machine it is trying to reach.
    final identity = context.watch<BridgeIdentityCubit>().state;
    final namedBridge = switch (identity) {
      BridgeIdentityNamed(:final bridge) => bridge,
      BridgeIdentityPending() || BridgeIdentityUnnamed() => null,
    };
    // Green only while the relay↔bridge chain is fully connected — a hidden
    // banner alone is not enough, since the disconnected and unregistered
    // bridge-offline parks are bannerless too. Watching here re-runs this build
    // on connection changes; [_bannerFor] watches the same cubit below.
    final overlay = context.watch<ConnectionOverlayCubit>().state;
    final online = overlay is ConnectionOverlayHidden && overlay.connected;
    final floatingAction = _floatingAction(context: context, state: state);

    return PregoGlassScaffold(
      title: loc.projectListTitle,
      // The page wears the compact back-leading block in every state rather than
      // a collapsing large title: the design gives the bar's second line to the
      // machine this account is paired with, and keeping one bar shape across
      // loading, the list, and the two disconnected setup flows means the title
      // never changes size or place as the page moves between them.
      titleMode: PregoTopNavigationTitleMode.backLeading,
      // With no back button leading it, the block is the page's own title, so
      // it takes the design's prominent weight rather than the muted one the
      // sessions bar uses beside its back button.
      leadingTitleEmphasis: PregoNavLeadingTitleEmphasis.prominent,
      subtitle: _subtitle(context: context, state: state, identity: identity, online: online),
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
      // Only the loaded list can scan: the disconnected states pull to
      // reconnect, and there is nothing to scan into until the list is there.
      deepRefresh: state is ProjectListLoaded
          ? CatalogScanRow.deepRefresh(
              context: context,
              onStart: () => context.read<ProjectListCubit>().startCatalogScan(),
            )
          : null,
      slivers: _buildContentSlivers(
        context: context,
        state: state,
        isRefreshing: isRefreshing,
        bridge: namedBridge,
      ),
    );
  }

  /// The bar's subtitle row: the machine this account is paired with, in a
  /// single `text-xs` line under the page title.
  ///
  /// The same row on every state — only the status dot changes. The disconnected
  /// surfaces carry the error dot, because there not being connected *is* the
  /// page; every other state reports plain reachability, green while the
  /// relay↔bridge chain is up. Before any bridge is registered there is no
  /// machine to name at all, so that one surface reports what its setup
  /// checklist is waiting for instead.
  ///
  /// While the machine lookup has no answer yet the row holds its place with a
  /// shimmering skeleton rather than being left out: the title block would
  /// otherwise re-lay-out around the name as it lands. A lookup that answered
  /// with nothing to name drops the row for good.
  Widget? _subtitle({
    required BuildContext context,
    required ProjectListState state,
    required BridgeIdentityState identity,
    required bool online,
  }) {
    if (state case ProjectListBridgeDisconnected(hasRegisteredBridges: false)) {
      return PregoNavSubtitle(
        text: context.loc.projectsOnboardingWaitingForBridge,
        icon: TablerRegular.broadcast_off,
        status: PregoNavStatus.error,
      );
    }
    final status = switch (state) {
      ProjectListBridgeDisconnected() => PregoNavStatus.error,
      ProjectListLoading() ||
      ProjectListLoaded() ||
      ProjectListFailed() => online ? PregoNavStatus.online : PregoNavStatus.offline,
    };
    return switch (identity) {
      BridgeIdentityPending() => const PregoNavSubtitleSkeleton(),
      BridgeIdentityNamed(:final bridge) => PregoNavSubtitle(
        text: bridge.name,
        icon: TablerRegular.device_laptop,
        status: status,
      ),
      BridgeIdentityUnnamed() => null,
    };
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
    required BridgeSummary? bridge,
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
      // than nesting one of their own, so they scroll under the fixed bar.
      // hasScrollBody: false lets a body shorter than the viewport sit still
      // while a taller one — the offline view with its install commands
      // expanded — scrolls the page. SafeArea(top: false) keeps the last box
      // clear of the home indicator.
      ProjectListBridgeDisconnected(:final hasRegisteredBridges) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: SafeArea(
            top: false,
            child: hasRegisteredBridges ? _BridgeOfflineView(bridge: bridge) : const _ConnectBridgeChecklist(),
          ),
        ),
      ],
      ProjectListLoaded(:final projects, :final activityById, :final unseenByProjectId, :final catalogScan) => [
        if (isRefreshing) const SliverToBoxAdapter(child: LinearProgressIndicator()),
        SliverToBoxAdapter(
          child: CatalogScanRow(
            scan: catalogScan,
            onCancel: () => context.read<ProjectListCubit>().cancelCatalogScan(),
            onDismiss: () => context.read<ProjectListCubit>().dismissCatalogScan(),
          ),
        ),
        // Keep the list mounted at zero items so its final row can finish the
        // closing transition before the connected-empty view takes over.
        PregoAnimatedSliverList<ProjectSummary>(
          key: const ValueKey("project-list"),
          items: projects,
          itemKey: (project) => ValueKey(project.id),
          itemBuilder: (context, _, project) => ProjectTile(
            project: project,
            activeSessions: activityById[project.id] ?? 0,
            unseen: unseenByProjectId[project.id] ?? project.hasUnseenChanges,
          ),
        ),
        if (projects.isEmpty)
          // Same shape as the disconnected bodies above: the empty state joins
          // the page scroll rather than nesting one of its own.
          const SliverFillRemaining(
            hasScrollBody: false,
            child: SafeArea(
              top: false,
              child: _ConnectedEmptyView(),
            ),
          )
        else ...[
          // Clear the floating folder FAB and the home indicator.
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 96)),
        ],
      ],
      ProjectListFailed(:final reason) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: RemoteFailureView(
            reason: reason,
            title: context.loc.projectListErrorTitle,
            retryLabel: context.loc.projectListRetry,
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
    // One pull, one report — but only for a confirmation. Keyed on the scan row
    // showing anything at all, not on a scan being *live*: this read reaches
    // the same bridge the scan is working, so it resolves after the scan
    // finishes, by which point the row reads "Scan complete" and a live check
    // would already have gone false. A *failure* is never suppressed: the row
    // reports the scan, not this read, and a pull that silently did nothing is
    // worse than one toast too many.
    if (success) {
      if (context.read<ProjectListCubit>().state case ProjectListLoaded(catalogScan: final scan)
          when scan is! CatalogRescanIdle) {
        return;
      }
    }
    PregoPopupAlertPresenter.of(context).show(
      title: success ? loc.projectListRefreshSuccess : loc.projectListRefreshFailed,
      variant: success ? PregoPopupAlertsNotificationsVariant.success : PregoPopupAlertsNotificationsVariant.error,
    );
  }
}
