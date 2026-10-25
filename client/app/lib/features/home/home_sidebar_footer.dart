import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/routing/app_router.dart";
import "onboarding/bridge_onboarding.dart";

/// The phone and tablet sidebar's footer (D10): the computer switcher, then
/// Archived (D6), Settings and collapse.
class const HomeSidebarFooter({super.key, required final VoidCallback onCollapse}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final computer = homeComputerSubtitle(
      context: context,
      onSwitchComputer: switchComputer,
      onManageComputers: manageComputers,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(PregoSpacing.lg, PregoSpacing.md, PregoSpacing.md, PregoSpacing.md),
      child: Row(
        spacing: PregoSpacing.sm,
        children: [
          Expanded(
            child: Align(alignment: AlignmentDirectional.centerStart, child: computer ?? const SizedBox.shrink()),
          ),
          PregoButtonsIconGlass(
            key: const Key("home-archived"),
            icon: TablerRegular.archive,
            size: PregoButtonsIconGlassSize.md,
            semanticLabel: loc.archivedSessionsTitle,
            onPressed: () => context.pushRoute(const AppRoute.archivedSessions()),
          ),
          PregoButtonsIconGlass(
            key: const Key("home-settings"),
            icon: VESPRSolid.gear,
            size: PregoButtonsIconGlassSize.md,
            semanticLabel: loc.settingsTitle,
            onPressed: () => context.pushRoute(const AppRoute.settings()),
          ),
          PregoButtonsIconGlass(
            key: const Key("session-sidebar-collapse"),
            icon: TablerRegular.layout_sidebar_left_collapse,
            size: PregoButtonsIconGlassSize.md,
            semanticLabel: loc.sessionSidebarCollapse,
            onPressed: onCollapse,
          ),
        ],
      ),
    );
  }
}
