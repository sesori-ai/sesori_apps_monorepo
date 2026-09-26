import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// The collapsed rail has no room for Activity rows, so its one Activity
/// button pops the list out beside the rail instead of over its project chips.
class const DesktopSidebarActivityPopout({
  super.key,
  required final double railStart,
  required final PregoPopoverTriggerBuilder triggerBuilder,
  required final PregoPopoverContentBuilder contentBuilder,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // The rail floats [railStart] from the window's start edge, so the popout
    // may begin past that and the rail's width.
    builder: (context, constraints) => PregoPopover(
      popoverWidth: 300,
      popoverMaxHeight: null,
      contentScrolls: false,
      onClosed: null,
      popoverBorderRadius: PregoRadius.lg,
      screenPadding: EdgeInsetsDirectional.fromSTEB(
        railStart + constraints.maxWidth + PregoSpacing.md,
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
