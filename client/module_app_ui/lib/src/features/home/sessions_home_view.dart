import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../widgets/catalog_scan_row.dart";
import "../../widgets/computer_menu.dart";
import "../project_list/project_path_labels.dart";
import "../project_picker/project_picker.dart";
import "../session_list/all_sessions_list.dart";
import "../session_list/session_empty_state.dart";
import "../session_list/session_list_action_dispatcher.dart";

typedef HomeAction = void Function({required BuildContext context});

typedef HomeNewSessionCallback = void Function({
  required BuildContext context,
  required String? projectId,
  required String? projectName,
});

typedef HomeDisconnectedRefresh = Future<void> Function({
  required BuildContext context,
  required ProjectListBridgeDisconnected state,
});

/// The signed-in home: the session list across projects, under a title that
/// filters it to one project and the computer it reaches.
///
/// It lists the scope's active [AllSessionsCubit]; product shells provide the
/// [BridgeIdentityCubit] and [ComputerSwitcherCubit] above it, and inject
/// routes, the disconnected pages and the connection banner.
class const SessionsHomeView({
  super.key,

  /// The session the content pane beside the list shows, if any.
  required final String? selectedSessionId,
  required final AllSessionsRowOpenedCallback onSessionTap,
  required final SessionListActionDispatcher actionDispatcher,
  required final ActionSessionListCubitFactory createActionCubit,

  /// Opens a new session in the list's default project, or with none chosen.
  required final HomeNewSessionCallback onNewSession,

  /// Opens Archived, which shares the list's filter (D6).
  required final HomeAction onOpenArchived,
  required final HomeAction onOpenSettings,
  required final AllSessionsDisconnectedBuilder disconnectedBuilder,

  /// The empty state of a computer with no projects yet.
  required final Widget noProjectsState,
  required final Widget? Function({required BuildContext context}) connectionBannerBuilder,
  required final HomeDisconnectedRefresh onRefreshDisconnected,

  /// Switches to a computer picked in the menu under the title.
  required final ComputerSwitchCallback onSwitchComputer,

  /// Opens the Computers page from the menu under the title.
  required final HomeAction onManageComputers,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final projects = context.watch<ProjectListCubit>().state;
    final sessions = context.read<AllSessionsCubit>();
    final AllSessionsState(:projectId, :defaultProjectId) = context.watch<AllSessionsCubit>().state;
    String? nameOf(String? projectId) => switch (projects) {
      ProjectListLoaded(:final projects) => [
        for (final project in projects)
          if (project.id == projectId) projectDisplayName(loc: loc, project: project),
      ].firstOrNull,
      ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => null,
    };
    final filterName = nameOf(projectId);
    final isRefreshing = projects is ProjectListLoaded && projects.isRefreshing;

    return PregoGlassScaffold(
      title: filterName ?? loc.projectPickerAllProjects,
      largeTitleTrailingIcon: TablerRegular.chevron_down,
      // The title is the filter: it picks the one project the list shows.
      largeTitleBuilder: (context, title) => ProjectPicker(
        selectedProjectId: projectId,
        onSelected: ({required projectId, required projectName}) => sessions.selectProject(projectId: projectId),
        onAllProjects: () => sessions.selectProject(projectId: null),
        triggerBuilder: (context, open) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: open,
          child: Semantics(button: true, child: title),
        ),
      ),
      subtitle: _subtitle(context: context, state: projects),
      banner: _bannerFor(context: context, state: projects),
      actions: [
        PregoButtonsIconGlass(
          key: const Key("home-new-session"),
          icon: TablerRegular.plus,
          semanticLabel: loc.sessionListNewSession,
          onPressed: () => onNewSession(
            context: context,
            projectId: defaultProjectId,
            projectName: nameOf(defaultProjectId),
          ),
        ),
        PregoButtonsIconGlass(
          key: const Key("home-archived"),
          icon: TablerRegular.archive,
          semanticLabel: loc.archivedSessionsTitle,
          onPressed: () => onOpenArchived(context: context),
        ),
        PregoButtonsIconGlass(
          icon: VESPRSolid.gear,
          semanticLabel: loc.settingsTitle,
          onPressed: () => onOpenSettings(context: context),
        ),
      ],
      onRefresh: switch (projects) {
        ProjectListLoaded() => () => _refresh(context: context),
        final ProjectListBridgeDisconnected disconnected => () => onRefreshDisconnected(
          context: context,
          state: disconnected,
        ),
        ProjectListLoading() || ProjectListFailed() => null,
      },
      slivers: [
        if (isRefreshing) const SliverToBoxAdapter(child: LinearProgressIndicator()),
        if (projects is ProjectListLoaded)
          SliverToBoxAdapter(
            child: CatalogScanRow(scan: context.select((SessionListRefreshCubit refresh) => refresh.state.scan)),
          ),
        AllSessionsList(
          onSessionTap: onSessionTap,
          actionDispatcher: actionDispatcher,
          createActionCubit: createActionCubit,
          selectedSessionId: selectedSessionId,
          disconnectedBuilder: disconnectedBuilder,
          emptyState: projects is ProjectListLoaded && projects.projects.isEmpty
              ? SafeArea(top: false, child: noProjectsState)
              : SessionEmptyState(projectName: filterName),
        ),
      ],
    );
  }

  /// The computer this account is paired with, in a single line under the
  /// title, and the trigger of the computer menu. Only the status dot changes
  /// with the state: the disconnected pages carry the error dot, every other
  /// state plain reachability. Before any bridge is registered there is no
  /// computer to name, so the line says what setup is waiting for.
  ///
  /// While the computer's name is unknown the line holds its place with a
  /// skeleton, so the title does not move when the name lands.
  Widget? _subtitle({required BuildContext context, required ProjectListState state}) {
    if (state case ProjectListBridgeDisconnected(hasRegisteredBridges: false)) {
      return PregoNavSubtitle(
        text: context.loc.projectsOnboardingWaitingForBridge,
        icon: TablerRegular.broadcast_off,
        status: PregoNavStatus.error,
      );
    }
    // Green only while the relay-to-bridge chain is fully connected.
    final overlay = context.watch<ConnectionOverlayCubit>().state;
    final online = overlay is ConnectionOverlayHidden && overlay.connected;
    final status = switch (state) {
      ProjectListBridgeDisconnected() => PregoNavStatus.error,
      ProjectListLoading() ||
      ProjectListLoaded() ||
      ProjectListFailed() => online ? PregoNavStatus.online : PregoNavStatus.offline,
    };
    return switch (context.watch<BridgeIdentityCubit>().state) {
      BridgeIdentityPending() => const PregoNavSubtitleSkeleton(),
      BridgeIdentityNamed(:final bridge) => ComputerMenu(
        onSelect: ({required bridgeId}) => onSwitchComputer(bridgeId: bridgeId, source: ComputerSwitchSource.menu),
        // With one computer, management stays in Settings (plan decision D7).
        onManageComputers: context.watch<ComputerSwitcherCubit>().state.computers.length > 1
            ? () => onManageComputers(context: context)
            : null,
        triggerBuilder: (context, toggle) => PregoNavSubtitle(
          text: bridge.name,
          icon: TablerRegular.device_laptop,
          status: status,
          action: PregoNavSubtitleAction(onTap: toggle, semanticsHint: context.loc.computerMenuSwitchHint),
        ),
      ),
      BridgeIdentityUnnamed() => null,
    };
  }

  /// The connection banner over a loaded list. A computer with no projects
  /// owns its screen with its own call to action, so it shows the banner only
  /// for a lost connection, which nothing else there reports. Loading and the
  /// disconnected pages report the connection themselves.
  Widget? _bannerFor({required BuildContext context, required ProjectListState state}) {
    if (state is! ProjectListLoaded) return null;
    final banner = connectionBannerBuilder(context: context);
    if (state.projects.isNotEmpty) return banner;
    return context.watch<ConnectionOverlayCubit>().state is ConnectionOverlayConnectionLost ? banner : null;
  }

  /// Reloads the projects and their sessions and imports from every harness.
  static Future<void> _refresh({required BuildContext context}) async {
    final loc = context.loc;
    final success = await context.read<SessionListRefreshCubit>().refresh();
    if (!context.mounted) return;
    PregoPopupAlertPresenter.of(context).show(
      title: success ? loc.sessionListRefreshSuccess : loc.sessionListRefreshFailed,
      variant: success ? PregoPopupAlertsNotificationsVariant.success : PregoPopupAlertsNotificationsVariant.error,
    );
  }
}
