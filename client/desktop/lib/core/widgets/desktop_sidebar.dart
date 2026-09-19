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
  required final double expansion,
  required final bool autoCollapsed,
  required final String? selectedProjectId,
  required final String? selectedSessionId,
  required final SidebarSessionOpenedCallback onOpenSession,
  required final ProjectOpenedCallback onNewSession,
  required final SessionListActionDispatcher sessionActions,
  required final VoidCallback onToggleCollapsed,
  required final VoidCallback onOpenProjects,
  required final VoidCallback onAddProject,
  required final ProjectOpenedCallback onOpenProject,
  required final VoidCallback onOpenBridgeSettings,
  required final VoidCallback onOpenSettings,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectListCubit>().state;
    final collapsedProjects = context.select((DesktopSidebarCubit cubit) => cubit.state.collapsedProjectIds);
    final loc = context.loc;
    final toggleLabel = expansion < 0.5 ? loc.desktopSidebarExpand : loc.desktopSidebarCollapse;
    final prego = context.prego;
    final bridge = context.watch<BridgeControlCubit>().state;
    final bridgeColor = bridge.canTakeOver
        ? prego.colors.textWarningPrimary
        : switch (bridge.processState) {
            BridgeProcessStopped() => prego.colors.textDisabled,
            BridgeProcessStartFailed() || BridgeProcessCrashGiveUp() => prego.colors.textErrorPrimary,
            BridgeProcessRunning()
                when bridge.controlStatus.helperOnline &&
                    bridge.controlStatus.startup == ControlStartupState.ready &&
                    bridge.controlStatus.relay == ControlRelayConnectionState.connected &&
                    bridge.controlStatus.plugin != ControlPluginHealthState.degraded =>
              prego.colors.textSuccessPrimary,
            BridgeProcessLoginRequired() ||
            BridgeProcessStarting() ||
            BridgeProcessRunning() ||
            BridgeProcessStopping() ||
            BridgeProcessContention() ||
            BridgeProcessCrashRetryScheduled() => prego.colors.textWarningPrimary,
          };
    return Material(
      color: prego.colors.bgSecondary,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 8),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: SizedBox.square(
                  dimension: 32,
                  child: IconButton(
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
                      expansion < 0.5
                          ? TablerRegular.layout_sidebar_left_expand
                          : TablerRegular.layout_sidebar_left_collapse,
                      size: 18,
                      color: autoCollapsed ? prego.colors.textDisabled : prego.colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 16),
              child: _ConditionalTooltip(
                enabled: expansion < 1,
                message: loc.desktopSidebarNewProject,
                child: FilledButton(
                  key: const Key("desktop-sidebar-new-project"),
                  onPressed: state is ProjectListLoaded ? onAddProject : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: prego.colors.bgBrandSolid,
                    foregroundColor: prego.colors.textWhite,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.sm),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PregoRadius.lg)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(TablerRegular.plus, size: 18),
                      if (expansion > 0)
                        Flexible(
                          child: Opacity(
                            opacity: expansion,
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(start: PregoSpacing.md * expansion),
                              child: _TooltipWhenTruncated(
                                message: loc.desktopSidebarNewProject,
                                style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textWhite),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (expansion < 1)
              ClipRect(
                child: Align(
                  heightFactor: 1 - expansion,
                  child: Opacity(
                    opacity: 1 - expansion,
                    child: _SidebarButton(
                      key: const Key("desktop-sidebar-projects"),
                      label: loc.projectListTitle,
                      icon: const Icon(TablerRegular.folders, size: 20),
                      expansion: 0,
                      selected: selectedProjectId == null,
                      status: null,
                      onPressed: onOpenProjects,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: switch (state) {
                ProjectListLoading() => Center(
                  child: Semantics(
                    label: loc.projectListLoadingSemantics,
                    child: const PregoActivityIndicator(color: null),
                  ),
                ),
                ProjectListLoaded(:final projects, :final activityById, :final unseenByProjectId) => _SidebarInventory(
                  key: const Key("desktop-sidebar-inventory"),
                  projects: projects,
                  activityById: activityById,
                  unseenByProjectId: unseenByProjectId,
                  collapsedProjectIds: collapsedProjects,
                  expansion: expansion,
                  selectedProjectId: selectedProjectId,
                  selectedSessionId: selectedSessionId,
                  onOpenProject: onOpenProject,
                  onOpenSession: onOpenSession,
                  onNewSession: onNewSession,
                  sessionActions: sessionActions,
                ),
                ProjectListFailed() => _SidebarButton(
                  label: loc.projectListRetry,
                  icon: const Icon(TablerRegular.refresh, size: 20),
                  expansion: expansion,
                  selected: false,
                  status: null,
                  onPressed: () => unawaited(context.read<ProjectListCubit>().retryLoadProjects()),
                ),
                ProjectListBridgeDisconnected() => const SizedBox.shrink(),
              },
            ),
            _SidebarFooter(
              projectState: state,
              expansion: expansion,
              bridge: bridge,
              bridgeColor: bridgeColor,
              onOpenBridgeSettings: onOpenBridgeSettings,
              onOpenSettings: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class const _SidebarFooter({
  required final ProjectListState projectState,
  required final double expansion,
  required final BridgeControlState bridge,
  required final Color bridgeColor,
  required final VoidCallback onOpenBridgeSettings,
  required final VoidCallback onOpenSettings,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final refresh = context.watch<DesktopSidebarRefreshCubit>();
    final refreshing =
        refresh.state == DesktopSidebarRefreshState.refreshing ||
        switch (projectState) {
          ProjectListLoaded(:final isRefreshing) => isRefreshing,
          ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => false,
        };
    final canRefresh = projectState is ProjectListLoaded && !refreshing;
    final controlSize = 28 + 8 * expansion;
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
        padding: const EdgeInsets.symmetric(vertical: PregoSpacing.xs),
        decoration: BoxDecoration(
          color: prego.colors.bgSurface1,
          border: Border(top: BorderSide(color: prego.colors.borderPrimary)),
        ),
        child: Column(
          children: [
            DesktopBridgeRecoveryCard(expansion: expansion),
            PregoPopover(
              popoverWidth: 300,
              triggerBuilder: (context, toggle) => _SidebarButton(
                label: loc.desktopSettingsThisComputer,
                icon: const Icon(TablerRegular.server, size: 20),
                expansion: expansion,
                selected: false,
                status: (icon: Icon(Icons.circle, size: 8, color: bridgeColor), label: bridge.statusLabel),
                onPressed: toggle,
              ),
              contentBuilder: (context, close) => DesktopBridgePopover(
                close: close,
                onOpenSettings: onOpenBridgeSettings,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: controlSize,
                  child: IconButton(
                    key: const Key("desktop-sidebar-refresh"),
                    tooltip: refreshing ? loc.desktopSidebarRefreshing : loc.desktopSidebarRefresh,
                    padding: const EdgeInsets.all(PregoSpacing.sm),
                    onPressed: canRefresh ? () => unawaited(refresh.refresh()) : null,
                    icon: refreshing
                        ? Semantics(
                            label: loc.desktopSidebarRefreshing,
                            child: const ExcludeSemantics(
                              child: SizedBox.square(dimension: 20, child: PregoActivityIndicator(color: null)),
                            ),
                          )
                        : Icon(TablerRegular.refresh, size: 18, semanticLabel: loc.desktopSidebarRefresh),
                  ),
                ),
                SizedBox.square(
                  dimension: controlSize,
                  child: IconButton(
                    key: const Key("desktop-sidebar-settings"),
                    tooltip: loc.desktopShortcutHint(
                      loc.settingsTitle,
                      defaultTargetPlatform == TargetPlatform.macOS ? "⌘," : "Ctrl+,",
                    ),
                    padding: const EdgeInsets.all(PregoSpacing.sm),
                    onPressed: onOpenSettings,
                    icon: Icon(TablerRegular.settings, size: 18, semanticLabel: loc.settingsTitle),
                  ),
                ),
              ],
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
  required final Map<String, int> activityById,
  required final Map<String, bool> unseenByProjectId,
  required final Set<String> collapsedProjectIds,
  required final double expansion,
  required final String? selectedProjectId,
  required final String? selectedSessionId,
  required final SidebarSessionOpenedCallback onOpenSession,
  required final ProjectOpenedCallback onNewSession,
  required final SessionListActionDispatcher sessionActions,
  required final ProjectOpenedCallback onOpenProject,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final entries = context.watch<RecentSessionsCubit>().state;
    final projection = DesktopSidebarSessionProjection.from(projects: projects, entries: entries);
    List<PregoMenuEntry> buildSessionMenuEntries({
      required SessionListCubit cubit,
      required Session session,
    }) => sessionActions.sessionMenuEntries(context: context, cubit: cubit, session: session);
    final gutter = PregoSpacing.xl * expansion;
    final activityHeaderExpansion = projection.activityGroups.isEmpty ? 0.0 : expansion;
    return CustomScrollView(
      key: const Key("desktop-sidebar-project-list"),
      slivers: [
        SliverPadding(
          padding: EdgeInsetsDirectional.only(end: gutter),
          sliver: SliverToBoxAdapter(
            key: const Key("desktop-sidebar-activity-header"),
            child: ClipRect(
              child: Align(
                heightFactor: activityHeaderExpansion,
                child: Opacity(
                  opacity: activityHeaderExpansion,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, PregoSpacing.sm, 8, PregoSpacing.xs),
                    child: Text(
                      context.loc.desktopSidebarActivity,
                      style: context.prego.textTheme.textXs.bold.copyWith(
                        color: context.prego.colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsetsDirectional.only(end: gutter),
          sliver: PregoAnimatedSliverList<DesktopSidebarActivityGroup>(
            key: const Key("desktop-sidebar-activity-list"),
            items: projection.activityGroups,
            itemKey: (group) => ValueKey(group.project.id),
            itemBuilder: (context, _, group) {
              final projectName = _projectName(context: context, project: group.project);
              return _SidebarActivityProjectGroup(
                key: ValueKey("sidebar-activity-${group.project.id}"),
                group: group,
                projectName: projectName,
                expansion: expansion,
                selectedSessionId: group.project.id == selectedProjectId ? selectedSessionId : null,
                onOpenSession: onOpenSession,
                sessionMenuEntries: buildSessionMenuEntries,
              );
            },
          ),
        ),
        SliverPadding(
          padding: EdgeInsetsDirectional.only(end: gutter),
          sliver: PregoAnimatedSliverList<ProjectSummary>(
            key: const Key("desktop-sidebar-project-groups"),
            items: projects,
            itemKey: (project) => ValueKey(project.id),
            itemBuilder: (context, _, project) {
              final projectName = _projectName(context: context, project: project);
              final entry = entries[project.id];
              return _SidebarProjectGroup(
                key: ValueKey(project.id),
                project: project,
                name: projectName,
                active: activityById[project.id] ?? 0,
                unseen: unseenByProjectId[project.id] ?? project.hasUnseenChanges,
                entry: entry,
                ordinarySessions: entry is RecentSessionsLoaded
                    ? projection.ordinaryRows(
                        projectId: project.id,
                        loaded: entry,
                        selectedSessionId: project.id == selectedProjectId ? selectedSessionId : null,
                      )
                    : const [],
                expansion: expansion,
                expanded: !collapsedProjectIds.contains(project.id),
                selected: project.id == selectedProjectId,
                selectedSessionId: project.id == selectedProjectId ? selectedSessionId : null,
                onOpenProject: onOpenProject,
                onOpenSession: onOpenSession,
                onNewSession: onNewSession,
                sessionMenuEntries: buildSessionMenuEntries,
              );
            },
          ),
        ),
      ],
    );
  }
}

class const _SidebarActivityProjectGroup({
  super.key,
  required final DesktopSidebarActivityGroup group,
  required final String projectName,
  required final double expansion,
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
  required final int active,
  required final bool unseen,
  required final RecentSessionsEntry? entry,
  required final List<Session> ordinarySessions,
  required final double expansion,
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
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final loc = context.loc;
    final detailStyle = context.prego.textTheme.textXs.regular;
    // Created only if a session menu reads it. Keep this scope above the rows:
    // a successful delete can remove its row before the route callback runs.
    return BlocProvider<SessionListCubit>(
      create: (_) => createSessionListCubit(
        locator: getIt,
        projectId: widget.project.id,
        mode: SessionListMode.actions(sessions: entry is RecentSessionsLoaded ? entry.sourceSessions : const []),
      ),
      child: Builder(
        builder: (actionContext) => Focus(
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
                        entriesBuilder: () => ProjectTile.menuEntries(context: actionContext, project: widget.project),
                        triggerBuilder: (_, openMenu) => GestureDetector(
                          onSecondaryTap: openMenu,
                          onLongPress: openMenu,
                          child: _SidebarButton(
                            label: widget.name,
                            icon: PregoAvatarInitials(label: widget.name, size: 26),
                            expansion: widget.expansion,
                            selected: widget.selected,
                            status: widget.active > 0 || widget.unseen
                                ? (
                                    icon: PregoAiLoader(size: 18, animate: widget.active > 0),
                                    label: widget.active > 0
                                        ? widget.unseen
                                              ? "${loc.projectListRunning(widget.active)}, ${loc.projectListNewActivity}"
                                              : loc.projectListRunning(widget.active)
                                        : loc.projectListNewActivity,
                                  )
                                : null,
                            onPressed: () => widget.onOpenProject(
                              context: actionContext,
                              project: widget.project,
                              displayName: widget.name,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.expansion > 0)
                      SizedBox(
                        width: 48 * widget.expansion,
                        height: 36,
                        child: ClipRect(
                          child: Opacity(
                            opacity: widget.expansion,
                            child: OverflowBox(
                              minWidth: 48,
                              maxWidth: 48,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 28,
                                    child: Opacity(
                                      opacity: _hovered || _focused ? 1 : 0,
                                      child: IconButton(
                                        key: ValueKey("sidebar-new-session-${widget.project.id}"),
                                        padding: EdgeInsets.zero,
                                        tooltip: widget.selected
                                            ? loc.desktopShortcutHint(
                                                loc.desktopSidebarNewSession(widget.name),
                                                defaultTargetPlatform == TargetPlatform.macOS ? "⌘N" : "Ctrl+N",
                                              )
                                            : loc.desktopSidebarNewSession(widget.name),
                                        icon: const Icon(TablerRegular.plus, size: 16),
                                        onPressed: () => widget.onNewSession(
                                          context: actionContext,
                                          project: widget.project,
                                          displayName: widget.name,
                                        ),
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
                                        widget.expanded ? TablerRegular.chevron_down : TablerRegular.chevron_right,
                                        size: 16,
                                      ),
                                      onPressed: () => unawaited(
                                        context.read<DesktopSidebarCubit>().toggleProject(projectId: widget.project.id),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.expanded && widget.expansion > 0)
                ClipRect(
                  child: Align(
                    heightFactor: widget.expansion,
                    child: Opacity(
                      opacity: widget.expansion,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          switch (entry) {
                            RecentSessionsLoaded() => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                PregoAnimatedList<Session>(
                                  items: widget.ordinarySessions,
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
                                      final cubit = actionContext.read<SessionListCubit>()
                                        ..updateActionSession(session: session);
                                      return widget.sessionMenuEntries(cubit: cubit, session: session);
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(start: 44, end: 8),
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      alignment: AlignmentDirectional.centerStart,
                                      foregroundColor: context.prego.colors.textSecondary,
                                      minimumSize: const Size(0, 32),
                                      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xs),
                                    ),
                                    onPressed: () => widget.onOpenProject(
                                      context: actionContext,
                                      project: widget.project,
                                      displayName: widget.name,
                                    ),
                                    child: Text(
                                      loc.desktopSidebarAllSessions(entry.visibleSessions.length),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: detailStyle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            RecentSessionsFailed() => TextButton.icon(
                              onPressed: () =>
                                  unawaited(context.read<RecentSessionsCubit>().retry(projectId: widget.project.id)),
                              icon: const Icon(TablerRegular.refresh, size: 14),
                              label: Text(loc.sessionListRetry, style: detailStyle),
                            ),
                            RecentSessionsLoading() || null => Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(44, 4, 8, 4),
                              child: Text(
                                loc.sessionListLoadingSemantics,
                                style: detailStyle,
                              ),
                            ),
                          },
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class const _SidebarActivitySessionRow({
  super.key,
  required final DesktopSidebarActivitySession item,
  required final String projectName,
  required final bool selected,
  required final double expansion,
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
    final description = [identity, ...statuses].join(", ");
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(14 - 2 * expansion, 0, 14 - 6 * expansion, 0),
      child: PregoAnchorMenu(
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
              enabled: expansion < 1,
              message: description,
              child: InkWell(
                onTap: onPressed,
                onLongPress: openMenu,
                borderRadius: BorderRadius.circular(PregoRadius.md),
                child: Ink(
                  padding: EdgeInsets.symmetric(horizontal: 8 * expansion, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? prego.colors.textBrandPrimary.withValues(alpha: 0.14) : null,
                    borderRadius: BorderRadius.circular(PregoRadius.md),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              PregoAvatarInitials(label: projectName, size: 26),
                              if (expansion < 1)
                                PositionedDirectional(
                                  end: -4,
                                  top: -4,
                                  child: Opacity(
                                    opacity: 1 - expansion,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: prego.colors.bgSecondary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: PregoAiLoader(size: 12, animate: item.isRunning),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (expansion > 0)
                          Expanded(
                            child: ClipRect(
                              child: Opacity(
                                opacity: expansion,
                                child: Padding(
                                  padding: EdgeInsetsDirectional.only(start: PregoSpacing.md * expansion),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _TooltipWhenTruncated(
                                        message: title,
                                        style: item.isUnseen
                                            ? prego.textTheme.textXs.bold
                                            : prego.textTheme.textXs.regular,
                                      ),
                                      _TooltipWhenTruncated(
                                        message: projectName,
                                        style: prego.textTheme.textXs.regular.copyWith(
                                          color: prego.colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (expansion > 0 && constraints.maxWidth >= 104)
                          ClipRect(
                            child: Opacity(
                              opacity: expansion,
                              child: _SessionSignals(
                                isAwaitingInput: item.isAwaitingInput,
                                isRunning: item.isRunning,
                                isUnseen: item.isUnseen,
                                size: 14,
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
      ),
    );
  }
}

class const _SidebarSessionRow({
  super.key,
  required final Session session,
  required final RecentSessionsLoaded entry,
  required final bool selected,
  required final double expansion,
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
    final description = [
      session.title ?? context.loc.sessionListUntitled,
      if (awaiting) context.loc.sessionListAwaitingInput,
      if (running) context.loc.projectListRunning(1),
      if (unseen) context.loc.projectListNewActivity,
    ].join(", ");
    const statusIconSize = 14.0;
    final statusIcons = [
      if (awaiting) Icon(TablerRegular.message_circle, size: statusIconSize, color: prego.colors.textWarningPrimary),
      if (running || unseen) PregoAiLoader(size: statusIconSize, animate: running),
    ];
    // What the signals need before the rail starts narrowing.
    final statusWidth = statusIcons.isEmpty ? 0.0 : PregoSpacing.xs + statusIconSize * statusIcons.length;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(40, 0, 8, 0),
      child: PregoAnchorMenu(
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
                borderRadius: BorderRadius.circular(PregoRadius.md),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? prego.colors.textBrandPrimary.withValues(alpha: 0.14) : null,
                    borderRadius: BorderRadius.circular(PregoRadius.md),
                  ),
                  // A collapsing rail can leave less room than a row needs, so the
                  // signals are measured against the row's own width.
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.title ?? context.loc.sessionListUntitled,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: unseen ? prego.textTheme.textXs.bold : prego.textTheme.textXs.regular,
                          ),
                        ),
                        // Reveal the signals with the rail, but only while the row
                        // is still wide enough to hold them.
                        if (statusIcons.isNotEmpty && statusWidth * expansion <= constraints.maxWidth)
                          ClipRect(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              widthFactor: expansion,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: PregoSpacing.xs),
                                  ...statusIcons,
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
        ),
      ),
    );
  }
}

class const _SessionSignals({
  required final bool isAwaitingInput,
  required final bool isRunning,
  required final bool isUnseen,
  required final double size,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (isAwaitingInput)
        Tooltip(
          message: context.loc.sessionListAwaitingInput,
          child: Icon(
            TablerRegular.message_circle,
            size: size,
            color: context.prego.colors.textWarningPrimary,
          ),
        ),
      if (isRunning || isUnseen)
        Tooltip(
          message: isRunning
              ? isUnseen
                    ? "${context.loc.projectListRunning(1)}, ${context.loc.projectListNewActivity}"
                    : context.loc.projectListRunning(1)
              : context.loc.projectListNewActivity,
          child: PregoAiLoader(size: size, animate: isRunning),
        ),
    ],
  );
}

class const _SidebarButton({
  super.key,
  required final String label,
  required final Widget icon,
  required final double expansion,
  required final bool selected,
  required final ({Widget icon, String label})? status,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final status = this.status;
    final description = status == null ? label : "$label, ${status.label}";
    final emphasized = selected || status != null;
    final color = emphasized ? prego.colors.textPrimary : prego.colors.textSecondary;
    final textStyle = (emphasized ? prego.textTheme.textSm.medium : prego.textTheme.textSm.regular).copyWith(
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.md, vertical: PregoSpacing.xxs),
      child: _ConditionalTooltip(
        enabled: expansion < 1 || status != null,
        message: description,
        child: Semantics(
          button: true,
          selected: selected,
          label: description,
          onTap: onPressed,
          excludeSemantics: true,
          child: InkWell(
            onTap: onPressed,
            hoverColor: prego.colors.bgSecondaryHover,
            focusColor: prego.colors.textBrandPrimary.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(PregoRadius.lg),
            child: Ink(
              decoration: BoxDecoration(
                color: selected ? prego.colors.textBrandPrimary.withValues(alpha: 0.14) : null,
                borderRadius: BorderRadius.circular(PregoRadius.lg),
              ),
              padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.sm, vertical: PregoSpacing.xs),
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
                        if (status != null && expansion < 1)
                          PositionedDirectional(
                            end: -4,
                            top: -4,
                            child: Opacity(
                              opacity: 1 - expansion,
                              child: DecoratedBox(
                                decoration: BoxDecoration(color: prego.colors.bgSecondary, shape: BoxShape.circle),
                                child: status.icon,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (expansion > 0)
                    Expanded(
                      child: Opacity(
                        opacity: expansion,
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(start: PregoSpacing.md * expansion),
                          child: status == null
                              ? _TooltipWhenTruncated(message: label, style: textStyle)
                              : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle),
                        ),
                      ),
                    ),
                  if (status != null && expansion > 0)
                    SizedBox(
                      width: 24 * expansion,
                      height: 20,
                      child: ClipRect(
                        child: Opacity(
                          opacity: expansion,
                          child: OverflowBox(minWidth: 24, maxWidth: 24, child: status.icon),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => enabled ? Tooltip(message: message, child: child) : child;
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

String _projectName({required BuildContext context, required ProjectSummary project}) {
  final basename = projectDirectoryBasename(project);
  return project.name ?? (basename.isEmpty ? context.loc.projectListDefaultName : basename);
}
