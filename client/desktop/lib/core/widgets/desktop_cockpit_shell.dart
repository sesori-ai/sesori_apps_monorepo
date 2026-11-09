import "dart:async";
import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

import "../di/injection.dart";
import "desktop_command_palette.dart";
import "desktop_connection_pill.dart";
import "desktop_page_toolbar.dart";
import "desktop_sidebar.dart";
import "desktop_sidebar_expansion.dart";

/// The signed-in [SessionScope] plus the cockpit's own layout owners.
class const DesktopCockpitCubitProvider({super.key, required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SessionScope(
    createProjectInventory: getIt.call<ProjectInventoryService>,
    createSessionWindow: ({required mode, required projectInventory}) =>
        getIt<SessionWindowService>(param1: mode, param2: projectInventory),
    createRefreshService: ({required projectInventory, required window}) =>
        getIt<SessionListRefreshService>(param1: projectInventory, param2: window),
    sessionCleanupService: getIt<SessionCleanupService>(),
    sessionLaunchService: getIt<SessionLaunchService>(),
    connectionService: getIt<ConnectionService>(),
    filterTracker: getIt<SessionListFilterTracker>(),
    sseEventTracker: getIt<SseEventTracker>(),
    sessionUnseenTracker: getIt<SessionUnseenTracker>(),
    alertNavigatorKey: null,
    child: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => DesktopSidebarCubit(repository: getIt())),
        // Not lazy: besides naming the computer, it fetches the account's
        // computers whenever the relay is reachable, which the sidebar's
        // computer row relies on, as nothing else there loads the list.
        BlocProvider(
          lazy: false,
          create: (_) => BridgeIdentityCubit(
            registeredBridgesService: getIt<RegisteredBridgesService>(),
            connectionService: getIt<ConnectionService>(),
            selectedComputerService: getIt<SelectedComputerService>(),
          ),
        ),
        BlocProvider(
          create: (_) => ComputerSwitcherCubit(
            registeredBridgesService: getIt<RegisteredBridgesService>(),
            connectionService: getIt<ConnectionService>(),
            selectedComputerService: getIt<SelectedComputerService>(),
            activeBridgeLocality: getIt<ActiveBridgeLocality>(),
          ),
        ),
        BlocProvider(
          create: (_) => LinkedComputerAlertCubit(
            registeredBridgesService: getIt<RegisteredBridgesService>(),
            activeBridgeLocality: getIt<ActiveBridgeLocality>(),
          ),
        ),
      ],
      child: LinkedComputerAlerts(
        navigatorKey: null,
        onSwitchComputer: ({required bridgeId, required source}) =>
            unawaited(getIt<ComputerSwitchDispatcher>().switchTo(bridgeId: bridgeId, source: source)),
        child: child,
      ),
    ),
  );
}

/// Product-shell navigation and supervision chrome around the desktop cockpit.
class const DesktopCockpitShell({
  super.key,
  required final String? selectedProjectId,
  required final String? selectedSessionId,
  required final SidebarSessionOpenedCallback onOpenSession,

  /// Opens a new session in a project, including one just added.
  required final ProjectOpenedCallback onNewSession,
  required final SessionListActionDispatcher sessionActions,

  /// Opens the Computers page from the sidebar's computer menu.
  required final VoidCallback onManageComputers,
  required final VoidCallback onOpenBridgeSettings,
  required final VoidCallback onOpenSettings,

  /// Opens the Archived page over the current one.
  required final VoidCallback onOpenArchived,

  /// Closes what the page has open, such as its Prompts screen, else leaves a
  /// pushed page; a page reached from the sidebar has nowhere to go.
  required final VoidCallback onGoBack,
  required final Widget child,
}) extends StatelessWidget {
  static const double autoCollapseBreakpoint = 760;
  static const double narrowWindowWidth = 1000;
  static const double narrowSidebarWidth = 240;

  @override
  Widget build(BuildContext context) {
    final sidebar = context.read<DesktopSidebarCubit>();
    final sessions = context.read<AllSessionsCubit>();
    // macOS only: the window has no title bar of its own (see `FlutterWindowHost`).
    final windowHost = defaultTargetPlatform == TargetPlatform.macOS ? getIt<WindowHost>() : null;
    // A first project's next step is its first session.
    void addProject() => unawaited(
      showAddProjectDialog(context: context, onProjectAdded: onNewSession),
    );
    // The open project, else the list's new-session default (the filter, else
    // "No project", else the newest session's project), else the first listed
    // one; with no project yet, adding one is the only useful next step. A
    // chosen project missing from the inventory (hidden meanwhile) is never
    // swapped for another one.
    void startNewSession() {
      final projects = context.read<ProjectListCubit>().state;
      if (projects is! ProjectListLoaded) return;
      final projectId = selectedProjectId ?? sessions.state.defaultProjectId;
      final project = projectId == null
          ? projects.projects.firstOrNull
          : projects.projects.where((project) => project.id == projectId).firstOrNull;
      if (project == null) {
        if (projects.projects.isEmpty) addProject();
        return;
      }
      onNewSession(
        context: context,
        project: project,
        displayName: desktopProjectDisplayName(context: context, project: project),
      );
    }

    void switchComputer({required String bridgeId, required ComputerSwitchSource source}) =>
        unawaited(getIt<ComputerSwitchDispatcher>().switchTo(bridgeId: bridgeId, source: source));

    return LayoutBuilder(
      builder: (context, constraints) {
        final autoCollapsed = constraints.maxWidth < autoCollapseBreakpoint;
        final loc = context.loc;
        final computers = context.watch<ComputerSwitcherCubit>().state;
        // As the sidebar's row: absent until projects load, Add project while there are none.
        final hasProjects = context.select(
          (ProjectListCubit cubit) => switch (cubit.state) {
            ProjectListLoaded(:final projects) => projects.isNotEmpty,
            ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => null,
          },
        );
        // Page-only commands, such as Mark as unread, stay with their page.
        final commands = [
          if (hasProjects != null)
            DesktopCommand(
              label: hasProjects ? loc.sessionListNewSession : loc.addProject,
              icon: TablerRegular.plus,
              shortcut: desktopShortcut(key: LogicalKeyboardKey.keyN),
              run: startNewSession,
            ),
          // An auto-collapsed sidebar cannot open, so it has no toggle.
          if (!autoCollapsed)
            DesktopCommand(
              label: loc.desktopToggleSidebar,
              icon: TablerRegular.layout_sidebar_left_collapse,
              shortcut: desktopShortcut(key: LogicalKeyboardKey.keyB),
              run: () => unawaited(sidebar.toggleCollapsed()),
            ),
          DesktopCommand(
            label: loc.settingsTitle,
            icon: TablerRegular.settings,
            shortcut: desktopShortcut(key: LogicalKeyboardKey.comma),
            run: onOpenSettings,
          ),
          // The sidebar's row, for a window too narrow to show the sidebar.
          DesktopCommand(
            label: loc.archivedSessionsTitle,
            icon: TablerRegular.archive,
            shortcut: null,
            run: onOpenArchived,
          ),
          DesktopCommand(
            label: loc.desktopGoBack,
            icon: TablerRegular.arrow_left,
            shortcut: desktopShortcut(key: LogicalKeyboardKey.bracketLeft),
            run: onGoBack,
          ),
          // The way to switch while the sidebar, and its computer row, is hidden.
          for (final computer in computers.computers)
            if (computer.id != computers.currentId)
              DesktopCommand(
                label: computers.isThisComputer(bridgeId: computer.id)
                    ? loc.desktopSwitchToThisComputer
                    : loc.desktopSwitchToComputer(computer.name),
                detail: ComputerMenu.presenceLabel(context: context, computer: computer),
                icon: ComputerMenu.platformIcon(platform: computer.platform),
                shortcut: null,
                run: () => switchComputer(bridgeId: computer.id, source: ComputerSwitchSource.commandPalette),
              ),
        ];
        void openPalette() => unawaited(
          showDesktopCommandPalette(
            context: context,
            commands: commands,
            onOpenSession: onOpenSession,
            // The sidebar opens to show the list it filtered.
            onSelectProject: ({required projectId}) {
              sessions.selectProject(projectId: projectId);
              if (sidebar.state.collapsed) unawaited(sidebar.toggleCollapsed());
            },
          ),
        );
        bool collapsed(BuildContext context) =>
            context.select((DesktopSidebarCubit cubit) => cubit.state.collapsed) || autoCollapsed;
        final content = Stack(
          fit: StackFit.expand,
          children: [
            child,
            const PositionedDirectional(
              top: DesktopPageToolbar.height + PregoSpacing.md,
              end: PregoSpacing.xl,
              child: DesktopConnectionPill(),
            ),
          ],
        );
        // The sidebar runs the window's full height, its edge a hairline that
        // lights up under the pointer.
        final row = Builder(
          builder: (context) {
            final saved = context.select((DesktopSidebarCubit cubit) => cubit.state.width);
            // A window this small keeps more of itself for the page; the saved
            // width returns with the room for it.
            final width = constraints.maxWidth < narrowWindowWidth ? math.min(saved, narrowSidebarWidth) : saved;
            return _SlidingLayout(
              panelWidth: width,
              panel: _SidebarPanel(
                width: width,
                resizeHandle: Builder(
                  builder: (context) =>
                      collapsed(context) ? const SizedBox.shrink() : _SidebarResizeHandle(sidebar: sidebar),
                ),
                child: DesktopSidebar(
                  windowHost: windowHost,
                  selectedSessionId: selectedSessionId,
                  onOpenSession: onOpenSession,
                  onStartNewSession: startNewSession,
                  onOpenSearch: openPalette,
                  onOpenArchived: onOpenArchived,
                  sessionActions: sessionActions,
                  onToggleCollapsed: () => unawaited(sidebar.toggleCollapsed()),
                  onSwitchComputer: switchComputer,
                  onManageComputers: onManageComputers,
                  onOpenBridgeSettings: onOpenBridgeSettings,
                  onOpenSettings: onOpenSettings,
                ),
              ),
              page: content,
              titleBar: Builder(
                builder: (context) => _SidebarTitleBar(
                  collapsed: collapsed(context),
                  autoCollapsed: autoCollapsed,
                  onPressed: () => unawaited(sidebar.toggleCollapsed()),
                ),
              ),
            );
          },
        );
        // Only the animation follows a toggle: the sidebar reads its expansion
        // from it, so the panel's rows are not rebuilt to start one.
        final scaffold = Scaffold(
          body: Builder(
            builder: (context) => _SidebarExpansionAnimator(
              target: collapsed(context) ? 0 : 1,
              // A shortcut is answered at once; only a click gets the motion.
              duration: switch ((prefersReducedMotion(context) || pregoActivatedByKeyboard, collapsed(context))) {
                (true, _) => Duration.zero,
                (false, true) => const Duration(milliseconds: 180),
                (false, false) => const Duration(milliseconds: 200),
              },
              // Softer than a popover's curve: the whole page moves with this one.
              curve: const Cubic(0.25, 0.55, 0.2, 1),
              child: row,
            ),
          ),
        );
        return CallbackShortcuts(
          bindings: {
            for (final command in commands) ?command.shortcut: command.run,
            desktopShortcut(key: LogicalKeyboardKey.keyK): openPalette,
          },
          child: Focus(autofocus: true, child: scaffold),
        );
      },
    );
  }
}

/// Animates the sidebar's expansion like a [TweenAnimationBuilder], but hands
/// [child] the animation through [DesktopSidebarExpansion] instead of
/// rebuilding it with every value: only the parts that read the animation
/// update during a frame.
class const _SidebarExpansionAnimator({
  required final double target,
  required super.duration,
  required super.curve,
  required final Widget child,
}) extends ImplicitlyAnimatedWidget {
  @override
  ImplicitlyAnimatedWidgetState<_SidebarExpansionAnimator> createState() => _SidebarExpansionAnimatorState();
}

class _SidebarExpansionAnimatorState() extends ImplicitlyAnimatedWidgetState<_SidebarExpansionAnimator> {
  // One tween, retargeted in place by every change of [target].
  Tween<double>? _tween;
  Animation<double>? _expansion;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    // The visitor only constructs a tween for the target it was handed.
    _tween = switch (visitor(_tween, widget.target, (_) => Tween<double>(begin: widget.target))) {
      final Tween<double> tween => tween,
      _ => null,
    };
  }

  @override
  void didUpdateTweens() {
    if (_tween case final tween? when _expansion == null) _expansion = animation.drive(tween);
  }

  @override
  Widget build(BuildContext context) => DesktopSidebarExpansion(
    expansion: _expansion ?? kAlwaysCompleteAnimation,
    child: widget.child,
  );
}

/// The panel over the page. The panel moves by transform. The page's start edge
/// follows it frame by frame, so nothing on the page jumps when a toggle begins,
/// and because the transcript's column is capped, its text keeps its width and
/// is not laid out again as the page widens.
class const _SlidingLayout({
  required final double panelWidth,
  required final Widget panel,
  required final Widget page,
  required final Widget titleBar,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final extent = panelWidth;
    return Stack(
      fit: StackFit.expand,
      children: [
        DesktopSidebarExpansionBuilder(
          expansion: DesktopSidebarExpansion.of(context),
          builder: (expansion, page) => Padding(
            padding: EdgeInsetsDirectional.only(start: extent * expansion),
            child: page,
          ),
          child: page,
        ),
        PositionedDirectional(start: 0, top: 0, bottom: 0, child: panel),
        titleBar,
      ],
    );
  }
}

/// The full-height sidebar and the resize handle astride its edge. Collapsing
/// slides both out past the window's edge (D9) while the page takes their room.
class const _SidebarPanel({
  required final double width,
  required final Widget resizeHandle,
  required final Widget child,
}) extends StatelessWidget {
  /// How far the handle reaches each side of the edge's middle.
  static const double _handleReach = 4.5;

  @override
  Widget build(BuildContext context) {
    final expansion = DesktopSidebarExpansion.of(context);
    final prego = context.prego;
    final extent = width + _handleReach;
    final panel = SizedBox(
      width: extent,
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: width,
            child: DecoratedBox(
              key: const Key("desktop-cockpit-sidebar"),
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: BorderDirectional(end: BorderSide(color: prego.colors.borderSecondary)),
              ),
              child: Material(
                color: prego.colors.pointerPanelFill,
                child: child,
              ),
            ),
          ),
          PositionedDirectional(
            start: width - 0.5 - _handleReach,
            top: 0,
            bottom: 0,
            width: _handleReach * 2,
            child: resizeHandle,
          ),
        ],
      ),
    );
    final towardStart = Directionality.of(context) == TextDirection.rtl ? 1.0 : -1.0;
    return DesktopSidebarExpansionSelector<bool>(
      expansion: expansion,
      select: (expansion) => expansion > 0,
      // Hidden, it keeps its list and scroll offset but leaves the focus order
      // and the screen reader.
      builder: (context, shown) => Visibility(
        visible: shown,
        maintainState: true,
        child: DesktopSidebarExpansionBuilder(
          expansion: expansion,
          builder: (expansion, panel) => Transform.translate(
            offset: Offset(towardStart * extent * (1 - expansion), 0),
            child: panel,
          ),
          child: panel,
        ),
      ),
    );
  }
}

/// The sidebar's toggle and the product's name, on the title line above both the
/// sidebar and the page. They stay where they are as the sidebar slides, so the
/// control stays under the pointer and the name never crosses the traffic lights.
class const _SidebarTitleBar({
  required final bool collapsed,
  required final bool autoCollapsed,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  static const String _productName = "Sesori";

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    const size = DesktopSidebarRestoreInset.buttonSize;
    final label = collapsed ? loc.desktopSidebarExpand : loc.desktopSidebarCollapse;
    return PositionedDirectional(
      top: DesktopSidebarRestoreInset.titleLineCentre - size / 2,
      start: DesktopSidebarRestoreInset.buttonStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: PregoSpacing.xs,
        children: [
          SizedBox.square(
            dimension: size,
            child: IconButton(
              key: Key(collapsed ? "desktop-sidebar-restore" : "desktop-sidebar-toggle"),
              // A window too narrow for the sidebar keeps it hidden.
              tooltip: autoCollapsed
                  ? label
                  : loc.desktopShortcutHint(label, defaultTargetPlatform == TargetPlatform.macOS ? "⌘B" : "Ctrl+B"),
              padding: EdgeInsets.zero,
              onPressed: autoCollapsed ? null : onPressed,
              icon: Transform.translate(
                offset: DesktopSidebarRestoreInset.toggleGlyphNudge,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      collapsed ? TablerLight.layout_sidebar_left_expand : TablerLight.layout_sidebar_left_collapse,
                      size: 16,
                      color: autoCollapsed ? prego.colors.textDisabled : null,
                    ),
                    // The sidebar's Needs you, while it is out of sight.
                    if (collapsed &&
                        context.select(
                          (AllSessionsCubit cubit) => cubit.state.rows.any((row) => row.isAwaitingInput),
                        ))
                      PositionedDirectional(
                        top: -2,
                        end: -2,
                        child: Container(
                          key: const Key("desktop-sidebar-needs-you"),
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: prego.colors.pointerWarningFill,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Decoration in the title bar: clicks reach the window drag beneath it.
          IgnorePointer(
            child: ExcludeSemantics(
              child: Text(
                _productName,
                maxLines: 1,
                style: prego.textTheme.textSm.medium.copyWith(
                  color: collapsed ? prego.colors.textSecondary : prego.colors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class const _SidebarResizeHandle({required final DesktopSidebarCubit sidebar}) extends StatefulWidget {
  @override
  State<_SidebarResizeHandle> createState() => _SidebarResizeHandleState();
}

class _SidebarResizeHandleState() extends State<_SidebarResizeHandle> with TickerProviderStateMixin {
  late final AnimationController _lit = AnimationController(
    vsync: this,
    duration: pregoPointerEnterDuration,
    reverseDuration: pregoPointerExitDuration,
  );
  final ValueNotifier<double> _pointerY = ValueNotifier(0);

  /// Whether letting go of the drag here would collapse the sidebar.
  late final AnimationController _armed = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
  );
  bool _hovering = false;

  /// How far past the sidebar's minimum width a released drag collapses it.
  static const double _collapseReach = 48;

  ({double width, double pointerX})? _dragOrigin;
  double _draggedTo = 0;

  void _updateLit() {
    if (_hovering || _dragOrigin != null) {
      _lit.forward();
    } else {
      _lit.reverse();
    }
  }

  void _finishDrag({required bool released}) {
    // A tap also cancels the drag recognizer, without starting a drag.
    final origin = _dragOrigin;
    if (origin == null) return;
    _dragOrigin = null;
    _armed.value = 0;
    _updateLit();
    if (released && _draggedTo < DesktopSidebarCubit.minWidth - _collapseReach) {
      unawaited(widget.sidebar.collapseFromDrag(reopenWidth: origin.width));
    } else {
      unawaited(widget.sidebar.saveLayout());
    }
  }

  @override
  void dispose() {
    _lit.dispose();
    _pointerY.dispose();
    _armed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeLeftRight,
    onEnter: (event) {
      _hovering = true;
      _pointerY.value = event.localPosition.dy;
      _updateLit();
    },
    onHover: (event) => _pointerY.value = event.localPosition.dy,
    onExit: (_) {
      _hovering = false;
      _updateLit();
    },
    // A node of its own, or its name lands on the whole window.
    child: Semantics(
      container: true,
      tooltip: context.loc.desktopSidebarResize,
      child: GestureDetector(
        key: const Key("desktop-sidebar-resize"),
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onTap: () => unawaited(widget.sidebar.toggleCollapsed()),
        onHorizontalDragStart: (details) {
          _dragOrigin = (width: widget.sidebar.state.width, pointerX: details.globalPosition.dx);
          _draggedTo = widget.sidebar.state.width;
          _updateLit();
        },
        onHorizontalDragUpdate: (details) {
          _pointerY.value = details.localPosition.dy;
          if (_dragOrigin case final origin?) {
            _draggedTo = origin.width + details.globalPosition.dx - origin.pointerX;
            if (_draggedTo < DesktopSidebarCubit.minWidth - _collapseReach) {
              _armed.forward();
            } else {
              _armed.reverse();
            }
            widget.sidebar.resize(width: _draggedTo);
          }
        },
        onHorizontalDragEnd: (_) => _finishDrag(released: true),
        onHorizontalDragCancel: () => _finishDrag(released: false),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _SidebarEdgeLight(
              lit: _lit,
              pointerY: _pointerY,
              armed: _armed,
              color: context.prego.colors.textTertiary,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

/// The stretch of the sidebar's edge near the pointer, brightening in light
/// themes' ink or dark themes' light, and tapering away along the edge.
class _SidebarEdgeLight({
  required final Animation<double> lit,
  required final ValueListenable<double> pointerY,

  /// Whether a release collapses the sidebar: the whole edge lights to say so.
  required final Animation<double> armed,
  required final Color color,
}) extends CustomPainter {
  this : super(repaint: Listenable.merge([lit, pointerY, armed]));

  static const double _reach = 110;
  static const double _thickness = 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (lit.value <= 0) return;
    final strong = color.withValues(alpha: color.a * lit.value);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, pointerY.value),
      width: _thickness,
      height: _reach * 2,
    );
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..drawRect(
        Rect.fromCenter(center: size.center(Offset.zero), width: _thickness, height: size.height),
        Paint()..color = strong.withValues(alpha: strong.a * armed.value),
      )
      ..drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              strong.withValues(alpha: 0),
              strong.withValues(alpha: strong.a * 0.35),
              strong,
              strong.withValues(alpha: strong.a * 0.35),
              strong.withValues(alpha: 0),
            ],
            stops: const [0, 0.25, 0.5, 0.75, 1],
          ).createShader(rect),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_SidebarEdgeLight oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.lit != lit ||
      oldDelegate.pointerY != pointerY ||
      oldDelegate.armed != armed;
}
