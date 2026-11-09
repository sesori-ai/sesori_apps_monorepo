import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/scheduler.dart";
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

/// Desktop navigation frame: New session, Search, Archived, and the shared
/// list of sessions across projects under its project filter (D4).
class const DesktopSidebar({
  super.key,

  /// Set on macOS, where the traffic lights sit on this panel's top: it makes
  /// room for them there, and that room drags and zooms the window.
  required final WindowHost? windowHost,
  required final String? selectedSessionId,
  required final SidebarSessionOpenedCallback onOpenSession,
  required final VoidCallback onStartNewSession,
  required final VoidCallback onOpenSearch,
  required final VoidCallback onOpenArchived,
  required final SessionListActionDispatcher sessionActions,
  required final VoidCallback onToggleCollapsed,
  required final ComputerSwitchCallback onSwitchComputer,
  required final VoidCallback onManageComputers,
  required final VoidCallback onOpenBridgeSettings,
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
    final prego = context.prego;
    final panelColor = prego.colors.pointerPanelFill;
    final newSessionShortcut = defaultTargetPlatform == TargetPlatform.macOS ? "⌘N" : "Ctrl+N";
    // The shell's panel paints the surface.
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
              icon: const Icon(TablerLight.plus, size: _navIconSize),
              status: null,
              shortcut: newSessionShortcut,
              onPressed: state is ProjectListLoaded ? onStartNewSession : null,
            ),
            _SidebarButton(
              key: const Key("desktop-sidebar-search"),
              label: loc.desktopSearch,
              icon: const Icon(TablerLight.search, size: _navIconSize),
              status: null,
              shortcut: defaultTargetPlatform == TargetPlatform.macOS ? "⌘K" : "Ctrl+K",
              onPressed: onOpenSearch,
            ),
            // Offline, the page itself lists nothing while the pill and the
            // footer's recovery card say why, so the row stays enabled.
            _SidebarButton(
              key: const Key("desktop-sidebar-archived"),
              label: loc.archivedSessionsTitle,
              icon: const Icon(TablerLight.archive, size: _navIconSize),
              status: null,
              shortcut: null,
              onPressed: onOpenArchived,
            ),
            _SidebarFilter(projectState: state, projectId: filterId, projectName: filterName),
            Expanded(
              // Ink paints on the nearest Material, outside the list's own clip: this
              // one keeps a row's highlight from showing through the section above.
              child: Material(
                type: MaterialType.transparency,
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  children: [
                    CustomScrollView(
                      key: const Key("desktop-sidebar-session-list"),
                      slivers: [
                        _PausesHoverWhileScrolling(
                          sliver: AllSessionsList(
                            onSessionTap: ({required row}) => onOpenSession(
                              context: context,
                              project: row.project,
                              displayName: desktopProjectDisplayName(context: context, project: row.project),
                              session: row.session,
                            ),
                            actionDispatcher: sessionActions,
                            createActions: ({required window}) =>
                                createSessionActionsCubit(locator: getIt, window: window),
                            selectedSessionId: selectedSessionId,
                            // The footer's recovery card says so, unless this
                            // computer's bridge is still starting: that is the
                            // list's own load, whose one skeleton hands off to the
                            // rows.
                            disconnectedBuilder: ({required context, required state}) =>
                                context.select(
                                  (LocalBridgeStartupCubit cubit) => cubit.state == LocalBridgeStartupState.starting,
                                )
                                ? null
                                : SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsetsDirectional.fromSTEB(14, PregoSpacing.md, 14, 0),
                                      child: Text(
                                        loc.desktopSidebarOfflineHint,
                                        style: context.prego.textTheme.textXs.regular.copyWith(
                                          color: context.prego.colors.textTertiary,
                                        ),
                                      ),
                                    ),
                                  ),
                            // The home pane says so, and Refresh retries it.
                            showsLoadFailure: false,
                            // The Search row above opens the palette, which searches sessions.
                            showsSearchField: false,
                            // With no project at all the page offers the one next step.
                            emptyState: state is ProjectListLoaded && state.projects.isEmpty
                                ? const SizedBox.shrink()
                                : SessionEmptyState(projectName: filterName),
                            // The filter heads the list already, beside Refresh.
                            header: null,
                            // The last row scrolls clear of the floating scan card.
                            endClearance: catalogScanRowClearance(context: context),
                          ),
                        ),
                      ],
                    ),
                    // Floats over the bottom of the list rather than taking a
                    // place in it, so neither its arrival nor its exit moves a
                    // row or a chip under the pointer. A lost connection clears
                    // the scan, so it is empty while this computer is
                    // unreachable.
                    PositionedDirectional(
                      start: 0,
                      end: 0,
                      bottom: 0,
                      height: 20,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [panelColor.withValues(alpha: 0), panelColor, panelColor],
                              stops: const [0, 0.8, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: 0,
                      end: 0,
                      bottom: 0,
                      child: CatalogScanRow(
                        scan: context.select((SessionListRefreshCubit refresh) => refresh.state.scan),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _SidebarFooter(
              // The home page explains a lost bridge itself, in the centre.
              showsRecovery: state is! ProjectListBridgeDisconnected || selectedSessionId != null,
              onToggleCollapsed: onToggleCollapsed,
              onSwitchComputer: onSwitchComputer,
              onManageComputers: onManageComputers,
              onOpenBridgeSettings: onOpenBridgeSettings,
              onOpenSettings: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}

/// The room above the panel's first control, under the title line. It stands in
/// for the title bar: on macOS it drags the window and zooms it on a double click.
class const _TopStrip({required final WindowHost? windowHost}) extends StatelessWidget {
  static const double _height = 44;

  @override
  Widget build(BuildContext context) {
    final windowHost = this.windowHost;
    if (windowHost == null) return const SizedBox(height: _height);
    return DesktopWindowDragArea(
      windowHost: windowHost,
      height: _height,
      zoomOnDoubleClick: true,
      child: const SizedBox(height: _height, width: double.infinity),
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
    final noProjects = switch (projectState) {
      ProjectListLoaded(:final projects) => projects.isEmpty,
      ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => false,
    };
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(6, PregoSpacing.md, 6, 0),
      child: Row(
        children: [
          Expanded(
            child: noProjects
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(start: PregoSpacing.md),
                    child: Text(
                      context.loc.desktopSidebarNoProjects,
                      style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
                    ),
                  )
                : Align(
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
                            padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.md, vertical: PregoSpacing.xs),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    projectName ?? context.loc.projectPickerAllProjects,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: prego.textTheme.textXs.medium.copyWith(color: secondary),
                                  ),
                                ),
                                const SizedBox(width: PregoSpacing.xs),
                                Icon(TablerLight.chevron_down, size: PregoIconSize.sm, color: secondary),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          SizedBox.square(
            dimension: 26,
            child: _SidebarRefreshButton(projectState: projectState, iconSize: PregoIconSize.sm, color: secondary),
          ),
        ],
      ),
    );
  }
}

/// Rows take no hover while the list scrolls, and for a moment after each wheel
/// tick, so the highlight doesn't hop along under a pointer that isn't moving.
class const _PausesHoverWhileScrolling({required final Widget sliver}) extends StatefulWidget {
  @override
  State<_PausesHoverWhileScrolling> createState() => _PausesHoverWhileScrollingState();
}

class _PausesHoverWhileScrollingState() extends State<_PausesHoverWhileScrolling> {
  ValueListenable<bool>? _scrolling;
  Timer? _release;
  bool _paused = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrolling = Scrollable.of(context).position.isScrollingNotifier;
    if (identical(scrolling, _scrolling)) return;
    _scrolling?.removeListener(_onScrollingChanged);
    _scrolling = scrolling..addListener(_onScrollingChanged);
  }

  void _onScrollingChanged() {
    _release?.cancel();
    if (_scrolling?.value ?? false) {
      _setPaused(true);
    } else {
      _release = Timer(const Duration(milliseconds: 100), () => _setPaused(false));
    }
  }

  void _setPaused(bool paused) {
    if (paused == _paused) return;
    // An overscrolled list that shrinks settles from inside layout, too late to rebuild this frame.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _paused = paused);
      });
    } else {
      setState(() => _paused = paused);
    }
  }

  @override
  void dispose() {
    _release?.cancel();
    _scrolling?.removeListener(_onScrollingChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SliverIgnorePointer(ignoring: _paused, sliver: widget.sliver);
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
    // The list leaves a failed load to the home pane, so Refresh retries it
    // from here too.
    final VoidCallback? onPressed = switch (projectState) {
      ProjectListLoaded() when !refreshing => () => unawaited(context.read<SessionListRefreshCubit>().refresh()),
      ProjectListFailed() => () => unawaited(context.read<ProjectListCubit>().retryLoadProjects()),
      ProjectListLoaded() || ProjectListLoading() || ProjectListBridgeDisconnected() => null,
    };
    return IconButton(
      key: const Key("desktop-sidebar-refresh"),
      tooltip: refreshing ? loc.desktopSidebarRefreshing : loc.desktopSidebarRefresh,
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      // The tooltip names it for screen readers too.
      icon: refreshing
          ? ExcludeSemantics(
              child: SizedBox.square(dimension: iconSize, child: const PregoActivityIndicator(color: null)),
            )
          : Icon(TablerLight.refresh, size: iconSize, color: color),
    );
  }
}

class const _SidebarFooter({
  required final bool showsRecovery,
  required final VoidCallback onToggleCollapsed,
  required final ComputerSwitchCallback onSwitchComputer,
  required final VoidCallback onManageComputers,
  required final VoidCallback onOpenBridgeSettings,
  required final VoidCallback onOpenSettings,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final macOS = defaultTargetPlatform == TargetPlatform.macOS;
    Widget control(Widget button) => SizedBox.square(dimension: 28, child: button);
    return BlocListener<SessionListRefreshCubit, SessionListRefreshState>(
      // A refresh that worked shows in the button and the list; only a failure speaks.
      listenWhen: (previous, current) =>
          previous.status != current.status && current.status == SessionListRefreshStatus.failed,
      listener: (context, state) => PregoPopupAlertPresenter.of(
        context,
      ).show(title: loc.desktopSidebarRefreshFailed, variant: PregoPopupAlertsNotificationsVariant.error),
      child: Container(
        key: const Key("desktop-sidebar-footer"),
        decoration: BoxDecoration(
          color: prego.colors.pointerPanelFill,
          border: Border(top: BorderSide(color: prego.colors.borderSecondary)),
        ),
        child: Column(
          children: [
            if (showsRecovery) const DesktopBridgeRecoveryCard(compact: false),
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    child: _SidebarComputerRow(
                      onSwitchComputer: onSwitchComputer,
                      onManageComputers: onManageComputers,
                      onOpenBridgeSettings: onOpenBridgeSettings,
                    ),
                  ),
                  control(
                    IconButton(
                      key: const Key("desktop-sidebar-settings"),
                      tooltip: loc.desktopShortcutHint(loc.settingsTitle, macOS ? "⌘," : "Ctrl+,"),
                      padding: EdgeInsets.zero,
                      onPressed: onOpenSettings,
                      icon: const Icon(TablerLight.settings, size: _navIconSize),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Names the computer the app works on, with its status, and opens the menu
/// to switch computers above this computer's own bridge controls. The menu
/// lists no computers while this one is the account's only one.
class const _SidebarComputerRow({
  required final ComputerSwitchCallback onSwitchComputer,
  required final VoidCallback onManageComputers,
  required final VoidCallback onOpenBridgeSettings,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    final loc = context.loc;
    final bridge = context.watch<BridgeControlCubit>().state;
    final computers = context.watch<ComputerSwitcherCubit>().state;
    final remote = computers.viewsAnotherComputer;
    final current = computers.computers.where((computer) => computer.id == computers.currentId).firstOrNull;
    final (:name, :dot, :statusLabel) = switch ((remote, current)) {
      (false, _) => (
        name: loc.desktopSettingsThisComputer,
        dot: desktopBridgeStatusColor(colors: colors, state: bridge),
        statusLabel: bridge.statusLabel,
      ),
      (true, final BridgeSummary current) => (
        name: current.name,
        dot: ComputerMenu.presenceStatus(computer: current).dotColor(colors: colors),
        statusLabel: ComputerMenu.presenceLabel(context: context, computer: current),
      ),
      // Another computer, until the account's list names it.
      (true, null) => (name: loc.computersTitle, dot: colors.textDisabled, statusLabel: loc.computerMenuSwitchHint),
    };
    return PregoAnchorMenu(
      flat: true,
      menuWidth: 264,
      triggerBuilder: (context, toggle) => _SidebarButton(
        key: const Key("desktop-sidebar-computer"),
        label: name,
        // A status dot, not a glyph: no icon token applies. Keyed so a change
        // of colour crossfades with the name.
        icon: AnimatedSwitcher(
          duration: _SidebarButton._statusFade,
          child: Icon(TablerSolid.circle, key: ValueKey(dot), size: 8, color: dot),
        ),
        status: statusLabel,
        shortcut: null,
        trailing: Icon(TablerLight.selector, size: PregoIconSize.sm, color: colors.textTertiary),
        onPressed: toggle,
      ),
      entriesBuilder: () => [
        if (remote || computers.computers.length > 1) ...[
          ...ComputerMenu.entries(
            context: context,
            state: computers,
            onSelect: ({required bridgeId}) => onSwitchComputer(bridgeId: bridgeId, source: ComputerSwitchSource.menu),
            onManageComputers: onManageComputers,
            currentFirst: false,
          ),
          const PregoMenuDivider(),
        ],
        PregoMenuCustom(
          // Only the glass menu reads the height; this one is flat.
          height: 0,
          builder: (context, close) => DesktopBridgePopover(close: close, onOpenSettings: onOpenBridgeSettings),
        ),
      ],
    );
  }
}

class const _SidebarButton({
  super.key,
  required final String label,
  required final Widget icon,

  /// Joins the row's tooltip and spoken label.
  required final String? status,

  /// Shown at the row's end.
  required final String? shortcut,

  /// Shown at the row's end: what a press opens.
  final Widget? trailing,
  required final VoidCallback? onPressed,
}) extends StatelessWidget {
  static const Duration _statusFade = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final status = this.status;
    final description = status == null ? label : "$label, $status";
    final shortcut = this.shortcut;
    final color = onPressed == null ? prego.colors.textDisabled : prego.colors.textPrimary;
    final textStyle = prego.textTheme.textSm.regular.copyWith(color: color);
    final button = Semantics(
      button: true,
      enabled: onPressed != null,
      label: description,
      onTap: onPressed,
      excludeSemantics: true,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(PregoRadius.sm),
        hoverDuration: Duration.zero,
        hoverColor: prego.colors.bgSecondaryHover.withValues(alpha: 0.5),
        focusColor: prego.colors.textBrandPrimary.withValues(alpha: 0.18),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(PregoSpacing.sm, 5, PregoSpacing.md, 5),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(color: onPressed == null ? color : prego.colors.textSecondary),
                    child: icon,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: PregoSpacing.md),
                  child: status == null
                      ? _TooltipWhenTruncated(message: label, style: textStyle)
                      // A new computer's name crossfades in the same place.
                      : AnimatedSwitcher(
                          duration: _statusFade,
                          layoutBuilder: (current, previous) => Stack(
                            alignment: AlignmentDirectional.centerStart,
                            children: [...previous, ?current],
                          ),
                          child: Text(
                            label,
                            key: ValueKey(label),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textStyle,
                          ),
                        ),
                ),
              ),
              if (shortcut != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: PregoSpacing.md),
                  child: ExcludeSemantics(
                    child: Text(
                      shortcut,
                      style: prego.textTheme.textXs.regular.copyWith(
                        color: onPressed == null ? prego.colors.textDisabled : prego.colors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      // A status shows only its icon, so the tooltip names it.
      child: status == null
          ? button
          : Tooltip(
              message: shortcut == null ? description : context.loc.desktopShortcutHint(description, shortcut),
              excludeFromSemantics: true,
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

/// The size of the sidebar's navigation glyphs.
const double _navIconSize = 16;

/// A selected navigation row's fill.
Color desktopSidebarSelectedFill(PregoColors colors) => colors.pointerSelectionFill;

/// The sidebar's name for [project]: its stored name, else its directory.
String desktopProjectDisplayName({required BuildContext context, required ProjectSummary project}) {
  return projectDisplayName(loc: context.loc, project: project);
}
