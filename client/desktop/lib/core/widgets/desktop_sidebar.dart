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
import "desktop_window_drag_area.dart";

typedef SidebarSessionOpenedCallback = void Function({
  required BuildContext context,
  required ProjectSummary project,
  required String displayName,
  required Session session,
});

/// Desktop navigation frame: New session, Search, and the shared list of
/// sessions across projects under its project filter (D4).
class const DesktopSidebar({
  super.key,

  /// Set on macOS, where the traffic lights sit on this panel's top: it makes
  /// room for them there, and that room drags and zooms the window.
  required final WindowHost? windowHost,
  required final String? selectedSessionId,
  required final SidebarSessionOpenedCallback onOpenSession,
  required final VoidCallback onStartNewSession,
  required final VoidCallback onOpenSearch,
  required final SessionListActionDispatcher sessionActions,
  required final VoidCallback onToggleCollapsed,
  required final VoidCallback onOpenBridgeSettings,
  required final VoidCallback onOpenArchived,
  required final VoidCallback onOpenSettings,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectListCubit>().state;
    final filterId = context.select((AllSessionsCubit cubit) => cubit.state.projectId);
    final filterName = switch (state) {
      ProjectListLoaded(:final projects) => [
        for (final project in projects)
          if (project.id == filterId) desktopProjectDisplayName(context: context, project: project),
      ].firstOrNull,
      ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => null,
    };
    final loc = context.loc;
    final newSessionShortcut = defaultTargetPlatform == TargetPlatform.macOS ? "⌘N" : "Ctrl+N";
    final prego = context.prego;
    final bridge = context.watch<BridgeControlCubit>().state;
    final bridgeColor = desktopBridgeStatusColor(colors: prego.colors, state: bridge);
    // The shell's floating panel paints the surface.
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            _TopStrip(windowHost: windowHost),
            // A quiet row, not a filled button: with no projects it offers to add one.
            _SidebarButton(
              key: const Key("desktop-sidebar-new-session"),
              label: state is ProjectListLoaded && state.projects.isEmpty ? loc.addProject : loc.sessionListNewSession,
              icon: const Icon(TablerRegular.plus, size: PregoIconSize.md),
              status: null,
              shortcut: newSessionShortcut,
              onPressed: state is ProjectListLoaded ? onStartNewSession : null,
            ),
            _SidebarButton(
              key: const Key("desktop-sidebar-search"),
              label: loc.desktopSearch,
              icon: const Icon(TablerRegular.search, size: PregoIconSize.md),
              status: null,
              shortcut: defaultTargetPlatform == TargetPlatform.macOS ? "⌘K" : "Ctrl+K",
              onPressed: onOpenSearch,
            ),
            _SidebarFilter(projectState: state, projectId: filterId, projectName: filterName),
            Expanded(
              // Ink paints on the nearest Material, outside the list's own clip: this
              // one keeps a row's highlight from showing through the section above.
              child: Material(
                type: MaterialType.transparency,
                clipBehavior: Clip.hardEdge,
                child: CustomScrollView(
                  key: const Key("desktop-sidebar-session-list"),
                  slivers: [
                    if (state is ProjectListLoaded)
                      SliverToBoxAdapter(
                        child: CatalogScanRow(
                          scan: context.select((SessionListRefreshCubit refresh) => refresh.state.scan),
                        ),
                      ),
                    AllSessionsList(
                      onSessionTap: ({required row}) => onOpenSession(
                        context: context,
                        project: row.project,
                        displayName: desktopProjectDisplayName(context: context, project: row.project),
                        session: row.session,
                      ),
                      actionDispatcher: sessionActions,
                      createActionCubit: ({required projectId, required session}) => createSessionListCubit(
                        locator: getIt,
                        projectId: projectId,
                        mode: SessionListMode.actions(sessions: [session]),
                      ),
                      selectedSessionId: selectedSessionId,
                      // The footer's recovery card says so.
                      disconnectedBuilder: ({required context, required state}) => const SliverToBoxAdapter(),
                      emptyState: SessionEmptyState(projectName: filterName),
                      // The filter heads the list already, beside Refresh.
                      header: null,
                    ),
                  ],
                ),
              ),
            ),
            _SidebarFooter(
              bridge: bridge,
              bridgeColor: bridgeColor,
              onToggleCollapsed: onToggleCollapsed,
              onOpenBridgeSettings: onOpenBridgeSettings,
              onOpenArchived: onOpenArchived,
              onOpenSettings: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}

/// The space above the panel's first control. On macOS the traffic lights sit
/// on the panel, so it grows to clear them and stands in for the title bar: it
/// drags the window and zooms it on a double click.
class const _TopStrip({required final WindowHost? windowHost}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final windowHost = this.windowHost;
    if (windowHost == null) return const SizedBox(height: 12);
    const height = 34.0;
    return DesktopWindowDragArea(
      windowHost: windowHost,
      height: height,
      zoomOnDoubleClick: true,
      child: const SizedBox(height: height, width: double.infinity),
    );
  }
}

/// The list's project filter (D4), "All projects" or one project, beside
/// Refresh.
class const _SidebarFilter({
  required final ProjectListState projectState,
  required final String? projectId,
  required final String? projectName,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final sessions = context.read<AllSessionsCubit>();
    final secondary = prego.colors.textSecondary;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(PregoSpacing.md, PregoSpacing.sm, PregoSpacing.md, 0),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ProjectPicker(
                selectedProjectId: projectId,
                onSelected: ({required projectId, required projectName}) =>
                    sessions.selectProject(projectId: projectId),
                onAllProjects: () => sessions.selectProject(projectId: null),
                triggerBuilder: (context, open) => Semantics(
                  button: true,
                  enabled: projectState is ProjectListLoaded,
                  child: InkWell(
                    key: const Key("desktop-sidebar-filter"),
                    mouseCursor: WidgetStateMouseCursor.clickable,
                    onTap: projectState is ProjectListLoaded ? open : null,
                    borderRadius: BorderRadius.circular(PregoRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.sm, vertical: PregoSpacing.xs),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              projectName ?? context.loc.projectPickerAllProjects,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: prego.textTheme.textSm.medium.copyWith(color: secondary),
                            ),
                          ),
                          const SizedBox(width: PregoSpacing.xs),
                          Icon(TablerRegular.chevron_down, size: PregoIconSize.sm, color: secondary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox.square(
            dimension: 32,
            child: _SidebarRefreshButton(projectState: projectState, iconSize: PregoIconSize.md, color: secondary),
          ),
        ],
      ),
    );
  }
}

/// Reloads projects and their sessions and imports from every harness.
class const _SidebarRefreshButton({
  required final ProjectListState projectState,
  required final double iconSize,
  required final Color? color,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final refreshing =
        context.select(
          (SessionListRefreshCubit refresh) => refresh.state.status == SessionListRefreshStatus.refreshing,
        ) ||
        switch (projectState) {
          ProjectListLoaded(:final isRefreshing) => isRefreshing,
          ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => false,
        };
    final canRefresh = projectState is ProjectListLoaded && !refreshing;
    return IconButton(
      key: const Key("desktop-sidebar-refresh"),
      tooltip: refreshing ? loc.desktopSidebarRefreshing : loc.desktopSidebarRefresh,
      padding: EdgeInsets.zero,
      onPressed: canRefresh ? () => unawaited(context.read<SessionListRefreshCubit>().refresh()) : null,
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
  required final BridgeControlState bridge,
  required final Color bridgeColor,
  required final VoidCallback onToggleCollapsed,
  required final VoidCallback onOpenBridgeSettings,
  required final VoidCallback onOpenArchived,
  required final VoidCallback onOpenSettings,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final macOS = defaultTargetPlatform == TargetPlatform.macOS;
    Widget control(Widget button) => SizedBox.square(dimension: 36, child: button);
    return BlocListener<SessionListRefreshCubit, SessionListRefreshState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          (current.status == SessionListRefreshStatus.succeeded || current.status == SessionListRefreshStatus.failed),
      listener: (context, state) {
        final succeeded = state.status == SessionListRefreshStatus.succeeded;
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
            const DesktopBridgeRecoveryCard(compact: false),
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    child: PregoPopover(
                      popoverWidth: 300,
                      popoverMaxHeight: null,
                      contentScrolls: false,
                      onClosed: null,
                      triggerBuilder: (context, toggle) => _SidebarButton(
                        label: loc.desktopSettingsThisComputer,
                        icon: const Icon(TablerRegular.server, size: PregoIconSize.md),
                        // A status dot, not a glyph: no icon token applies.
                        status: (
                          icon: Icon(TablerSolid.circle, size: 8, color: bridgeColor),
                          label: bridge.statusLabel,
                        ),
                        shortcut: null,
                        onPressed: toggle,
                      ),
                      contentBuilder: (context, close) => DesktopBridgePopover(
                        close: close,
                        onOpenSettings: onOpenBridgeSettings,
                      ),
                    ),
                  ),
                  control(
                    IconButton(
                      key: const Key("desktop-sidebar-archived"),
                      tooltip: loc.archivedSessionsTitle,
                      padding: const EdgeInsets.all(PregoSpacing.sm),
                      onPressed: onOpenArchived,
                      icon: Icon(
                        TablerRegular.archive,
                        size: PregoIconSize.md,
                        semanticLabel: loc.archivedSessionsTitle,
                      ),
                    ),
                  ),
                  control(
                    IconButton(
                      key: const Key("desktop-sidebar-settings"),
                      tooltip: loc.desktopShortcutHint(loc.settingsTitle, macOS ? "⌘," : "Ctrl+,"),
                      padding: const EdgeInsets.all(PregoSpacing.sm),
                      onPressed: onOpenSettings,
                      icon: Icon(TablerRegular.settings, size: PregoIconSize.md, semanticLabel: loc.settingsTitle),
                    ),
                  ),
                  control(
                    IconButton(
                      key: const Key("desktop-sidebar-toggle"),
                      tooltip: loc.desktopShortcutHint(loc.desktopSidebarCollapse, macOS ? "⌘B" : "Ctrl+B"),
                      padding: const EdgeInsets.all(PregoSpacing.sm),
                      onPressed: onToggleCollapsed,
                      icon: const Icon(TablerRegular.layout_sidebar_left_collapse, size: PregoIconSize.md),
                    ),
                  ),
                  const SizedBox(width: PregoSpacing.xs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class const _SidebarButton({
  super.key,
  required final String label,
  required final Widget icon,

  /// Shown at the row's end; its label joins the row's tooltip and spoken
  /// label.
  required final ({Widget icon, String label})? status,

  /// Shown at the row's end.
  required final String? shortcut,
  required final VoidCallback? onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final status = this.status;
    final description = status == null ? label : "$label, ${status.label}";
    final shortcut = this.shortcut;
    final color = onPressed == null ? prego.colors.textDisabled : prego.colors.textPrimary;
    final textStyle = prego.textTheme.textSm.medium.copyWith(color: color);
    final button = Semantics(
      button: true,
      enabled: onPressed != null,
      label: description,
      onTap: onPressed,
      excludeSemantics: true,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: onPressed,
        hoverColor: prego.colors.bgSecondaryHover,
        focusColor: prego.colors.textBrandPrimary.withValues(alpha: 0.18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.md + PregoSpacing.sm, vertical: PregoSpacing.xs),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(color: color),
                    child: icon,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: PregoSpacing.md),
                  child: status == null
                      ? _TooltipWhenTruncated(message: label, style: textStyle)
                      : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle),
                ),
              ),
              if (shortcut != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: PregoSpacing.md),
                  child: ExcludeSemantics(
                    child: Text(
                      shortcut,
                      style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
                    ),
                  ),
                ),
              if (status != null) SizedBox(width: 24, height: 20, child: Center(child: status.icon)),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PregoSpacing.xxs),
      // A status shows only its icon, so the tooltip names it.
      child: status == null
          ? button
          : Tooltip(
              message: shortcut == null ? description : context.loc.desktopShortcutHint(description, shortcut),
              child: button,
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

/// The selected row's fill. It spans the sidebar's width.
Color desktopSidebarSelectedFill(PregoColors colors) => colors.textBrandPrimary.withValues(alpha: 0.14);

/// The sidebar's name for [project]: its stored name, else its directory.
String desktopProjectDisplayName({required BuildContext context, required ProjectSummary project}) {
  return projectDisplayName(loc: context.loc, project: project);
}
