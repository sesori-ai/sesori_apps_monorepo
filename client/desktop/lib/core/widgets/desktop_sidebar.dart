import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../di/injection.dart";
import "desktop_bridge_popover.dart";
import "desktop_bridge_recovery_card.dart";
import "desktop_session_signals.dart";
import "desktop_sidebar_activity_popout.dart";
import "desktop_sidebar_expansion.dart";
import "desktop_sidebar_section_header.dart";
import "desktop_window_drag_area.dart";

typedef SidebarSessionOpenedCallback = void Function({
  required BuildContext context,
  required ProjectSummary project,
  required String displayName,
  required Session session,
});

typedef _SidebarSessionMenuEntriesBuilder = List<PregoMenuEntry> Function({
  required SessionListCubit cubit,
  required Session session,
});

/// Desktop navigation frame. Its project inventory is shared with the main pane.
class const DesktopSidebar({
  super.key,

  /// Set on macOS, where the traffic lights sit on this panel's top: it makes
  /// room for them there, and that room drags and zooms the window.
  required final WindowHost? windowHost,
  required final bool autoCollapsed,
  required final String? selectedProjectId,
  required final String? selectedSessionId,
  required final SidebarSessionOpenedCallback onOpenSession,
  required final ProjectOpenedCallback onNewSession,
  required final VoidCallback onStartNewSession,
  required final SessionListActionDispatcher sessionActions,
  required final VoidCallback onToggleCollapsed,
  required final VoidCallback onOpenProjects,
  required final VoidCallback onAddProject,
  required final ProjectOpenedCallback onOpenProject,
  required final VoidCallback onOpenBridgeSettings,
  required final VoidCallback onOpenSettings,
}) extends StatelessWidget {
  /// The gap the shell keeps around this floating panel; what pops out beside
  /// the rail starts past it.
  static const double panelMargin = PregoSpacing.md;

  @override
  Widget build(BuildContext context) {
    final expansion = DesktopSidebarExpansion.of(context);
    final state = context.watch<ProjectListCubit>().state;
    final collapsedProjects = context.select((DesktopSidebarCubit cubit) => cubit.state.collapsedProjectIds);
    final loc = context.loc;
    final newSessionShortcut = defaultTargetPlatform == TargetPlatform.macOS ? "⌘N" : "Ctrl+N";
    final prego = context.prego;
    final bridge = context.watch<BridgeControlCubit>().state;
    final bridgeColor = desktopBridgeStatusColor(colors: prego.colors, state: bridge);
    return Material(
      color: prego.colors.bgSecondary,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            _TopStrip(windowHost: windowHost, expansion: expansion),
            // A quiet row, not a filled button: with no projects it offers to add one.
            _SidebarButton(
              key: const Key("desktop-sidebar-new-session"),
              label: state is ProjectListLoaded && state.projects.isEmpty ? loc.addProject : loc.sessionListNewSession,
              icon: const Icon(TablerRegular.plus, size: PregoIconSize.md),
              expansion: expansion,
              selected: false,
              status: null,
              shortcut: newSessionShortcut,
              onPressed: state is ProjectListLoaded ? onStartNewSession : null,
            ),
            DesktopSidebarPhaseBuilder(
              expansion: expansion,
              builder: (context, phase) => phase == DesktopSidebarPhase.open
                  ? const SizedBox.shrink()
                  : DesktopSidebarFold(
                      heightFactor: ReverseAnimation(expansion),
                      child: _SidebarButton(
                        key: const Key("desktop-sidebar-projects"),
                        label: loc.projectListTitle,
                        icon: const Icon(TablerRegular.folders, size: PregoIconSize.md),
                        expansion: kAlwaysDismissedAnimation,
                        selected: selectedProjectId == null,
                        status: null,
                        shortcut: null,
                        onPressed: onOpenProjects,
                      ),
                    ),
            ),
            Expanded(
              // Ink paints on the nearest Material, outside the list's own clip: this
              // one keeps a row's highlight from showing through the section above.
              child: Material(
                type: MaterialType.transparency,
                clipBehavior: Clip.hardEdge,
                child: switch (state) {
                  ProjectListLoading() => Center(
                    child: Semantics(
                      label: loc.projectListLoadingSemantics,
                      child: const PregoActivityIndicator(color: null),
                    ),
                  ),
                  ProjectListLoaded(:final projects, :final runningByProjectId, :final unseenByProjectId) =>
                    _SidebarInventory(
                      key: const Key("desktop-sidebar-inventory"),
                      projects: projects,
                      runningByProjectId: runningByProjectId,
                      unseenByProjectId: unseenByProjectId,
                      collapsedProjectIds: collapsedProjects,
                      expansion: expansion,
                      selectedProjectId: selectedProjectId,
                      selectedSessionId: selectedSessionId,
                      onOpenProject: onOpenProject,
                      onOpenSession: onOpenSession,
                      onNewSession: onNewSession,
                      onAddProject: onAddProject,
                      sessionActions: sessionActions,
                    ),
                  ProjectListFailed() => _SidebarButton(
                    label: loc.projectListRetry,
                    icon: const Icon(TablerRegular.refresh, size: PregoIconSize.md),
                    expansion: expansion,
                    selected: false,
                    status: null,
                    shortcut: null,
                    onPressed: () => unawaited(context.read<ProjectListCubit>().retryLoadProjects()),
                  ),
                  ProjectListBridgeDisconnected() => const SizedBox.shrink(),
                },
              ),
            ),
            _SidebarFooter(
              projectState: state,
              expansion: expansion,
              bridge: bridge,
              bridgeColor: bridgeColor,
              autoCollapsed: autoCollapsed,
              onToggleCollapsed: onToggleCollapsed,
              onOpenBridgeSettings: onOpenBridgeSettings,
              onOpenSettings: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}

/// The space above the panel's first control. On macOS the traffic lights sit
/// on the expanded panel, so it grows to clear them and stands in for the title
/// bar: it drags the window and zooms it on a double click.
class const _TopStrip({required final WindowHost? windowHost, required final Animation<double> expansion})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final windowHost = this.windowHost;
    if (windowHost == null) return const SizedBox(height: 12);
    return AnimatedBuilder(
      animation: expansion,
      builder: (context, _) {
        final height = 12 + 22 * expansion.value;
        return DesktopWindowDragArea(
          windowHost: windowHost,
          height: height,
          zoomOnDoubleClick: true,
          child: SizedBox(height: height, width: double.infinity),
        );
      },
    );
  }
}

/// Reloads projects and their sessions: on the Projects header while the sidebar is open, in the rail's footer.
class const _SidebarRefreshButton({
  required final ProjectListState projectState,
  required final double iconSize,
  required final Color? color,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final refresh = context.watch<DesktopSidebarRefreshCubit>();
    final refreshing =
        refresh.state == DesktopSidebarRefreshState.refreshing ||
        switch (projectState) {
          ProjectListLoaded(:final isRefreshing) => isRefreshing,
          ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => false,
        };
    final canRefresh = projectState is ProjectListLoaded && !refreshing;
    return IconButton(
      key: const Key("desktop-sidebar-refresh"),
      tooltip: refreshing ? loc.desktopSidebarRefreshing : loc.desktopSidebarRefresh,
      padding: EdgeInsets.zero,
      onPressed: canRefresh ? () => unawaited(refresh.refresh()) : null,
      icon: refreshing
          ? Semantics(
              label: loc.desktopSidebarRefreshing,
              child: ExcludeSemantics(
                child: SizedBox.square(dimension: iconSize, child: const PregoActivityIndicator(color: null)),
              ),
            )
          : Icon(TablerRegular.refresh, size: iconSize, color: color, semanticLabel: loc.desktopSidebarRefresh),
    );
  }
}

class const _SidebarFooter({
  required final ProjectListState projectState,
  required final Animation<double> expansion,
  required final BridgeControlState bridge,
  required final Color bridgeColor,
  required final bool autoCollapsed,
  required final VoidCallback onToggleCollapsed,
  required final VoidCallback onOpenBridgeSettings,
  required final VoidCallback onOpenSettings,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    Widget control(Widget button) => DesktopSidebarExpansionBuilder(
      expansion: expansion,
      builder: (expansion, button) => SizedBox.square(dimension: 28 + 8 * expansion, child: button),
      child: button,
    );
    final bridgeButton = PregoPopover(
      popoverWidth: 300,
      popoverMaxHeight: null,
      contentScrolls: false,
      onClosed: null,
      triggerBuilder: (context, toggle) => _SidebarButton(
        label: loc.desktopSettingsThisComputer,
        icon: const Icon(TablerRegular.server, size: PregoIconSize.md),
        expansion: expansion,
        selected: false,
        // A status dot, not a glyph: no icon token applies.
        status: (
          icon: Icon(TablerSolid.circle, size: 8, color: bridgeColor),
          label: bridge.statusLabel,
          detail: null,
        ),
        shortcut: null,
        onPressed: toggle,
      ),
      contentBuilder: (context, close) => DesktopBridgePopover(
        close: close,
        onOpenSettings: onOpenBridgeSettings,
      ),
    );
    final refresh = control(_SidebarRefreshButton(projectState: projectState, iconSize: PregoIconSize.md, color: null));
    final controls = [
      control(
        IconButton(
          key: const Key("desktop-sidebar-settings"),
          tooltip: loc.desktopShortcutHint(
            loc.settingsTitle,
            defaultTargetPlatform == TargetPlatform.macOS ? "⌘," : "Ctrl+,",
          ),
          padding: const EdgeInsets.all(PregoSpacing.sm),
          onPressed: onOpenSettings,
          icon: Icon(TablerRegular.settings, size: PregoIconSize.md, semanticLabel: loc.settingsTitle),
        ),
      ),
      control(
        DesktopSidebarExpansionSelector(
          expansion: expansion,
          select: (expansion) => expansion < 0.5,
          builder: (context, railed) {
            final toggleLabel = railed ? loc.desktopSidebarExpand : loc.desktopSidebarCollapse;
            return IconButton(
              key: const Key("desktop-sidebar-toggle"),
              tooltip: autoCollapsed
                  ? toggleLabel
                  : loc.desktopShortcutHint(
                      toggleLabel,
                      defaultTargetPlatform == TargetPlatform.macOS ? "⌘B" : "Ctrl+B",
                    ),
              padding: const EdgeInsets.all(PregoSpacing.sm),
              onPressed: autoCollapsed ? null : onToggleCollapsed,
              icon: Icon(
                railed ? TablerRegular.layout_sidebar_left_expand : TablerRegular.layout_sidebar_left_collapse,
                size: PregoIconSize.md,
                color: autoCollapsed ? prego.colors.textDisabled : null,
              ),
            );
          },
        ),
      ),
    ];
    return BlocListener<DesktopSidebarRefreshCubit, DesktopSidebarRefreshState>(
      listenWhen: (_, current) =>
          current == DesktopSidebarRefreshState.succeeded || current == DesktopSidebarRefreshState.failed,
      listener: (context, state) {
        final succeeded = state == DesktopSidebarRefreshState.succeeded;
        PregoPopupAlertPresenter.of(context).show(
          title: succeeded ? loc.desktopSidebarRefreshSuccess : loc.desktopSidebarRefreshFailed,
          variant: succeeded
              ? PregoPopupAlertsNotificationsVariant.success
              : PregoPopupAlertsNotificationsVariant.error,
        );
      },
      child: Container(
        key: const Key("desktop-sidebar-footer"),
        decoration: BoxDecoration(
          color: prego.colors.bgSurface1,
          border: Border(top: BorderSide(color: prego.colors.borderPrimary)),
        ),
        child: Column(
          children: [
            DesktopSidebarPhaseBuilder(
              expansion: expansion,
              builder: (context, phase) => DesktopBridgeRecoveryCard(compact: phase != DesktopSidebarPhase.open),
            ),
            // Open, the footer is one row; the rail stacks it and fits two controls a line.
            DesktopSidebarPhaseBuilder(
              expansion: expansion,
              builder: (context, phase) => phase == DesktopSidebarPhase.open
                  ? SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          Expanded(child: bridgeButton),
                          // Refresh sits on the Projects header while the sidebar is open.
                          ...controls,
                          const SizedBox(width: PregoSpacing.xs),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: PregoSpacing.xs),
                      child: Column(
                        children: [
                          bridgeButton,
                          Wrap(alignment: WrapAlignment.center, children: [refresh, ...controls]),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class const _SidebarInventory({
  super.key,
  required final List<ProjectSummary> projects,
  required final Map<String, int> runningByProjectId,
  required final Map<String, bool> unseenByProjectId,
  required final Set<String> collapsedProjectIds,
  required final Animation<double> expansion,
  required final String? selectedProjectId,
  required final String? selectedSessionId,
  required final SidebarSessionOpenedCallback onOpenSession,
  required final ProjectOpenedCallback onNewSession,
  required final VoidCallback onAddProject,
  required final SessionListActionDispatcher sessionActions,
  required final ProjectOpenedCallback onOpenProject,
}) extends StatefulWidget {
  @override
  State<_SidebarInventory> createState() => _SidebarInventoryState();
}

class _SidebarInventoryState() extends State<_SidebarInventory> {
  // The Activity session the user just opened stays listed while selected,
  // even once opening it has marked it seen (sessions never jump lists).
  String? _stickyActivitySessionId;
  // Activity as last built, read only when the selection changes: by then the
  // opened session may already be seen and gone from a fresh projection.
  Set<String> _activitySessionIds = const {};

  @override
  void didUpdateWidget(_SidebarInventory oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selectedSessionId;
    if (selected == oldWidget.selectedSessionId) return;
    _stickyActivitySessionId = _activitySessionIds.contains(selected) ? selected : null;
  }

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<RecentSessionsCubit>().state;
    final projection = DesktopSidebarSessionProjection.from(
      projects: widget.projects,
      entries: entries,
      deferredSessions: context.select((DesktopSidebarCubit cubit) => cubit.state.deferredSessions),
      hiddenSessionIds: context.select((PendingSessionArchiveCubit cubit) => cubit.state.hiddenIds),
      stickySessionId: _stickyActivitySessionId,
    );
    final activityFolded = context.select((DesktopSidebarCubit cubit) => cubit.state.activitySectionCollapsed);
    final projectsFolded = context.select((DesktopSidebarCubit cubit) => cubit.state.projectsSectionCollapsed);
    final activitySessions = [for (final group in projection.activityGroups) ...group.sessions];
    _activitySessionIds = {for (final item in activitySessions) item.session.id};
    final activityRunning = activitySessions.where((item) => item.isRunning).length;
    // A sticky row is seen and idle, so the button says only what its rows' flags say.
    final activityStatuses = [
      if (activityRunning > 0) context.loc.projectListRunning(activityRunning),
      if (activitySessions.any((item) => item.isAwaitingInput)) context.loc.sessionListAwaitingInput,
      if (activitySessions.any((item) => item.isUnseen)) context.loc.projectListNewActivity,
    ];
    List<PregoMenuEntry> buildSessionMenuEntries({
      required SessionListCubit cubit,
      required Session session,
    }) => widget.sessionActions.sessionMenuEntries(
      context: context,
      cubit: cubit,
      session: session,
      readEntry: SessionReadMenuEntry.toggle,
    );
    Widget gutter(Widget sliver) => DesktopSidebarExpansionBuilder(
      expansion: widget.expansion,
      builder: (expansion, sliver) => SliverPadding(
        padding: EdgeInsetsDirectional.only(end: PregoSpacing.xl * expansion),
        sliver: sliver,
      ),
      child: sliver,
    );
    // The rail has no headers to unfold a section with, so it ignores folding;
    // its Activity is one button whose list pops out.
    return DesktopSidebarExpansionSelector(
      expansion: widget.expansion,
      select: (expansion) => expansion < 0.5,
      builder: (context, railed) => CustomScrollView(
        key: const Key("desktop-sidebar-project-list"),
        slivers: [
          if (railed && activitySessions.isNotEmpty)
            SliverToBoxAdapter(
              child: DesktopSidebarActivityPopout(
                railStart: DesktopSidebar.panelMargin,
                triggerBuilder: (_, toggle) => _SidebarButton(
                  key: const Key("desktop-sidebar-rail-activity"),
                  label: context.loc.desktopSidebarActivity(activitySessions.length),
                  icon: PregoAiLoader(size: 20, animate: activityRunning > 0),
                  expansion: kAlwaysDismissedAnimation,
                  selected: false,
                  status: (
                    icon: _CountPill(count: activitySessions.length),
                    label: activityStatuses.isEmpty ? null : activityStatuses.join(", "),
                    detail: null,
                  ),
                  shortcut: null,
                  onPressed: toggle,
                ),
                // The popout sits on the root navigator, outside the cockpit's
                // providers, so the sidebar hands over the cubits its rows watch.
                contentBuilder: (_, close) => MultiBlocProvider(
                  providers: [
                    BlocProvider.value(value: context.read<RecentSessionsCubit>()),
                    BlocProvider.value(value: context.read<DesktopSidebarCubit>()),
                    BlocProvider.value(value: context.read<PendingSessionArchiveCubit>()),
                  ],
                  child: _SidebarActivityPopoutList(
                    close: close,
                    projects: widget.projects,
                    stickySessionId: _stickyActivitySessionId,
                    selectedProjectId: widget.selectedProjectId,
                    selectedSessionId: widget.selectedSessionId,
                    onOpenSession: ({required context, required project, required displayName, required session}) {
                      close();
                      widget.onOpenSession(
                        context: this.context,
                        project: project,
                        displayName: displayName,
                        session: session,
                      );
                    },
                    sessionMenuEntries: buildSessionMenuEntries,
                  ),
                ),
              ),
            ),
          gutter(
            SliverToBoxAdapter(
              key: const Key("desktop-sidebar-activity-header"),
              child: DesktopSidebarSectionHeader(
                label: context.loc.desktopSidebarActivity(_activitySessionIds.length),
                collapsed: activityFolded,
                expansion: projection.activityGroups.isEmpty ? kAlwaysDismissedAnimation : widget.expansion,
                onToggle: () => unawaited(context.read<DesktopSidebarCubit>().toggleActivitySection()),
                action: null,
              ),
            ),
          ),
          gutter(
            PregoAnimatedSliverList<DesktopSidebarActivityGroup>(
              key: const Key("desktop-sidebar-activity-list"),
              items: railed || activityFolded ? const [] : projection.activityGroups,
              itemKey: (group) => ValueKey(group.project.id),
              itemBuilder: (context, _, group) {
                final projectName = desktopProjectDisplayName(context: context, project: group.project);
                return _SidebarActivityProjectGroup(
                  key: ValueKey("sidebar-activity-${group.project.id}"),
                  group: group,
                  projectName: projectName,
                  expansion: widget.expansion,
                  // The open session is highlighted once, under its project.
                  selectedSessionId: null,
                  onOpenSession: widget.onOpenSession,
                  sessionMenuEntries: buildSessionMenuEntries,
                );
              },
            ),
          ),
          gutter(
            SliverToBoxAdapter(
              child: DesktopSidebarSectionHeader(
                key: const Key("desktop-sidebar-projects-header"),
                label: context.loc.projectListTitle,
                collapsed: projectsFolded,
                expansion: widget.expansion,
                onToggle: () => unawaited(context.read<DesktopSidebarCubit>().toggleProjectsSection()),
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Until the sidebar is fully open, the footer still carries refresh.
                    DesktopSidebarPhaseBuilder(
                      expansion: widget.expansion,
                      builder: (context, phase) => phase == DesktopSidebarPhase.open
                          ? SizedBox.square(
                              dimension: 28,
                              child: _SidebarRefreshButton(
                                projectState: context.watch<ProjectListCubit>().state,
                                iconSize: PregoIconSize.sm,
                                color: context.prego.colors.textSecondary,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    SizedBox.square(
                      dimension: 28,
                      child: IconButton(
                        key: const Key("desktop-sidebar-new-project"),
                        padding: EdgeInsets.zero,
                        tooltip: context.loc.desktopSidebarNewProject,
                        onPressed: widget.onAddProject,
                        icon: Icon(
                          TablerRegular.folder_plus,
                          size: PregoIconSize.sm,
                          color: context.prego.colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          gutter(
            PregoAnimatedSliverList<ProjectSummary>(
              key: const Key("desktop-sidebar-project-groups"),
              items: railed || !projectsFolded ? widget.projects : const [],
              itemKey: (project) => ValueKey(project.id),
              itemBuilder: (context, _, project) {
                final projectName = desktopProjectDisplayName(context: context, project: project);
                final entry = entries[project.id];
                return _SidebarProjectGroup(
                  key: ValueKey(project.id),
                  project: project,
                  name: projectName,
                  running: widget.runningByProjectId[project.id] ?? 0,
                  unseen: widget.unseenByProjectId[project.id] ?? project.hasUnseenChanges,
                  entry: entry,
                  expansion: widget.expansion,
                  expanded: !widget.collapsedProjectIds.contains(project.id),
                  selected: project.id == widget.selectedProjectId,
                  selectedSessionId: project.id == widget.selectedProjectId ? widget.selectedSessionId : null,
                  onOpenProject: widget.onOpenProject,
                  onOpenSession: widget.onOpenSession,
                  onNewSession: widget.onNewSession,
                  sessionMenuEntries: buildSessionMenuEntries,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The Activity rows as the rail pops them out, live while the popout is open.
class const _SidebarActivityPopoutList({
  required final VoidCallback close,
  required final List<ProjectSummary> projects,
  required final String? stickySessionId,
  required final String? selectedProjectId,
  required final String? selectedSessionId,
  required final SidebarSessionOpenedCallback onOpenSession,
  required final _SidebarSessionMenuEntriesBuilder sessionMenuEntries,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final projection = DesktopSidebarSessionProjection.from(
      projects: projects,
      entries: context.watch<RecentSessionsCubit>().state,
      deferredSessions: context.select((DesktopSidebarCubit cubit) => cubit.state.deferredSessions),
      hiddenSessionIds: context.select((PendingSessionArchiveCubit cubit) => cubit.state.hiddenIds),
      stickySessionId: stickySessionId,
    );
    // The last row left the open popout: close it rather than leave an empty
    // bubble. [close] pops the top route, so only while this route is that one.
    final route = ModalRoute.of(context);
    if (projection.activityGroups.isEmpty && route != null && route.isCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isCurrent) close();
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final group in projection.activityGroups)
          _SidebarActivityProjectGroup(
            key: ValueKey("sidebar-activity-${group.project.id}"),
            group: group,
            projectName: desktopProjectDisplayName(context: context, project: group.project),
            expansion: kAlwaysCompleteAnimation,
            selectedSessionId: group.project.id == selectedProjectId ? selectedSessionId : null,
            onOpenSession: onOpenSession,
            sessionMenuEntries: sessionMenuEntries,
          ),
      ],
    );
  }
}

class const _SidebarActivityProjectGroup({
  super.key,
  required final DesktopSidebarActivityGroup group,
  required final String projectName,
  required final Animation<double> expansion,
  required final String? selectedSessionId,
  required final SidebarSessionOpenedCallback onOpenSession,
  required final _SidebarSessionMenuEntriesBuilder sessionMenuEntries,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider<SessionListCubit>(
    create: (_) => createSessionListCubit(
      locator: getIt,
      projectId: group.project.id,
      mode: SessionListMode.actions(sessions: group.sourceSessions),
    ),
    child: Builder(
      builder: (actionContext) => PregoAnimatedList<DesktopSidebarActivitySession>(
        items: group.sessions,
        itemKey: (item) => ValueKey(item.session.id),
        itemBuilder: (context, _, item) => _SidebarActivitySessionRow(
          key: ValueKey("sidebar-activity-session-${group.project.id}-${item.session.id}"),
          item: item,
          projectName: projectName,
          selected: item.session.id == selectedSessionId,
          expansion: expansion,
          onPressed: () => onOpenSession(
            context: actionContext,
            project: group.project,
            displayName: projectName,
            session: item.session,
          ),
          acquireMenuLease: () => actionContext.read<SessionListCubit>().retainActionScope(),
          menuEntries: () {
            final cubit = actionContext.read<SessionListCubit>()..updateActionSession(session: item.session);
            return sessionMenuEntries(cubit: cubit, session: item.session);
          },
        ),
      ),
    ),
  );
}

class const _SidebarProjectGroup({
  super.key,
  required final ProjectSummary project,
  required final String name,
  required final int running,
  required final bool unseen,
  required final RecentSessionsEntry? entry,
  required final Animation<double> expansion,
  required final bool expanded,
  required final bool selected,
  required final String? selectedSessionId,
  required final ProjectOpenedCallback onOpenProject,
  required final SidebarSessionOpenedCallback onOpenSession,
  required final ProjectOpenedCallback onNewSession,
  required final _SidebarSessionMenuEntriesBuilder sessionMenuEntries,
}) extends StatefulWidget {
  @override
  State<_SidebarProjectGroup> createState() => _SidebarProjectGroupState();
}

class _SidebarProjectGroupState() extends State<_SidebarProjectGroup> {
  static const int _initialRows = 3;
  static const int _moreRows = 10;
  bool _hovered = false;
  bool _focused = false;
  // Show more grows this in place; folding the project starts over.
  int _rowLimit = _initialRows;

  @override
  void didUpdateWidget(_SidebarProjectGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.expanded) _rowLimit = _initialRows;
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    // A session being archived leaves its project at once.
    final hidden = context.select((PendingSessionArchiveCubit cubit) => cubit.state.hiddenIds);
    final rows = entry is RecentSessionsLoaded
        ? entry
              .rows(selectedSessionId: widget.selectedSessionId, limit: _rowLimit)
              .where((session) => !hidden.contains(session.id))
              .toList()
        : const <Session>[];
    final loc = context.loc;
    final detailStyle = context.prego.textTheme.textXs.regular;
    // With one of its sessions open, the session row carries the highlight.
    final projectSelected = widget.selected && widget.selectedSessionId == null;
    // Created only if a session menu reads it. Keep this scope above the rows:
    // a successful delete can remove its row before the route callback runs.
    return BlocProvider<SessionListCubit>(
      create: (_) => createSessionListCubit(
        locator: getIt,
        projectId: widget.project.id,
        mode: SessionListMode.actions(sessions: entry is RecentSessionsLoaded ? entry.sourceSessions : const []),
      ),
      child: Builder(
        builder: (actionContext) {
          final sessions = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              switch (entry) {
                RecentSessionsLoaded() => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PregoAnimatedList<Session>(
                      items: rows,
                      itemKey: (session) => ValueKey(session.id),
                      itemBuilder: (context, _, session) => _SidebarSessionRow(
                        key: ValueKey("sidebar-session-${widget.project.id}-${session.id}"),
                        session: session,
                        entry: entry,
                        selected: session.id == widget.selectedSessionId,
                        expansion: widget.expansion,
                        onPressed: () => widget.onOpenSession(
                          context: actionContext,
                          project: widget.project,
                          displayName: widget.name,
                          session: session,
                        ),
                        acquireMenuLease: () => actionContext.read<SessionListCubit>().retainActionScope(),
                        menuEntries: () {
                          final cubit = actionContext.read<SessionListCubit>()..updateActionSession(session: session);
                          return widget.sessionMenuEntries(cubit: cubit, session: session);
                        },
                      ),
                    ),
                    if (entry.visibleSessions.where((s) => !hidden.contains(s.id)).length - rows.length case final more
                        when more > 0)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 46, end: 8),
                        child: TextButton(
                          key: ValueKey("sidebar-show-more-${widget.project.id}"),
                          style: TextButton.styleFrom(
                            alignment: AlignmentDirectional.centerStart,
                            foregroundColor: context.prego.colors.textTertiary,
                            minimumSize: const Size(0, 28),
                            padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xs),
                          ),
                          onPressed: () => setState(() => _rowLimit += _moreRows),
                          child: Text(
                            loc.desktopSidebarShowMore(more < _moreRows ? more : _moreRows),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: detailStyle.copyWith(color: context.prego.colors.textTertiary),
                          ),
                        ),
                      ),
                  ],
                ),
                RecentSessionsFailed() => TextButton.icon(
                  onPressed: () => unawaited(context.read<RecentSessionsCubit>().retry(projectId: widget.project.id)),
                  icon: const Icon(TablerRegular.refresh, size: PregoIconSize.sm),
                  label: Text(loc.sessionListRetry, style: detailStyle),
                ),
                RecentSessionsLoading() || null => Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(50, 4, 8, 4),
                  child: Text(
                    loc.sessionListLoadingSemantics,
                    style: detailStyle,
                  ),
                ),
              },
            ],
          );
          return Focus(
            canRequestFocus: false,
            onFocusChange: (focused) => setState(() => _focused = focused),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MouseRegion(
                  onEnter: (_) => setState(() => _hovered = true),
                  onExit: (_) => setState(() => _hovered = false),
                  child: Row(
                    children: [
                      Expanded(
                        child: PregoAnchorMenu(
                          flat: true,
                          menuWidth: 200,
                          acquireOpenLease: null,
                          entriesBuilder: () =>
                              ProjectTile.menuEntries(context: actionContext, project: widget.project),
                          triggerBuilder: (_, openMenu) => GestureDetector(
                            onSecondaryTap: openMenu,
                            onLongPress: openMenu,
                            child: _SidebarButton(
                              label: widget.name,
                              icon: PregoAvatarInitials(label: widget.name, size: 26),
                              expansion: widget.expansion,
                              selected: projectSelected,
                              status: widget.running > 0 || widget.unseen
                                  ? (
                                      icon: PregoAiLoader(size: 18, animate: widget.running > 0),
                                      label: widget.running > 0
                                          ? widget.unseen
                                                ? "${loc.projectListRunning(widget.running)}, ${loc.projectListNewActivity}"
                                                : loc.projectListRunning(widget.running)
                                          : loc.projectListNewActivity,
                                      detail: widget.running > 0 ? loc.projectListRunning(widget.running) : null,
                                    )
                                  : null,
                              shortcut: null,
                              onPressed: () => widget.onOpenProject(
                                context: actionContext,
                                project: widget.project,
                                displayName: widget.name,
                              ),
                            ),
                          ),
                        ),
                      ),
                      DesktopSidebarPhaseBuilder(
                        expansion: widget.expansion,
                        builder: (context, phase) => phase == DesktopSidebarPhase.rail
                            ? const SizedBox.shrink()
                            : DesktopSidebarExpansionBuilder(
                                expansion: widget.expansion,
                                builder: (expansion, controls) => ColoredBox(
                                  color: projectSelected ? _selectedFill(context.prego.colors) : Colors.transparent,
                                  child: SizedBox(width: 48 * expansion, height: 36, child: controls),
                                ),
                                child: ClipRect(
                                  child: FadeTransition(
                                    opacity: widget.expansion,
                                    child: OverflowBox(
                                      minWidth: 48,
                                      maxWidth: 48,
                                      // The row stays quiet until the pointer or focus reaches it.
                                      child: Opacity(
                                        opacity: _hovered || _focused ? 1 : 0,
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 24,
                                              height: 28,
                                              child: IconButton(
                                                key: ValueKey("sidebar-new-session-${widget.project.id}"),
                                                padding: EdgeInsets.zero,
                                                tooltip: widget.selected
                                                    ? loc.desktopShortcutHint(
                                                        loc.desktopSidebarNewSession(widget.name),
                                                        defaultTargetPlatform == TargetPlatform.macOS ? "⌘N" : "Ctrl+N",
                                                      )
                                                    : loc.desktopSidebarNewSession(widget.name),
                                                icon: const Icon(TablerRegular.plus, size: PregoIconSize.sm),
                                                onPressed: () => widget.onNewSession(
                                                  context: actionContext,
                                                  project: widget.project,
                                                  displayName: widget.name,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 24,
                                              height: 28,
                                              child: IconButton(
                                                key: ValueKey("sidebar-project-toggle-${widget.project.id}"),
                                                padding: EdgeInsets.zero,
                                                tooltip: widget.expanded
                                                    ? loc.desktopSidebarCollapseProject(widget.name)
                                                    : loc.desktopSidebarExpandProject(widget.name),
                                                icon: Icon(
                                                  widget.expanded
                                                      ? TablerRegular.chevron_down
                                                      : TablerRegular.chevron_right,
                                                  size: PregoIconSize.sm,
                                                ),
                                                onPressed: () => unawaited(
                                                  context.read<DesktopSidebarCubit>().toggleProject(
                                                    projectId: widget.project.id,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                // The rows are built outside the phase builder, so they are not
                // rebuilt when the fold appears or goes.
                if (widget.expanded)
                  DesktopSidebarPhaseBuilder(
                    expansion: widget.expansion,
                    builder: (context, phase) => phase == DesktopSidebarPhase.rail
                        ? const SizedBox.shrink()
                        : DesktopSidebarFold(heightFactor: widget.expansion, child: sessions),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class const _SidebarActivitySessionRow({
  super.key,
  required final DesktopSidebarActivitySession item,
  required final String projectName,
  required final bool selected,
  required final Animation<double> expansion,
  required final VoidCallback onPressed,
  required final PregoMenuOpenLease acquireMenuLease,
  required final List<PregoMenuEntry> Function() menuEntries,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final title = item.session.title ?? context.loc.sessionListUntitled;
    final identity = context.loc.desktopSidebarActivitySession(title, projectName);
    final statuses = _sessionStatusLabels(
      context: context,
      isAwaitingInput: item.isAwaitingInput,
      isRunning: item.isRunning,
      isUnseen: item.isUnseen,
    );
    // A running session is happening now; its spinning sparkle says so.
    final updatedAt = item.isRunning ? null : item.session.time?.updated;
    // The row's "3h" is a glance mark; the label says it in full.
    final description = [identity, ...statuses, if (updatedAt != null) context.formatTimestamp(updatedAt)].join(", ");
    return DesktopSidebarPhaseBuilder(
      expansion: expansion,
      builder: (context, phase) {
        final signals = SizedBox(
          width: DesktopSessionSignals.width,
          height: DesktopSessionSignals.width,
          child: Center(
            child: DesktopSessionSignals(
              isAwaitingInput: item.isAwaitingInput,
              isRunning: item.isRunning,
              isUnseen: item.isUnseen,
            ),
          ),
        );
        final labels = phase == DesktopSidebarPhase.rail
            ? null
            : Expanded(
                child: ClipRect(
                  child: FadeTransition(
                    opacity: expansion,
                    child: _LabelInset(
                      expansion: expansion,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TooltipWhenTruncated(
                            message: title,
                            style: _sessionTitleStyle(context: context, unseen: item.isUnseen),
                          ),
                          _TooltipWhenTruncated(
                            message: projectName,
                            style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
        final time = updatedAt == null || phase == DesktopSidebarPhase.rail
            ? null
            : FadeTransition(
                opacity: expansion,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
                  child: Text(
                    context.formatTimestampCompact(ms: updatedAt),
                    maxLines: 1,
                    style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
                  ),
                ),
              );
        return PregoAnchorMenu(
          flat: true,
          menuWidth: 220,
          acquireOpenLease: acquireMenuLease,
          entriesBuilder: menuEntries,
          triggerBuilder: (_, openMenu) => GestureDetector(
            onSecondaryTap: openMenu,
            child: Semantics(
              button: true,
              selected: selected,
              label: description,
              onTap: onPressed,
              onLongPress: openMenu,
              excludeSemantics: true,
              child: _ConditionalTooltip(
                enabled: phase != DesktopSidebarPhase.open,
                message: description,
                child: InkWell(
                  onTap: onPressed,
                  onLongPress: openMenu,
                  child: DesktopSidebarExpansionBuilder(
                    expansion: expansion,
                    // The rail centres the signals; the open sidebar lines them up with the project rows.
                    builder: (expansion, content) => Ink(
                      padding: EdgeInsets.symmetric(horizontal: 14 + 2 * expansion, vertical: 6),
                      color: selected ? _selectedFill(prego.colors) : null,
                      child: content,
                    ),
                    // The parts are built once: the row's width changes every
                    // frame the rail animates, and only the layout follows it.
                    child: LayoutBuilder(
                      builder: (context, constraints) => Row(
                        children: [
                          signals,
                          ?labels,
                          if (time != null && _rowFitsTime(context: context, width: constraints.maxWidth)) time,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Whether a row this wide has room for its time beside the title. The
/// collapsing rail passes through narrower rows, and larger text needs a wider one.
bool _rowFitsTime({required BuildContext context, required double width}) =>
    width >= MediaQuery.textScalerOf(context).scale(104);

class const _SidebarSessionRow({
  super.key,
  required final Session session,
  required final RecentSessionsLoaded entry,
  required final bool selected,
  required final Animation<double> expansion,
  required final VoidCallback onPressed,
  required final PregoMenuOpenLease acquireMenuLease,
  required final List<PregoMenuEntry> Function() menuEntries,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final unseen = entry.isUnseen(session: session);
    final running = entry.isRunning(session: session);
    final awaiting = entry.isAwaitingInput(session: session);
    // A running session is happening now; its spinning sparkle says so.
    final updatedAt = running ? null : session.time?.updated;
    final description = [
      session.title ?? context.loc.sessionListUntitled,
      if (awaiting) context.loc.sessionListAwaitingInput,
      if (running) context.loc.projectListRunning(1),
      if (unseen) context.loc.projectListNewActivity,
      // The row's "3h" is a glance mark; the label says it in full.
      if (updatedAt != null) context.formatTimestamp(updatedAt),
    ].join(", ");
    // The status column sits under the project's avatar.
    final signals = SizedBox(
      width: DesktopSessionSignals.width,
      child: Center(
        child: DesktopSessionSignals(isAwaitingInput: awaiting, isRunning: running, isUnseen: unseen),
      ),
    );
    final gap = AnimatedBuilder(
      animation: expansion,
      builder: (_, _) => SizedBox(width: PregoSpacing.md * expansion.value),
    );
    final title = Expanded(
      child: Text(
        session.title ?? context.loc.sessionListUntitled,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _sessionTitleStyle(context: context, unseen: unseen),
      ),
    );
    final time = updatedAt == null
        ? null
        : Padding(
            padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
            child: Text(
              context.formatTimestampCompact(ms: updatedAt),
              maxLines: 1,
              style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
            ),
          );
    return PregoAnchorMenu(
      flat: true,
      menuWidth: 220,
      acquireOpenLease: acquireMenuLease,
      entriesBuilder: menuEntries,
      triggerBuilder: (_, openMenu) => GestureDetector(
        onSecondaryTap: openMenu,
        child: Semantics(
          button: true,
          selected: selected,
          label: description,
          onTap: onPressed,
          onLongPress: openMenu,
          excludeSemantics: true,
          child: Tooltip(
            message: description,
            child: InkWell(
              onTap: onPressed,
              onLongPress: openMenu,
              child: DesktopSidebarExpansionBuilder(
                expansion: expansion,
                builder: (expansion, content) => Ink(
                  padding: EdgeInsets.symmetric(
                    horizontal: PregoSpacing.md + PregoSpacing.sm * expansion,
                    vertical: 6,
                  ),
                  color: selected ? _selectedFill(prego.colors) : null,
                  child: content,
                ),
                // A collapsing rail can leave less room than a row needs, so the
                // time is measured against the row's own width. The parts are
                // built once; only the layout follows the animating width.
                child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      signals,
                      gap,
                      title,
                      if (time != null && _rowFitsTime(context: context, width: constraints.maxWidth)) time,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The count on the rail's Activity button.
class const _CountPill({required final int count}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    // Minimums: larger system text grows the pill instead of clipping the count.
    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
    padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xs),
    alignment: Alignment.center,
    decoration: ShapeDecoration(color: context.prego.colors.bgBrandSolid, shape: const StadiumBorder()),
    child: Text(
      "$count",
      style: context.prego.textTheme.textXs.bold.copyWith(color: context.prego.colors.textWhite, height: 1),
    ),
  );
}

class const _SidebarButton({
  super.key,
  required final String label,
  required final Widget icon,
  required final Animation<double> expansion,
  required final bool selected,

  /// [detail] is short text shown beside [icon] while the sidebar is open.
  required final ({Widget icon, String? label, String? detail})? status,

  /// Shown at the row's end while the sidebar is open, and in its tooltip otherwise.
  required final String? shortcut,
  required final VoidCallback? onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final status = this.status;
    final statusLabel = status?.label;
    final statusDetail = status?.detail;
    final description = statusLabel == null ? label : "$label, $statusLabel";
    final shortcut = this.shortcut;
    final tooltip = shortcut == null ? description : context.loc.desktopShortcutHint(description, shortcut);
    final color = onPressed == null ? prego.colors.textDisabled : prego.colors.textPrimary;
    final textStyle = prego.textTheme.textSm.medium.copyWith(color: color);
    return DesktopSidebarPhaseBuilder(
      expansion: expansion,
      builder: (context, phase) => Padding(
        padding: const EdgeInsets.symmetric(vertical: PregoSpacing.xxs),
        child: _ConditionalTooltip(
          enabled: phase != DesktopSidebarPhase.open || status != null,
          message: tooltip,
          child: Semantics(
            button: true,
            enabled: onPressed != null,
            selected: selected,
            label: description,
            onTap: onPressed,
            excludeSemantics: true,
            child: InkWell(
              onTap: onPressed,
              hoverColor: prego.colors.bgSecondaryHover,
              focusColor: prego.colors.textBrandPrimary.withValues(alpha: 0.18),
              // The selected row fills the sidebar's width.
              child: Ink(
                color: selected ? _selectedFill(prego.colors) : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: PregoSpacing.md + PregoSpacing.sm,
                  vertical: PregoSpacing.xs,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          IconTheme(
                            data: IconThemeData(color: color),
                            child: icon,
                          ),
                          if (status != null && phase != DesktopSidebarPhase.open)
                            PositionedDirectional(
                              end: -4,
                              top: -4,
                              child: FadeTransition(
                                opacity: ReverseAnimation(expansion),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(color: prego.colors.bgSecondary, shape: BoxShape.circle),
                                  child: status.icon,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (phase != DesktopSidebarPhase.rail)
                      Expanded(
                        child: FadeTransition(
                          opacity: expansion,
                          child: _LabelInset(
                            expansion: expansion,
                            child: status == null
                                ? _TooltipWhenTruncated(message: label, style: textStyle)
                                : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle),
                          ),
                        ),
                      ),
                    if (shortcut != null && phase == DesktopSidebarPhase.open)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: PregoSpacing.md),
                        child: ExcludeSemantics(
                          child: Text(
                            shortcut,
                            style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
                          ),
                        ),
                      ),
                    if (status != null && phase != DesktopSidebarPhase.rail)
                      DesktopSidebarExpansionBuilder(
                        expansion: expansion,
                        builder: (expansion, statusSlot) => ClipRect(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: expansion,
                            child: statusSlot,
                          ),
                        ),
                        child: FadeTransition(
                          opacity: expansion,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (statusDetail != null)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
                                  child: Text(
                                    statusDetail,
                                    maxLines: 1,
                                    style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
                                  ),
                                ),
                              SizedBox(width: 24, height: 20, child: Center(child: status.icon)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A label's start inset, which grows with the sidebar.
class const _LabelInset({required final Animation<double> expansion, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DesktopSidebarExpansionBuilder(
    expansion: expansion,
    builder: (expansion, child) => Padding(
      padding: EdgeInsetsDirectional.only(start: PregoSpacing.md * expansion),
      child: child,
    ),
    child: child,
  );
}

class const _TooltipWhenTruncated({
  required final String message,
  required final TextStyle style,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final text = Text(message, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
      if (!constraints.maxWidth.isFinite) return text;
      final painter = TextPainter(
        text: TextSpan(text: message, style: style),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      return painter.didExceedMaxLines ? Tooltip(message: message, child: text) : text;
    },
  );
}

class const _ConditionalTooltip({
  required final bool enabled,
  required final String message,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<_ConditionalTooltip> createState() => _ConditionalTooltipState();
}

class _ConditionalTooltipState() extends State<_ConditionalTooltip> {
  // Toggling the tooltip moves the child instead of rebuilding it: the rail
  // animation flips every row's tooltip in one frame.
  final GlobalKey _childKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final child = KeyedSubtree(key: _childKey, child: widget.child);
    return widget.enabled ? Tooltip(message: widget.message, child: child) : child;
  }
}

/// Sessions sit under their project in secondary text; unread ones rise to primary.
TextStyle _sessionTitleStyle({required BuildContext context, required bool unseen}) {
  final prego = context.prego;
  return prego.textTheme.textSm.regular.copyWith(
    color: unseen ? prego.colors.textPrimary : prego.colors.textSecondary,
  );
}

List<String> _sessionStatusLabels({
  required BuildContext context,
  required bool isAwaitingInput,
  required bool isRunning,
  required bool isUnseen,
}) => [
  if (isAwaitingInput) context.loc.sessionListAwaitingInput,
  if (isRunning) context.loc.projectListRunning(1),
  if (isUnseen) context.loc.projectListNewActivity,
];

/// The selected row's fill. It spans the sidebar's width.
Color _selectedFill(PregoColors colors) => colors.textBrandPrimary.withValues(alpha: 0.14);

/// The sidebar's name for [project]: its stored name, else its directory.
String desktopProjectDisplayName({required BuildContext context, required ProjectSummary project}) {
  return projectDisplayName(loc: context.loc, project: project);
}
