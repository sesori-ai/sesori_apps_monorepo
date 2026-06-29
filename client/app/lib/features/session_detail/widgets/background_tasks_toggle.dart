import "package:flutter/material.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:theme_prego/module_prego.dart";
import "../../../core/extensions/build_context_x.dart";

/// The "Show / Hide N completed" toggle row at the bottom of the tasks card.
/// Rendered as a brand-tinted [GlassListTile] so it aligns with the task rows
/// above it but reads as an action rather than a navigable task.
class BackgroundTasksToggle extends StatelessWidget {
  final int completedCount;
  final bool showCompleted;
  final VoidCallback onTap;

  const BackgroundTasksToggle({
    super.key,
    required this.completedCount,
    required this.showCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    return GlassListTile(
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
