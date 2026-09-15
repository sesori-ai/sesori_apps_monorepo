import "dart:ui" show ImageFilter;

import "package:flutter/foundation.dart";
import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
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

/// Root presentation, not a product route: the session behind it stays current.
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
        final route = ModalRoute.of(dialogContext)!;
        if (!route.isActive) return;
        final navigator = route.navigator!;
        // Owned authentication/setting sheets leave with their dialog.
        navigator.popUntil((candidate) => candidate == route);
        navigator.pop();
      }

      return BlocProvider<AuthGateCubit>.value(
        value: authGate,
        child: _DesktopSettingsModal(
          initialTab: initialTab,
          onClose: close,
          onLogoutCompleted: () {
            close();
            onLogoutCompleted();
          },
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
                      children: [
                        SizedBox(
                          width: 160,
                          child: ColoredBox(
                            color: colors.bgSurface2,
                            child: Padding(
                              padding: const EdgeInsets.all(PregoSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: PregoSpacing.xl),
                                    child: Text(context.loc.settingsTitle, style: context.prego.textTheme.textMd.bold),
                                  ),
                                  for (final tab in DesktopSettingsTab.values)
                                    Semantics(
                                      selected: tab == _tab,
                                      child: TextButton.icon(
                                        key: ValueKey("desktop-settings-tab-${tab.name}"),
                                        style: TextButton.styleFrom(
                                          alignment: AlignmentDirectional.centerStart,
                                          foregroundColor: tab == _tab ? colors.fgBrandPrimary : colors.textSecondary,
                                          backgroundColor: tab == _tab ? colors.bgSurface3 : Colors.transparent,
                                          padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.sm),
                                        ),
                                        onPressed: () => setState(() => _tab = tab),
                                        icon: Icon(_tabIcon(tab: tab), size: 18),
                                        label: Text(_tabLabel(context: context, tab: tab)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: KeyedSubtree(key: ValueKey(_tab), child: _page()),
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
    DesktopSettingsTab.general => DesktopGeneralSettingsScreen(onClose: widget.onClose),
    DesktopSettingsTab.harnesses => _DesktopHarnessSettingsPage(onClose: widget.onClose),
    DesktopSettingsTab.bridge => BlocProvider(
      create: (_) => BridgeSettingsCubit(
        repository: getIt<BridgeSettingsRepository>(),
        connectionService: getIt<ConnectionService>(),
      ),
      child: _DesktopBridgeSettingsPage(onClose: widget.onClose),
    ),
    DesktopSettingsTab.notifications => BlocProvider(
      create: (_) => DesktopAttentionPreferenceCubit(service: getIt<DesktopAttentionService>()),
      child: _DesktopNotificationSettingsPage(onClose: widget.onClose),
    ),
    DesktopSettingsTab.account => DesktopProfileScreen(
      onClose: widget.onClose,
      onLogoutCompleted: widget.onLogoutCompleted,
    ),
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

class const _DesktopBridgeSettingsPage({required final VoidCallback onClose}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final control = context.watch<BridgeControlCubit>();
    return PregoGlassScaffold(
      title: loc.settingsSectionBridge,
      titleMode: PregoTopNavigationTitleMode.inline,
      automaticallyImplyLeading: false,
      actions: [PregoButtonsIconGlass(icon: TablerRegular.x, semanticLabel: loc.settingsClose, onPressed: onClose)],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(PregoSpacing.xl),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: PregoSpacing.xl,
              children: [
                Text(loc.desktopSettingsConnectedBridgeDescription, style: context.prego.textTheme.textSm.regular),
                BridgeSettingsSection(title: loc.desktopSettingsConnectedBridge),
                SettingsSection(
                  title: loc.desktopSettingsThisComputer,
                  child: PregoGroupedRows(
                    children: [
                      PregoGroupedRow(
                        icon: TablerRegular.server,
                        title: Text(loc.desktopLocalBridgeTitle),
                        subtitle: Text(control.state.statusLabel),
                      ),
                      PregoGroupedRow(
                        icon: TablerRegular.file_text,
                        title: Text(loc.desktopBridgeOpenLogs),
                        onTap: () => unawaited(control.openLogs()),
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

class const _DesktopNotificationSettingsPage({required final VoidCallback onClose}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PregoGlassScaffold(
    title: context.loc.settingsNotificationsTitle,
    titleMode: PregoTopNavigationTitleMode.inline,
    automaticallyImplyLeading: false,
    actions: [
      PregoButtonsIconGlass(icon: TablerRegular.x, semanticLabel: context.loc.settingsClose, onPressed: onClose),
    ],
    slivers: const [
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
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => DesktopHarnessesSettingsScreen(
    child: Navigator(
      key: _navigator,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => HarnessesSettingsView(
          presentation: HarnessSettingsPresentation.modal,
          connectionBanner: null,
          onClose: widget.onClose,
          onBack: null,
          onOpenHarness: _openHarness,
        ),
      ),
    ),
  );

  void _openHarness({required String pluginId}) {
    _navigator.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HarnessSettingsDetailView(
          pluginId: pluginId,
          presentation: HarnessSettingsPresentation.modal,
          onBack: () => _navigator.currentState!.pop(),
          onClose: widget.onClose,
          connectionBanner: null,
        ),
      ),
    );
  }
}
