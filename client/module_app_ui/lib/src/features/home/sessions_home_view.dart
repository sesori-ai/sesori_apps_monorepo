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
  required NewSessionEntry entry,
});

typedef HomeDisconnectedRefresh = Future<void> Function({
  required BuildContext context,
  required ProjectListBridgeDisconnected state,
});

/// Where [SessionsHomeView] shows, with what only that place needs.
sealed class const SessionsHomePresentation();

/// The phone's page: the project switcher is the title, alone under the bar,
/// the bar holds the computer button and Settings, and New session floats at
/// the bottom right.
final class const SessionsHomePage({
  required final HomeAction onOpenSettings,
  required final Widget? Function({required BuildContext context}) connectionBannerBuilder,

  /// Switches to a computer picked in the computer button's menu.
  required final ComputerSwitchCallback onSwitchComputer,

  /// Opens the Computers page from the computer button's menu.
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
    void newSession({required NewSessionEntry entry}) => onNewSession(
      context: context,
      projectId: defaultProjectId,
      projectName: nameOf(defaultProjectId),
      entry: entry,
    );
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
    List<Widget> slivers({
      required String? selectedSessionId,
      required Widget? header,
      required double endClearance,
    }) => [
      if (isRefreshing) const SliverToBoxAdapter(child: LinearProgressIndicator()),
      // Mounted with the loading skeleton, so a scan already running is there
      // from the first frame and the projects arriving move nothing. A pull
      // to reconnect keeps the disconnected page up until the list loads, and
      // a scan it recovers waits for the list rather than shifting that page.
      if (projects is! ProjectListBridgeDisconnected)
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
        endClearance: endClearance,
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
              child: _SidebarNewSession(
                key: const Key("home-new-session"),
                onPressed: () => newSession(entry: const NewSessionEntry.platform()),
              ),
            ),
            ...slivers(
              selectedSessionId: selectedSessionId,
              endClearance: 0,
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
      banner: _bannerFor(context: context, state: projects, page: page),
      actions: [
        // In the wide sidebar footer's order: computer, Settings.
        _HomeComputerButton(onSwitchComputer: page.onSwitchComputer, onManageComputers: page.onManageComputers),
        PregoButtonsIconGlass(
          icon: VESPRSolid.gear,
          semanticLabel: loc.settingsTitle,
          onPressed: () => page.onOpenSettings(context: context),
        ),
      ],
      // The scaffold holds it still above the home indicator while the list
      // scrolls under it. The page it opens grows out of it.
      floatingActionButton: Builder(
        builder: (buttonContext) => PregoButtonsIconGlass(
          key: const Key("home-new-session"),
          icon: TablerRegular.plus,
          size: _newSessionButtonSize,
          iconSize: PregoIconSize.lg,
          semanticLabel: loc.sessionListNewSession,
          onPressed: () => newSession(entry: _revealFrom(buttonContext: buttonContext)),
        ),
      ),
      onRefresh: onRefresh,
      // An open session covers the page, so no row is selected.
      slivers: slivers(
        selectedSessionId: null,
        header: null,
        // The last row scrolls clear of the floating New session button.
        endClearance: _newSessionButtonSize.diameter + kFloatingActionButtonMargin,
      ),
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

/// The paired computer's status as its dot reports it: the disconnected pages
/// carry the error dot, every other state plain reachability, green only while
/// the relay-to-bridge chain is fully connected.
PregoNavStatus _computerStatus({required BuildContext context}) {
  final overlay = context.watch<ConnectionOverlayCubit>().state;
  final online = overlay is ConnectionOverlayHidden && overlay.connected;
  return switch (context.watch<ProjectListCubit>().state) {
    ProjectListBridgeDisconnected() => PregoNavStatus.error,
    ProjectListLoading() ||
    ProjectListLoaded() ||
    ProjectListFailed() => online ? PregoNavStatus.online : PregoNavStatus.offline,
  };
}

/// Opens the Computers page from the computer menu, which with one computer
/// leaves management to Settings (plan decision D7).
VoidCallback? _manageComputersFrom({required BuildContext context, required HomeAction onManageComputers}) =>
    context.watch<ComputerSwitcherCubit>().state.computers.length > 1
    ? () => onManageComputers(context: context)
    : null;

/// The computer this account is paired with, in a single line, and the
/// trigger of the computer menu, in the wide sidebar's footer (D10). Only the
/// status dot changes with the state. Before any bridge is registered there is
/// no computer to name, so the line says what setup is waiting for.
///
/// While the computer's name is unknown the line holds its place with a
/// skeleton, so nothing moves when the name lands.
Widget? homeComputerSubtitle({
  required BuildContext context,
  required ComputerSwitchCallback onSwitchComputer,
  required HomeAction onManageComputers,
}) {
  if (context.watch<ProjectListCubit>().state case ProjectListBridgeDisconnected(hasRegisteredBridges: false)) {
    return PregoNavSubtitle(
      text: context.loc.projectsOnboardingWaitingForBridge,
      icon: TablerRegular.broadcast_off,
      status: PregoNavStatus.error,
    );
  }
  final status = _computerStatus(context: context);
  return switch (context.watch<BridgeIdentityCubit>().state) {
    BridgeIdentityPending() => const PregoNavSubtitleSkeleton(),
    BridgeIdentityNamed(:final bridge) => ComputerMenu(
      onSelect: ({required bridgeId}) => onSwitchComputer(bridgeId: bridgeId, source: ComputerSwitchSource.menu),
      onManageComputers: _manageComputersFrom(context: context, onManageComputers: onManageComputers),
      currentFirst: false,
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

/// The phone bar's computer: a glyph whose corner dot reports the computer's
/// status, crossfading as it changes, and which opens the computer menu with
/// the current computer first, since the button does not name it.
///
/// It holds its place in every state, so the bar never shifts. Until a
/// computer is named it takes no taps and shows no dot: while the lookup runs
/// it looks as it will once named, and with no computer to name it looks
/// disabled.
class const _HomeComputerButton({
  required final ComputerSwitchCallback onSwitchComputer,
  required final HomeAction onManageComputers,
}) extends StatelessWidget {
  /// The dot's diameter, ring included.
  static const double _dotSize = 10;
  static const double _ringWidth = 2;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final identity = context.watch<BridgeIdentityCubit>().state;
    final status = _computerStatus(context: context);
    final name = switch (identity) {
      BridgeIdentityNamed(:final bridge) => bridge.name,
      BridgeIdentityPending() || BridgeIdentityUnnamed() => null,
    };
    final label = name == null
        ? loc.homeComputerButtonUnnamed
        : switch (status) {
            PregoNavStatus.online => loc.homeComputerButtonOnline(name),
            PregoNavStatus.offline => loc.homeComputerButtonConnecting(name),
            PregoNavStatus.error => loc.homeComputerButtonOffline(name),
          };
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    return ComputerMenu(
      onSelect: ({required bridgeId}) => onSwitchComputer(bridgeId: bridgeId, source: ComputerSwitchSource.menu),
      onManageComputers: _manageComputersFrom(context: context, onManageComputers: onManageComputers),
      currentFirst: true,
      triggerBuilder: (context, toggle) {
        final button = Stack(
          clipBehavior: Clip.none,
          children: [
            PregoButtonsIconGlass(
              key: const Key("home-computer"),
              icon: TablerRegular.device_laptop,
              semanticLabel: label,
              iconColor: identity is BridgeIdentityPending ? prego.colors.textPrimary : null,
              onPressed: name == null ? null : toggle,
            ),
            PositionedDirectional(
              end: 1,
              bottom: 1,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  width: _dotSize,
                  height: _dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: name == null ? Colors.transparent : status.dotColor(colors: prego.colors),
                    // Cut out of the button by the page's colour.
                    border: Border.all(
                      color: name == null ? Colors.transparent : prego.colors.bgSurface1,
                      width: _ringWidth,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
        return pointer ? Tooltip(message: label, excludeFromSemantics: true, child: button) : button;
      },
    );
  }
}

/// The phone page's floating New session button.
const PregoButtonsIconGlassSize _newSessionButtonSize = PregoButtonsIconGlassSize.xl;

/// A reveal from the centre of the button at [buttonContext], placed on the
/// navigator the page opens in.
NewSessionEntry _revealFrom({required BuildContext buttonContext}) {
  final button = buttonContext.findRenderObject();
  final pages = Overlay.of(buttonContext).context.findRenderObject();
  if (button is! RenderBox || pages is! RenderBox) throw StateError("The New session button is not laid out");
  final centre = button.localToGlobal(button.size.center(Offset.zero), ancestor: pages);
  return NewSessionEntry.reveal(x: centre.dx / pages.size.width, y: centre.dy / pages.size.height);
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
