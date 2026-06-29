import "package:flutter/material.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:theme_prego/module_prego.dart";
import "../../../core/extensions/build_context_x.dart";

/// Tappable header row of the background-tasks glass card. Shows a spinner +
/// "N Tasks Running" (or a check + "Completed") and a chevron that rotates as
/// the card expands. Rendered as a [GlassListTile] so it shares the card's
/// glass surface and press feedback with the task rows below it.
class BackgroundTasksHeader extends StatelessWidget {
  final int runningCount;
  final bool expanded;
  final VoidCallback onTap;

  const BackgroundTasksHeader({
    super.key,
    required this.runningCount,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final hasRunning = runningCount > 0;

    return GlassListTile(
      onTap: onTap,
      showDivider: false,
      leading: hasRunning
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: prego.colors.bgBrandSolid,
              ),
            )
          : Icon(
              Icons.check_circle,
              size: 16,
              color: prego.colors.bgBrandSolid,
            ),
      title: Text(hasRunning ? loc.backgroundTasksRunning(runningCount) : loc.backgroundTasksCompleted),
      titleStyle: prego.textTheme.textMd.bold.copyWith(color: prego.colors.textPrimary),
      trailing: AnimatedRotation(
        turns: expanded ? 0.5 : 0.0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        child: Icon(
          Icons.keyboard_arrow_down,
          size: 20,
          color: prego.colors.textSecondary,
        ),
      ),
    );
  }
}
