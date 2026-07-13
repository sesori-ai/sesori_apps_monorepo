import "package:flutter/material.dart";
import "package:theme_prego/module_prego.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/throttled_activity_indicator.dart";

/// Tappable header row of the background-tasks card. Shows a spinner +
/// "N Tasks Running" (or a check + "Completed") and a chevron that rotates as
/// the card expands. Rendered as a [PregoListTile] so it shares the card's
/// surface and press feedback with the task rows below it.
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

    return PregoListTile(
      onTap: onTap,
      showDivider: false,
      leading: hasRunning
          // The leading slot is a tight 32px wide but leaves its height free. A
          // CircularProgressIndicator has no intrinsic size and paints to its box
          // without preserving aspect ratio, so it renders as an oval. Center
          // re-loosens the constraints around a fixed square so the spinner
          // stays a 16px circle.
          ? Center(
              heightFactor: 1,
              child: SizedBox.square(
                dimension: 16,
                child: ThrottledActivityIndicator(
                  strokeWidth: 2,
                  color: prego.colors.bgBrandSolid,
                ),
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
