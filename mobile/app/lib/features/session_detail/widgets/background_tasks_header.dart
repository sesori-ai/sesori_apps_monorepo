import "package:flutter/material.dart";
import "package:theme_zyra/module_zyra.dart";
import "../../../core/extensions/build_context_x.dart";

class BackgroundTasksHeader extends StatelessWidget {
  final int runningCount;
  final int totalCount;
  final bool expanded;
  final VoidCallback onTap;

  const BackgroundTasksHeader({
    super.key,
    required this.runningCount,
    required this.totalCount,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
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
                  color: zyra.colors.bgBrandSolid,
                ),
              )
            else
              Icon(
                Icons.check_circle,
                size: 16,
                color: zyra.colors.bgBrandSolid,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasRunning ? loc.backgroundTasksRunning(runningCount) : loc.backgroundTasksCompleted,
                style: zyra.textTheme.textMd.bold.copyWith(
                  color: zyra.colors.textPrimary,
                ),
              ),
            ),
            Icon(
              expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
              size: 20,
              color: zyra.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
