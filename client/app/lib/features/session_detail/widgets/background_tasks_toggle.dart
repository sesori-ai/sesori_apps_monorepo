import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";

/// The "Show / Hide N completed" toggle row at the bottom of the tasks card.
/// Rendered as a brand-tinted [PregoListTile] so it aligns with the task rows
/// above it but reads as an action rather than a navigable task.
class const BackgroundTasksToggle({
  super.key,
  required final int completedCount,
  required final bool showCompleted,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    return PregoListTile(
      onTap: onTap,
      isLast: true,
      showDivider: false,
      leading: Icon(
        showCompleted ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 16,
        color: prego.colors.bgBrandSolid,
      ),
      title: Text(showCompleted ? loc.backgroundTasksHideCompleted : loc.backgroundTasksShowCompleted(completedCount)),
      titleStyle: prego.textTheme.textSm.bold.copyWith(color: prego.colors.bgBrandSolid),
    );
  }
}
