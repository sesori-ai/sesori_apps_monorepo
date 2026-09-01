import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:theme_prego/module_prego.dart";

/// Tappable header row of the background-tasks card. Shows a spinner +
/// "N Tasks Running" (or a check + "Completed") and a chevron that rotates as
/// the card expands. Rendered as a [PregoListTile] so it shares the card's
/// surface and press feedback with the task rows below it.
class const BackgroundTasksHeader({
  super.key,
  required final int runningCount,
  required final bool expanded,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final hasRunning = runningCount > 0;

    return PregoListTile(
      onTap: onTap,
      showDivider: false,
      leading: hasRunning
          // The leading slot is a tight 32px wide but leaves its height free.
          // Center re-loosens those constraints around a fixed 16px square.
          ? Center(
              heightFactor: 1,
              child: SizedBox.square(
                dimension: 16,
                child: PregoActivityIndicator(
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
