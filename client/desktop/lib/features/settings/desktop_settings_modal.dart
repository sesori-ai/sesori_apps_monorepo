import "dart:ui" show ImageFilter;

import "package:flutter/foundation.dart";
import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
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
  harnesses,
  bridge,
  notifications,
  account,
}

/// Root presentation, not a product route: the underlying session stays mounted.
Future<void> showDesktopSettingsModal({
  required BuildContext context,
  required DesktopSettingsTab initialTab,
  required VoidCallback onLogoutCompleted,
}) async {
  final authGate = context.read<AuthGateCubit>();
  final reducedMotion = prefersReducedMotion(context) || GlassAccessibilityData.of(context).reduceMotion;
  await showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: context.loc.settingsClose,
    barrierColor: Colors.transparent,
    transitionDuration: reducedMotion ? Duration.zero : const Duration(milliseconds: 180),
    transitionBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    pageBuilder: (dialogContext, _, _) {
      void close() {
        // Logout can finish after the user has dismissed the dialog.
        if (!dialogContext.mounted) return;
        final route = ModalRoute.of(dialogContext);
        final navigator = route?.navigator;
        if (route?.isActive != true || navigator == null) return;
        // Owned authentication/setting sheets leave with their dialog.
        navigator.popUntil((candidate) => candidate == route);
        navigator.pop();
      }

      return BlocProvider<AuthGateCubit>.value(
        value: authGate,
        child: BlocListener<AuthGateCubit, AuthGateState>(
          // A definitive token-refresh rejection can sign out while this root
          // overlay is above the gated cockpit; dismiss its owned UI as well.
          listenWhen: (_, state) => state is AuthGateSignedOut,
          listener: (_, _) => close(),
          child: _DesktopSettingsModal(
            initialTab: initialTab,
            onClose: close,
            onLogoutCompleted: () {
              close();
              onLogoutCompleted();
            },
          ),
        ),
      );
    },
  );
}

class const _DesktopSettingsModal({
  required final DesktopSettingsTab initialTab,
  required final VoidCallback onClose,
  required final VoidCallback onLogoutCompleted,
}) extends StatefulWidget {
  @override
  State<_DesktopSettingsModal> createState() => _DesktopSettingsModalState();
}

class _DesktopSettingsModalState() extends State<_DesktopSettingsModal> {
  late DesktopSettingsTab _tab = widget.initialTab;

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
    final scrim = ColoredBox(color: colors.bgSurface1.withValues(alpha: blur ? 0.4 : 0.6));
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): widget.onClose},
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: blur ? BackdropFilter(filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), child: scrim) : scrim,
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(PregoSpacing.lg),
                child: SizedBox(
                  width: 860,
                  height: 640,
                  child: Material(
                    key: const Key("desktop-settings-modal"),
                    color: colors.bgSurface1,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PregoRadius.x4l),
                      side: BorderSide(color: colors.borderSecondary),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 160,
                          // A Material, not a ColoredBox: the tabs' selected Ink paints on it.
                          child: Material(
                            color: colors.bgSurface2,
                            child: SingleChildScrollView(
                              primary: false,
                              padding: const EdgeInsets.symmetric(vertical: PregoSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: _tabInset,
                                      vertical: PregoSpacing.xl,
                                    ),
                                    child: Text(
                                      context.loc.settingsTitle,
                                      style: context.prego.textTheme.textMd.bold,
                                    ),
                                  ),
                                  for (final tab in DesktopSettingsTab.values)
                                    _SettingsTabRow(
                                      key: ValueKey("desktop-settings-tab-${tab.name}"),
                                      icon: _tabIcon(tab: tab),
                                      label: _tabLabel(context: context, tab: tab),
                                      selected: tab == _tab,
                                      onPressed: () => setState(() => _tab = tab),
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
                              // One small plain close for every page; Esc closes too.
                              PositionedDirectional(
                                top: PregoSpacing.md,
                                end: PregoSpacing.md,
                                child: Semantics(
                                  label: context.loc.settingsClose,
                                  child: Tooltip(
                                    message: context.loc.settingsClose,
                                    excludeFromSemantics: true,
                                    child: PregoButtonsSolid.iconOnly(
                                      key: const Key("desktop-settings-close"),
                                      leadingIcon: TablerRegular.x,
                                      // Filled, so it stays legible over content scrolling beneath it.
                                      hierarchy: PregoButtonsSolidHierarchy.secondary,
                                      size: PregoButtonsSolidSize.sm,
                                      onPressed: widget.onClose,
                                    ),
                                  ),
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
          ],
        ),
      ),
    );
  }

  Widget _page() => switch (_tab) {
    DesktopSettingsTab.general => const DesktopGeneralSettingsScreen(),
    DesktopSettingsTab.harnesses => _DesktopHarnessSettingsPage(onClose: widget.onClose),
    DesktopSettingsTab.bridge => BlocProvider(
      create: (_) => BridgeSettingsCubit(
        repository: getIt<BridgeSettingsRepository>(),
        connectionService: getIt<ConnectionService>(),
      ),
      child: const _DesktopBridgeSettingsPage(),
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
  DesktopSettingsTab.harnesses => context.loc.settingsHarnessesTitle,
  DesktopSettingsTab.bridge => context.loc.settingsSectionBridge,
  DesktopSettingsTab.notifications => context.loc.settingsNotificationsTitle,
  DesktopSettingsTab.account => context.loc.settingsSectionAccount,
};

IconData _tabIcon({required DesktopSettingsTab tab}) => switch (tab) {
  DesktopSettingsTab.general => TablerRegular.settings,
  DesktopSettingsTab.harnesses => TablerRegular.plug,
  DesktopSettingsTab.bridge => TablerRegular.server,
  DesktopSettingsTab.notifications => TablerRegular.bell,
  DesktopSettingsTab.account => TablerRegular.user,
};

/// Start inset of the sidebar's title and tab rows.
const double _tabInset = PregoSpacing.xl;

/// A settings tab in the main sidebar's row style: 14 medium, and the selected
/// row filled across the sidebar's width.
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
        onTap: onPressed,
        hoverColor: prego.colors.bgSecondaryHover,
        child: Ink(
          color: selected ? desktopSidebarSelectedFill(prego.colors) : null,
          padding: const EdgeInsets.symmetric(horizontal: _tabInset, vertical: PregoSpacing.sm),
          child: Row(
            spacing: PregoSpacing.md,
            children: [
              Icon(icon, size: PregoIconSize.md, color: color),
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

class const _DesktopBridgeSettingsPage() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final control = context.watch<BridgeControlCubit>();
    final access = context.watch<FileAccessCubit>();
    return SettingsWindowPage(
      onRefresh: null,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(PregoSpacing.xl),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: PregoSpacing.xl,
              children: [
                BridgeSettingsSection(
                  title: loc.desktopSettingsConnectedBridge,
                  description: loc.desktopSettingsConnectedBridgeDescription,
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

class const _DesktopHarnessSettingsPage({required final VoidCallback onClose}) extends StatefulWidget {
  @override
  State<_DesktopHarnessSettingsPage> createState() => _DesktopHarnessSettingsPageState();
}

class _DesktopHarnessSettingsPageState() extends State<_DesktopHarnessSettingsPage> {
  String? _pluginId;

  @override
  Widget build(BuildContext context) => DesktopHarnessesSettingsScreen(
    // The pages have no background of their own, so a slide or cross-fade
    // would show both at once; the old page fades out before the new one fades in.
    child: Theme(
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
              onBack: null,
              onOpenHarness: ({required pluginId}) => setState(() => _pluginId = pluginId),
            ),
          ),
          if (_pluginId case final pluginId?)
            MaterialPage<void>(
              key: ValueKey(pluginId),
              child: HarnessSettingsDetailView(
                pluginId: pluginId,
                chrome: HarnessSettingsChrome.window,
                onBack: () => setState(() => _pluginId = null),
                onClose: widget.onClose,
                connectionBanner: null,
              ),
            ),
        ],
      ),
    ),
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
