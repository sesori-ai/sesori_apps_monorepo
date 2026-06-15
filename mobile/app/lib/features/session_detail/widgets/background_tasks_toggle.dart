import "package:flutter/material.dart";
import "package:theme_prego/module_prego.dart";
import "../../../core/extensions/build_context_x.dart";

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

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              showCompleted ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 16,
              color: prego.colors.bgBrandSolid,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                showCompleted ? loc.backgroundTasksHideCompleted : loc.backgroundTasksShowCompleted(completedCount),
                style: prego.textTheme.textSm.bold.copyWith(
                  color: prego.colors.bgBrandSolid,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
