import "package:flutter/material.dart";
import "package:theme_prego/module_prego.dart";
import "../../../core/extensions/build_context_x.dart";

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

    return InkWell(
      borderRadius: expanded ? const BorderRadius.vertical(top: Radius.circular(12)) : BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            if (hasRunning)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: prego.colors.bgBrandSolid,
                ),
              )
            else
              Icon(
                Icons.check_circle,
                size: 16,
                color: prego.colors.bgBrandSolid,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasRunning ? loc.backgroundTasksRunning(runningCount) : loc.backgroundTasksCompleted,
                style: prego.textTheme.textMd.bold.copyWith(
                  color: prego.colors.textPrimary,
                ),
              ),
            ),
            Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 20,
              color: prego.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
