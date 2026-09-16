import "dart:async";

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
              child: Row(
                children: [
                  if (expansion > 0)
                    Expanded(
                      child: ClipRect(
                        child: Opacity(
                          opacity: expansion,
                          child: SizedBox(
                            height: 32,
                            child: OverflowBox(
                              alignment: AlignmentDirectional.centerStart,
                              minWidth: 130,
                              maxWidth: 130,
                              child: Semantics(
                                button: true,
                                label: loc.projectListTitle,
                                onTap: onOpenProjects,
                                excludeSemantics: true,
                                selected: selectedProjectId == null,
                                child: TextButton(
                                  onPressed: onOpenProjects,
                                  style: TextButton.styleFrom(
                                    alignment: AlignmentDirectional.centerStart,
                                    padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.sm),
                                  ),
                                  child: Text(
                                    loc.projectListTitle,
                                    style: prego.textTheme.textSm.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      key: const Key("desktop-sidebar-toggle"),
                      tooltip: expansion < 0.5 ? loc.desktopSidebarExpand : loc.desktopSidebarCollapse,
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 16),
              child: Tooltip(
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
                              child: Text(
                                loc.desktopSidebarNewProject,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: prego.textTheme.textSm.medium.copyWith(
                                  color: prego.colors.textWhite,
                                ),
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
                ProjectListLoaded(:final projects, :final activityById, :final unseenByProjectId) => ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: projects.length,
                  findChildIndexCallback: (key) {
                    final index = projects.indexWhere((project) => ValueKey(project.id) == key);
                    return index < 0 ? null : index;
                  },
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    final basename = projectDirectoryBasename(project);
                    final name = project.name ?? (basename.isEmpty ? loc.projectListDefaultName : basename);
                    final active = activityById[project.id] ?? 0;
                    final unseen = unseenByProjectId[project.id] ?? project.hasUnseenChanges;
                    return _SidebarProjectGroup(
                      key: ValueKey(project.id),
                      project: project,
                      name: name,
                      active: active,
                      unseen: unseen,
                      expansion: expansion,
                      expanded: !collapsedProjects.contains(project.id),
                      selected: project.id == selectedProjectId,
                      selectedSessionId: project.id == selectedProjectId ? selectedSessionId : null,
                      onOpenProject: onOpenProject,
                      onOpenSession: onOpenSession,
                      onNewSession: onNewSession,
                      sessionActions: sessionActions,
                    );
                  },
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
            Container(
              key: const Key("desktop-sidebar-footer"),
              padding: const EdgeInsets.symmetric(vertical: PregoSpacing.md),
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
                      label: loc.desktopBridgeTitle,
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
                  _SidebarButton(
                    label: loc.settingsTitle,
                    icon: const Icon(TablerRegular.settings, size: 20),
                    expansion: expansion,
                    selected: false,
                    status: null,
                    onPressed: onOpenSettings,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class const _SidebarProjectGroup({
  super.key,
  required final ProjectSummary project,
  required final String name,
  required final int active,
  required final bool unseen,
  required final double expansion,
  required final bool expanded,
  required final bool selected,
  required final String? selectedSessionId,
  required final ProjectOpenedCallback onOpenProject,
  required final SidebarSessionOpenedCallback onOpenSession,
  required final ProjectOpenedCallback onNewSession,
  required final SessionListActionDispatcher sessionActions,
}) extends StatefulWidget {
  @override
  State<_SidebarProjectGroup> createState() => _SidebarProjectGroupState();
}

class _SidebarProjectGroupState() extends State<_SidebarProjectGroup> {
  bool _hovered = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _loadExpanded();
  }

  @override
  void didUpdateWidget(covariant _SidebarProjectGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.expanded && widget.expanded) || (oldWidget.expansion == 0 && widget.expansion > 0)) {
      _loadExpanded();
    }
  }

  void _loadExpanded() {
    if (widget.expanded && widget.expansion > 0) {
      unawaited(context.read<RecentSessionsCubit>().ensureLoaded(projectId: widget.project.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = context.select((RecentSessionsCubit cubit) => cubit.state[widget.project.id]);
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
                                        tooltip: loc.desktopSidebarNewSession(widget.name),
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
                                for (final session in entry.rows(selectedSessionId: widget.selectedSessionId))
                                  _SidebarSessionRow(
                                    key: ValueKey(session.id),
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
                                    menuEntries: () {
                                      actionContext.read<SessionListCubit>().updateActionSession(session: session);
                                      return widget.sessionActions.sessionMenuEntries(
                                        context: actionContext,
                                        session: session,
                                      );
                                    },
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

class const _SidebarSessionRow({
  super.key,
  required final Session session,
  required final RecentSessionsLoaded entry,
  required final bool selected,
  required final double expansion,
  required final VoidCallback onPressed,
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
    final statusIcons = [
      if (awaiting) Icon(TablerRegular.message_circle, size: 14, color: prego.colors.textWarningPrimary),
      if (running || unseen) PregoAiLoader(size: 14, animate: running),
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(40, 0, 8, 0),
      child: PregoAnchorMenu(
        flat: true,
        menuWidth: 220,
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.title ?? context.loc.sessionListUntitled,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: unseen ? prego.textTheme.textXs.bold : prego.textTheme.textXs.regular,
                        ),
                      ),
                      // The collapsing rail leaves less room than the signals need,
                      // so reveal them with the row instead of overflowing it.
                      if (statusIcons.isNotEmpty)
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
    );
  }
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.md, vertical: PregoSpacing.xxs),
      child: Tooltip(
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
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: (emphasized ? prego.textTheme.textSm.medium : prego.textTheme.textSm.regular)
                                .copyWith(color: color),
                          ),
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
