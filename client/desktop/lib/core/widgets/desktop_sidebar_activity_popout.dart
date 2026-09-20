import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// The collapsed rail has no room for Activity rows, so its one Activity
/// button pops the list out beside the rail instead of over its project chips.
class const DesktopSidebarActivityPopout({
  super.key,
  required final PregoPopoverTriggerBuilder triggerBuilder,
  required final PregoPopoverContentBuilder contentBuilder,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // The rail spans the window's start edge, so its width is where the popout
    // may begin.
    builder: (context, constraints) => PregoPopover(
      popoverWidth: 300,
      popoverBorderRadius: PregoRadius.lg,
      screenPadding: EdgeInsetsDirectional.fromSTEB(
        constraints.maxWidth + PregoSpacing.md,
        PregoSpacing.lg,
        PregoSpacing.lg,
        PregoSpacing.lg,
      ).resolve(Directionality.of(context)),
      triggerBuilder: triggerBuilder,
      contentBuilder: (context, close) => Padding(
        key: const Key("desktop-sidebar-activity-popout"),
        padding: const EdgeInsets.symmetric(vertical: PregoSpacing.sm),
        child: contentBuilder(context, close),
      ),
    ),
  );
}
