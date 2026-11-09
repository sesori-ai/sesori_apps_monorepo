import "dart:async";
import "dart:ui" show ImageFilter;

import "package:flutter/foundation.dart";
import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/widgets/desktop_sidebar.dart";
import "desktop_attention_preference_section.dart";
import "desktop_general_settings_screen.dart";
import "desktop_harnesses_settings_screen.dart";
import "desktop_profile_screen.dart";

enum DesktopSettingsTab() {
  general,
  projects,
  bridge,
  notifications,
  account,
}

/// A page the Bridge tab pushes over its own settings page.
enum _BridgeSubpage() {
  harnesses,
  computers,
}

/// Root presentation, not a product route: the underlying session stays mounted.
Future<void> showDesktopSettingsModal({
  required BuildContext context,
  required DesktopSettingsTab initialTab,
  required VoidCallback onLogoutCompleted,
}) => _showDesktopSettings(
  context: context,
  initialTab: initialTab,
  bridgeSubpage: null,
  onLogoutCompleted: onLogoutCompleted,
);

/// The settings window on its Bridge tab with the Harnesses page already open.
Future<void> showDesktopHarnessSettings({
  required BuildContext context,
  required VoidCallback onLogoutCompleted,
}) => _showDesktopSettings(
  context: context,
  initialTab: DesktopSettingsTab.bridge,
  bridgeSubpage: _BridgeSubpage.harnesses,
  onLogoutCompleted: onLogoutCompleted,
);

/// The settings window on its Bridge tab with the Computers page already open.
Future<void> showDesktopComputersSettings({
  required BuildContext context,
  required VoidCallback onLogoutCompleted,
}) => _showDesktopSettings(
  context: context,
  initialTab: DesktopSettingsTab.bridge,
  bridgeSubpage: _BridgeSubpage.computers,
  onLogoutCompleted: onLogoutCompleted,
);

Future<void> _showDesktopSettings({
  required BuildContext context,
  required DesktopSettingsTab initialTab,

  /// The Bridge tab's page to open over its own, or null for none.
  required _BridgeSubpage? bridgeSubpage,
  required VoidCallback onLogoutCompleted,
}) async {
  final authGate = context.read<AuthGateCubit>();
  // The window is a root route above the cockpit, so the Projects tab gets the
  // cockpit's live list and the folder browser's service by value.
  final projectList = context.read<ProjectListCubit>();
  final connectionService = context.read<ConnectionService>();
  // A shortcut is answered at once; only a click gets the entrance.
  final instant =
      prefersReducedMotion(context) || GlassAccessibilityData.of(context).reduceMotion || pregoActivatedByKeyboard;
  // ignore: no_slop_linter/avoid_navigator_of, a desktop-only full-window surface above the router's own pages
  await Navigator.of(context, rootNavigator: true).push<void>(
    _DesktopSettingsRoute(
      barrierDismissible: true,
      barrierLabel: context.loc.settingsClose,
      barrierColor: Colors.transparent,
      transitionDuration: instant ? Duration.zero : pregoPointerEnterDuration,
      reverseDuration: instant ? Duration.zero : const Duration(milliseconds: 90),
      // The scrim and the panel fade apart: see the window's build.
      transitionBuilder: (_, _, _, child) => child,
      pageBuilder: (dialogContext, _, _) {
        void close() {
          // Logout can finish after the user has dismissed the dialog.
          if (!dialogContext.mounted) return;
          final route = ModalRoute.of(dialogContext);
          final navigator = route?.navigator;
          if (route?.isActive != true || navigator == null) return;
          if (route is _DesktopSettingsRoute && pregoActivatedByKeyboard) route.leaveAtOnce();
          // Owned authentication/setting sheets leave with their dialog.
          navigator.popUntil((candidate) => candidate == route);
          navigator.pop();
        }

        return MultiBlocProvider(
          providers: [
            BlocProvider<AuthGateCubit>.value(value: authGate),
            BlocProvider<ProjectListCubit>.value(value: projectList),
            RepositoryProvider<ConnectionService>.value(value: connectionService),
          ],
          child: BlocListener<AuthGateCubit, AuthGateState>(
            // A definitive token-refresh rejection can sign out while this root
            // overlay is above the gated cockpit; dismiss its owned UI as well.
            listenWhen: (_, state) => state is AuthGateSignedOut,
            listener: (_, _) => close(),
            child: _DesktopSettingsModal(
              initialTab: initialTab,
              initialBridgeSubpage: bridgeSubpage,
              onClose: close,
              onLogoutCompleted: () {
                close();
                onLogoutCompleted();
              },
            ),
          ),
        );
      },
    ),
  );
}

/// A dialog route that leaves faster than it arrives, which [showGeneralDialog]
/// cannot express.
class _DesktopSettingsRoute({
  required super.barrierDismissible,
  required super.barrierLabel,
  required super.barrierColor,
  required super.transitionDuration,
  required final Duration reverseDuration,
  required super.transitionBuilder,
  required super.pageBuilder,
}) extends RawDialogRoute<void> {
  this : super(settings: null);

  @override
  Duration get reverseTransitionDuration => reverseDuration;

  /// For a close from the keyboard, which is answered at once however the window opened.
  void leaveAtOnce() => controller?.reverseDuration = Duration.zero;
}

class const _DesktopSettingsModal({
  required final DesktopSettingsTab initialTab,
  required final _BridgeSubpage? initialBridgeSubpage,
  required final VoidCallback onClose,
  required final VoidCallback onLogoutCompleted,
}) extends StatefulWidget {
  @override
  State<_DesktopSettingsModal> createState() => _DesktopSettingsModalState();
}

class _DesktopSettingsModalState() extends State<_DesktopSettingsModal> {
  late DesktopSettingsTab _tab = widget.initialTab;

  /// The page the Bridge tab shows over its own, or null for its own page.
  /// Picking any tab, including the Bridge tab again, leaves it.
  late _BridgeSubpage? _bridgeSubpage = widget.initialBridgeSubpage;

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    // Match Prego's macOS backdrop policy: native AppKit indicators cannot be
    // sampled by Flutter blur. Keep them native and use the stronger scrim.
    // Honor the library's accessibility and adaptive-quality gates too.
    final blur =
        glassEffectsEnabled() &&
        defaultTargetPlatform != TargetPlatform.macOS &&
        !GlassAccessibilityData.of(context).reduceTransparency &&
        GlassAdaptiveScopeData.maybeOf(context)?.effectiveQuality != GlassQuality.minimal;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scrim = ColoredBox(color: Colors.black.withValues(alpha: dark ? 0.45 : 0.14));
    // The scrim fades; the panel also settles into place, except under reduced motion.
    final routeAnimation = ModalRoute.of(context)?.animation;
    final settle = routeAnimation == null || prefersReducedMotion(context)
        ? null
        : routeAnimation.drive(Tween<double>(begin: 0.98, end: 1).chain(CurveTween(curve: pregoPointerEnterCurve)));
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): widget.onClose},
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: switch (routeAnimation) {
                    null => kAlwaysCompleteAnimation,
                    // Dims with the panel's arrival, and lifts the moment it leaves.
                    final route => CurvedAnimation(
                      parent: route,
                      curve: const Interval(0, 0.4),
                      reverseCurve: Curves.easeOut,
                    ),
                  },
                  child: blur ? BackdropFilter(filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), child: scrim) : scrim,
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(PregoSpacing.lg),
                // Solid in the first frames and gone in the last ones, so the page behind
                // never reads through it.
                child: FadeTransition(
                  opacity: routeAnimation == null
                      ? kAlwaysCompleteAnimation
                      : CurvedAnimation(
                          parent: routeAnimation,
                          curve: const Interval(0, 0.07, curve: Curves.easeOut),
                          reverseCurve: const Interval(0.65, 1, curve: Curves.easeIn),
                        ),
                  child: ScaleTransition(
                    scale: settle ?? kAlwaysCompleteAnimation,
                    child: SizedBox(
                      width: 780,
                      height: 724,
                      child: Material(
                        key: const Key("desktop-settings-modal"),
                        color: colors.bgSecondary,
                        elevation: 24,
                        shadowColor: Colors.black.withValues(alpha: colors.brightness == .dark ? 1 : 0.3),
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(PregoRadius.xl),
                          side: BorderSide(color: colors.borderSecondary),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 188,
                              // A Material, not a ColoredBox: the tabs' selected Ink paints on it.
                              child: Material(
                                color: colors.bgSurface2,
                                shape: BorderDirectional(end: BorderSide(color: colors.borderSecondary)),
                                child: SingleChildScrollView(
                                  primary: false,
                                  padding: const EdgeInsets.all(PregoSpacing.md),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    spacing: PregoSpacing.xxs,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsetsDirectional.fromSTEB(
                                          _tabInset,
                                          // On the line of the page's own title beside it.
                                          PregoSpacing.sm - 1.5,
                                          _tabInset,
                                          PregoSpacing.lg + 1.5,
                                        ),
                                        child: Text(
                                          context.loc.settingsTitle,
                                          style: context.prego.textTheme.textMd.medium,
                                        ),
                                      ),
                                      for (final tab in DesktopSettingsTab.values)
                                        _SettingsTabRow(
                                          key: ValueKey("desktop-settings-tab-${tab.name}"),
                                          icon: _tabIcon(tab: tab),
                                          label: _tabLabel(context: context, tab: tab),
                                          selected: tab == _tab,
                                          onPressed: () => setState(() {
                                            _tab = tab;
                                            _bridgeSubpage = null;
                                          }),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Stack(
                                children: [
                                  KeyedSubtree(key: ValueKey(_tab), child: _page()),
                                  // The page's name, at one height on every tab, with the page
                                  // scrolling beneath it. A pushed page brings its own bar.
                                  if (_bridgeSubpage == null)
                                    PositionedDirectional(
                                      start: 0,
                                      end: 0,
                                      top: 0,
                                      height: SettingsWindowPage.topInset,
                                      child: ColoredBox(
                                        color: colors.bgSecondary,
                                        child: Padding(
                                          padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xl),
                                          child: Align(
                                            alignment: AlignmentDirectional.centerStart,
                                            child: Text(
                                              _tabLabel(context: context, tab: _tab),
                                              style: context.prego.textTheme.textMd.medium.copyWith(
                                                color: colors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  // The page visibly carries on below the fold.
                                  PositionedDirectional(
                                    start: 0,
                                    end: 0,
                                    bottom: 0,
                                    height: 32,
                                    child: IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [colors.bgSecondary.withValues(alpha: 0), colors.bgSecondary],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // One small plain close for every page; Esc closes too.
                                  PositionedDirectional(
                                    top: PregoSpacing.md,
                                    end: PregoSpacing.md,
                                    child: PregoButtonsSolid.iconOnly(
                                      key: const Key("desktop-settings-close"),
                                      leadingIcon: TablerRegular.x,
                                      semanticLabel: context.loc.settingsClose,
                                      showsTooltip: true,
                                      hierarchy: PregoButtonsSolidHierarchy.tertiary,
                                      size: PregoButtonsSolidSize.sm,
                                      onPressed: widget.onClose,
                                    ),
                                  ),
                                ],
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
    );
  }

  Widget _page() => switch (_tab) {
    DesktopSettingsTab.general => BlocProvider(
      create: (_) => DesktopUpdateCubit(service: getIt<DesktopUpdateService>()),
      child: const DesktopGeneralSettingsScreen(),
    ),
    DesktopSettingsTab.projects => ProjectsSettingsView(chrome: SettingsPageInWindow()),
    DesktopSettingsTab.bridge => MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => BridgeSettingsCubit(
            service: getIt<BridgeSettingsService>(),
            connectionService: getIt<ConnectionService>(),
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
          create: (_) => ComputersCubit(
            registeredBridgesService: getIt<RegisteredBridgesService>(),
            selectedComputerService: getIt<SelectedComputerService>(),
          ),
        ),
      ],
      child: _DesktopBridgeSettingsTab(
        onClose: widget.onClose,
        subpage: _bridgeSubpage,
        onShowSubpage: ({required subpage}) => setState(() => _bridgeSubpage = subpage),
      ),
    ),
    DesktopSettingsTab.notifications => BlocProvider(
      create: (_) => DesktopAttentionPreferenceCubit(service: getIt<DesktopAttentionService>()),
      child: const _DesktopNotificationSettingsPage(),
    ),
    DesktopSettingsTab.account => DesktopProfileScreen(onLogoutCompleted: widget.onLogoutCompleted),
  };
}

String _tabLabel({required BuildContext context, required DesktopSettingsTab tab}) => switch (tab) {
  DesktopSettingsTab.general => context.loc.desktopSettingsGeneral,
  DesktopSettingsTab.projects => context.loc.settingsProjectsTitle,
  DesktopSettingsTab.bridge => context.loc.settingsSectionBridge,
  DesktopSettingsTab.notifications => context.loc.settingsNotificationsTitle,
  DesktopSettingsTab.account => context.loc.settingsSectionAccount,
};

IconData _tabIcon({required DesktopSettingsTab tab}) => switch (tab) {
  DesktopSettingsTab.general => TablerRegular.settings,
  DesktopSettingsTab.projects => TablerRegular.folder,
  DesktopSettingsTab.bridge => TablerRegular.server,
  DesktopSettingsTab.notifications => TablerRegular.bell,
  DesktopSettingsTab.account => TablerRegular.user,
};

/// Start inset of the sidebar's title and tab row content.
const double _tabInset = PregoSpacing.md;

/// A settings tab in the main sidebar's row style: 13 medium, inset, with the
/// selected row filled.
class const _SettingsTabRow({
  super.key,
  required final IconData icon,
  required final String label,
  required final bool selected,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final color = selected ? prego.colors.textPrimary : prego.colors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(PregoRadius.sm),
        hoverColor: prego.colors.bgSecondaryHover.withValues(alpha: 0.5),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? desktopSidebarSelectedFill(prego.colors) : null,
            borderRadius: BorderRadius.circular(PregoRadius.sm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: _tabInset, vertical: 5),
          child: Row(
            spacing: PregoSpacing.md,
            children: [
              Icon(icon, size: 16, color: color),
              Expanded(
                child: Text(label, style: prego.textTheme.textSm.medium.copyWith(color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Bridge tab: its settings page, with the Harnesses page pushed over it
/// from its Harnesses row, or the Computers page from the computer entry's
/// menu.
class const _DesktopBridgeSettingsTab({
  required final VoidCallback onClose,
  required final _BridgeSubpage? subpage,
  required final void Function({required _BridgeSubpage? subpage}) onShowSubpage,
}) extends StatelessWidget {
  /// A switch lands on the new computer's Projects root, so the window steps
  /// aside for it.
  void _switchComputer({required String bridgeId, required ComputerSwitchSource source}) {
    onClose();
    unawaited(getIt<ComputerSwitchDispatcher>().switchTo(bridgeId: bridgeId, source: source));
  }

  void _back() => onShowSubpage(subpage: null);

  @override
  Widget build(BuildContext context) => _FadeThroughPages(
    child: Navigator(
      onDidRemovePage: (page) {
        if (page.key case ValueKey<_BridgeSubpage>()) _back();
      },
      pages: [
        MaterialPage<void>(
          child: _DesktopBridgeSettingsPage(
            onOpenHarnesses: () => onShowSubpage(subpage: _BridgeSubpage.harnesses),
            onSwitchComputer: _switchComputer,
            onManageComputers: () => onShowSubpage(subpage: _BridgeSubpage.computers),
          ),
        ),
        if (subpage case final subpage?)
          MaterialPage<void>(
            key: ValueKey(subpage),
            child: switch (subpage) {
              _BridgeSubpage.harnesses => _DesktopHarnessSettingsPage(onClose: onClose, onBack: _back),
              _BridgeSubpage.computers => ComputersView(
                chrome: SettingsPageInWindowSubpage(title: context.loc.computersTitle, onBack: _back),
                onSwitchComputer: _switchComputer,
                localBridgeTurnOffActionBuilder: (_) => const _TurnOffLocalBridgeAction(),
              ),
            },
          ),
      ],
    ),
  );
}

/// Turns off this computer's own bridge from the dialog that explains why this
/// computer cannot be removed. Nothing while the bridge is off or on its way
/// off.
class const _TurnOffLocalBridgeAction() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocBuilder<BridgeControlCubit, BridgeControlState>(
    builder: (context, state) => switch (state.toggleTarget) {
      BridgeProcessDesiredState.on => const SizedBox(width: double.infinity),
      BridgeProcessDesiredState.off => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.md),
        child: PregoButtonsSolid(
          key: const Key("desktop-computers-turn-off-bridge"),
          label: context.loc.computersTurnOffBridge,
          hierarchy: PregoButtonsSolidHierarchy.primary,
          size: PregoButtonsSolidSize.lg,
          fullWidth: true,
          onPressed: state.activity.locksCommands
              ? null
              : () => unawaited(context.read<BridgeControlCubit>().stopBridge()),
        ),
      ),
    },
  );
}

class const _DesktopBridgeSettingsPage({
  required final VoidCallback onOpenHarnesses,
  required final ComputerSwitchCallback onSwitchComputer,
  required final VoidCallback onManageComputers,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final control = context.watch<BridgeControlCubit>();
    final access = context.watch<FileAccessCubit>();
    return SettingsWindowPage(
      onRefresh: null,
      slivers: [
        SliverPadding(
          // A section heading leads this page, so its top matches the cards' on others.
          padding: const EdgeInsets.fromLTRB(PregoSpacing.xl, PregoSpacing.md, PregoSpacing.xl, PregoSpacing.xl),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: PregoSpacing.xl,
              children: [
                BridgeSettingsSection(
                  title: loc.desktopSettingsConnectedBridge,
                  description: loc.desktopSettingsConnectedBridgeDescription,
                  onOpenHarnesses: onOpenHarnesses,
                  onOpenProjects: null,
                  // The main window's sidebar holds Archived.
                  onOpenArchived: null,
                  onSwitchComputer: onSwitchComputer,
                  onManageComputers: onManageComputers,
                ),
                SettingsSection(
                  title: loc.desktopSettingsThisComputer,
                  child: PregoGroupedRows(
                    children: [
                      if (access.state.status != FileAccessStatus.unsupported)
                        PregoGroupedRow(
                          icon: TablerRegular.shield,
                          title: Text(loc.desktopFileAccessTitle),
                          subtitle: Text(switch (access.state.status) {
                            FileAccessStatus.granted => loc.desktopFileAccessGranted,
                            FileAccessStatus.denied => loc.desktopFileAccessDenied,
                            FileAccessStatus.unknown || FileAccessStatus.unsupported => loc.desktopFileAccessUnknown,
                          }),
                          trailing: Tooltip(
                            message: loc.desktopFileAccessOpenSettings,
                            child: const Icon(TablerRegular.external_link),
                          ),
                          onTap: access.openSystemSettings,
                        ),
                      PregoGroupedRow(
                        icon: TablerRegular.server,
                        title: Text(loc.desktopLocalBridgeTitle),
                        subtitle: Text(control.state.statusLabel),
                      ),
                      PregoGroupedRow(
                        icon: TablerRegular.file_text,
                        title: Text(loc.desktopBridgeOpenLogs),
                        trailing: const Icon(TablerRegular.external_link),
                        onTap: control.openLogs,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class const _DesktopNotificationSettingsPage() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SettingsWindowPage(
    onRefresh: null,
    slivers: [
      SliverPadding(
        padding: EdgeInsets.all(PregoSpacing.xl),
        sliver: SliverToBoxAdapter(child: DesktopAttentionPreferenceSection()),
      ),
    ],
  );
}

/// The harness overview and its detail pages, inside the Bridge tab.
class const _DesktopHarnessSettingsPage({
  required final VoidCallback onClose,

  /// Returns from the overview to the Bridge tab's own page.
  required final VoidCallback onBack,
}) extends StatefulWidget {
  @override
  State<_DesktopHarnessSettingsPage> createState() => _DesktopHarnessSettingsPageState();
}

class _DesktopHarnessSettingsPageState() extends State<_DesktopHarnessSettingsPage> {
  String? _pluginId;

  @override
  Widget build(BuildContext context) => DesktopHarnessesSettingsScreen(
    // The Bridge tab's fade-through moves these pages too.
    child: Navigator(
      onDidRemovePage: (page) {
        if (page.key case ValueKey<String>(:final value) when value == _pluginId) {
          setState(() => _pluginId = null);
        }
      },
      pages: [
        MaterialPage<void>(
          child: HarnessesSettingsView(
            chrome: HarnessSettingsChrome.window,
            connectionBanner: null,
            onClose: widget.onClose,
            onBack: widget.onBack,
            onOpenHarness: ({required pluginId}) => setState(() => _pluginId = pluginId),
          ),
        ),
        if (_pluginId case final pluginId?)
          MaterialPage<void>(
            key: ValueKey(pluginId),
            child: HarnessSettingsDetailView(
              pluginId: pluginId,
              onShowMcp: () => showMcpInventory(
                context: context,
                request: McpInventoryRequest(pluginId: pluginId, scope: const McpHarnessScope()),
                createService: getIt.call<McpService>,
                authenticationService: getIt.call<McpAuthenticationService>,
                mutationsAllowed: true,
              ),
              chrome: HarnessSettingsChrome.window,
              onBack: () => setState(() => _pluginId = null),
              onClose: widget.onClose,
              connectionBanner: null,
            ),
          ),
      ],
    ),
  );
}

/// Pages pushed inside a settings tab have no background of their own, so a
/// slide or cross-fade would show both at once; the old page fades out before
/// the new one fades in.
class const _FadeThroughPages({required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: _FadeThrough(
              transitionDuration: prefersReducedMotion(context) || GlassAccessibilityData.of(context).reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
            ),
        },
      ),
    ),
    child: child,
  );
}

class const _FadeThrough({@override required final Duration transitionDuration}) extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: const Interval(0.5, 1)),
    child: FadeTransition(
      opacity: ReverseAnimation(CurvedAnimation(parent: secondaryAnimation, curve: const Interval(0, 0.5))),
      child: child,
    ),
  );
}
