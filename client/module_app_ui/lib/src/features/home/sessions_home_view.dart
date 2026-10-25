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

/// Where [SessionsHomeView] shows, with what only that place needs.
sealed class const SessionsHomePresentation();

/// The phone's page: the project switcher is the title, the computer switcher
/// sits under it, and the bar holds New session, Archived and Settings.
final class const SessionsHomePage({
  /// Opens Archived, which shares the list's filter (D6).
  required final HomeAction onOpenArchived,
  required final HomeAction onOpenSettings,
  required final Widget? Function({required BuildContext context}) connectionBannerBuilder,

  /// Switches to a computer picked in the menu under the title.
  required final ComputerSwitchCallback onSwitchComputer,

  /// Opens the Computers page from the menu under the title.
  required final HomeAction onManageComputers,
}) extends SessionsHomePresentation;

/// The wide layout's sidebar body: New session, then the list with the project
/// switcher heading it under the search field (D4). The sidebar's footer holds
/// the rest (D10), and the content pane beside it the connection banner.
final class const SessionsHomeSidebar({
  /// The session the content pane beside the list shows, if any.
  required final String? selectedSessionId,
}) extends SessionsHomePresentation;

/// The signed-in home: the session list across projects, under a title that
/// filters it to one project and the computer it reaches.
///
/// It lists the scope's active [AllSessionsCubit]; product shells provide the
/// [BridgeIdentityCubit] and [ComputerSwitcherCubit] above it, and inject
/// routes, the disconnected pages and the connection banner.
class const SessionsHomeView({
  super.key,
  required final SessionsHomePresentation presentation,
  required final AllSessionsRowOpenedCallback onSessionTap,
  required final SessionListActionDispatcher actionDispatcher,
  required final ActionSessionListCubitFactory createActionCubit,

  /// Opens a new session in the list's default project, or with none chosen.
  required final HomeNewSessionCallback onNewSession,
  required final AllSessionsDisconnectedBuilder disconnectedBuilder,

  /// The empty state of a computer with no projects yet.
  required final Widget noProjectsState,
  required final HomeDisconnectedRefresh onRefreshDisconnected,
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
    final title = filterName ?? loc.projectPickerAllProjects;
    final isRefreshing = projects is ProjectListLoaded && projects.isRefreshing;
    void newSession() =>
        onNewSession(context: context, projectId: defaultProjectId, projectName: nameOf(defaultProjectId));
    // The switcher picks the one project the list shows.
    Widget switcher({required PregoPopoverTriggerBuilder triggerBuilder}) => ProjectPicker(
      selectedProjectId: projectId,
      onSelected: ({required projectId, required projectName}) => sessions.selectProject(projectId: projectId),
      onAllProjects: () => sessions.selectProject(projectId: null),
      triggerBuilder: triggerBuilder,
    );
    final onRefresh = switch (projects) {
      ProjectListLoaded() => () => _refresh(context: context),
      final ProjectListBridgeDisconnected disconnected => () => onRefreshDisconnected(
        context: context,
        state: disconnected,
      ),
      ProjectListLoading() || ProjectListFailed() => null,
    };
    List<Widget> slivers({required String? selectedSessionId, required Widget? header}) => [
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
        header: header,
      ),
    ];

    final SessionsHomePage page;
    switch (presentation) {
      case SessionsHomeSidebar(:final selectedSessionId):
        return CustomScrollView(
          physics: onRefresh == null
              ? const AlwaysScrollableScrollPhysics()
              : const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            if (onRefresh != null)
              PregoSliverRefreshControl(onRefresh: onRefresh, decorate: null, onPulledExtentChanged: null),
            SliverToBoxAdapter(
              child: _SidebarNewSession(key: const Key("home-new-session"), onPressed: newSession),
            ),
            ...slivers(
              selectedSessionId: selectedSessionId,
              header: switcher(
                triggerBuilder: (context, open) => _SidebarSwitcherHeading(title: title, onPressed: open),
              ),
            ),
          ],
        );
      case final SessionsHomePage pagePresentation:
        page = pagePresentation;
    }

    return PregoGlassScaffold(
      title: title,
      largeTitleTrailingIcon: TablerRegular.chevron_down,
      // The title is the filter.
      largeTitleBuilder: (context, title) => switcher(
        triggerBuilder: (context, open) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: open,
          child: Semantics(button: true, child: title),
        ),
      ),
      subtitle: homeComputerSubtitle(
        context: context,
        onSwitchComputer: page.onSwitchComputer,
        onManageComputers: page.onManageComputers,
      ),
      banner: _bannerFor(context: context, state: projects, page: page),
      actions: [
        PregoButtonsIconGlass(
          key: const Key("home-new-session"),
          icon: TablerRegular.plus,
          semanticLabel: loc.sessionListNewSession,
          onPressed: newSession,
        ),
        PregoButtonsIconGlass(
          key: const Key("home-archived"),
          icon: TablerRegular.archive,
          semanticLabel: loc.archivedSessionsTitle,
          onPressed: () => page.onOpenArchived(context: context),
        ),
        PregoButtonsIconGlass(
          icon: VESPRSolid.gear,
          semanticLabel: loc.settingsTitle,
          onPressed: () => page.onOpenSettings(context: context),
        ),
      ],
      onRefresh: onRefresh,
      // An open session covers the page, so no row is selected.
      slivers: slivers(selectedSessionId: null, header: null),
    );
  }

  /// The connection banner over a loaded list. A computer with no projects
  /// owns its screen with its own call to action, so it shows the banner only
  /// for a lost connection, which nothing else there reports. Loading and the
  /// disconnected pages report the connection themselves.
  static Widget? _bannerFor({
    required BuildContext context,
    required ProjectListState state,
    required SessionsHomePage page,
  }) {
    if (state is! ProjectListLoaded) return null;
    final banner = page.connectionBannerBuilder(context: context);
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

/// The computer this account is paired with, in a single line, and the
/// trigger of the computer menu: under the home's title, and in the sidebar's
/// footer (D10). Only the status dot changes with the state: the disconnected
/// pages carry the error dot, every other state plain reachability. Before any
/// bridge is registered there is no computer to name, so the line says what
/// setup is waiting for.
///
/// While the computer's name is unknown the line holds its place with a
/// skeleton, so nothing moves when the name lands.
Widget? homeComputerSubtitle({
  required BuildContext context,
  required ComputerSwitchCallback onSwitchComputer,
  required HomeAction onManageComputers,
}) {
  final state = context.watch<ProjectListCubit>().state;
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

/// The sidebar's first row: a new session in the list's default project.
class const _SidebarNewSession({super.key, required final VoidCallback onPressed}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(PregoSpacing.md, PregoSpacing.md, PregoSpacing.md, 0),
      child: Semantics(
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(PregoRadius.md),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.md, vertical: PregoSpacing.md),
            child: Row(
              spacing: PregoSpacing.md,
              children: [
                Icon(TablerRegular.plus, size: PregoIconSize.md, color: prego.colors.textPrimary),
                Expanded(
                  child: Text(
                    context.loc.sessionListNewSession,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: prego.textTheme.textMd.medium.copyWith(color: prego.colors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The project switcher heading the sidebar's list (D4): the filter's name,
/// opening the picker.
class const _SidebarSwitcherHeading({required final String title, required final VoidCallback onPressed})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(PregoSpacing.md, PregoSpacing.md, PregoSpacing.md, 0),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          button: true,
          child: InkWell(
            key: const Key("home-sidebar-switcher"),
            borderRadius: BorderRadius.circular(PregoRadius.md),
            onTap: onPressed,
            child: Padding(
              // Lines the title up with the search field and the rows.
              padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.md, vertical: PregoSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: PregoSpacing.xs,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: prego.textTheme.textLg.bold.copyWith(color: prego.colors.textPrimary),
                    ),
                  ),
                  Icon(TablerRegular.chevron_down, size: PregoIconSize.sm, color: prego.colors.textTertiary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
