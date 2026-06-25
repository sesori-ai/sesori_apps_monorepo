import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";
import "background_task_row.dart";
import "background_tasks_toggle.dart";

class BackgroundTasksList extends StatelessWidget {
  final String? projectId;
  final List<Session> runningTasks;
  final List<Session> completedTasks;
  final Map<String, SessionStatus> childStatuses;
  final bool showCompleted;
  final VoidCallback onToggleCompleted;

  const BackgroundTasksList({
    super.key,
    required this.projectId,
    required this.runningTasks,
    required this.completedTasks,
    required this.childStatuses,
    required this.showCompleted,
    required this.onToggleCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final hasRunning = runningTasks.isNotEmpty;
    final hasCompleted = completedTasks.isNotEmpty;

    // When no running tasks, show completed directly (no toggle needed).
    final visibleTasks = hasRunning ? [...runningTasks, if (showCompleted) ...completedTasks] : completedTasks;

    // Show toggle only when there's a mix of running and completed.
    final showToggle = hasRunning && hasCompleted;

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: prego.colors.borderSecondary,
            width: 0.5,
          ),
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: visibleTasks.length + (showToggle ? 1 : 0),
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 42,
          color: prego.colors.borderSecondary.withValues(alpha: 0.5),
        ),
        itemBuilder: (context, index) {
          // Toggle button goes after visible tasks.
          if (index == visibleTasks.length) {
            return BackgroundTasksToggle(
              completedCount: completedTasks.length,
              showCompleted: showCompleted,
              onTap: onToggleCompleted,
            );
          }

          final child = visibleTasks[index];
          return BackgroundTaskRow(
            projectId: projectId,
            session: child,
            status: childStatuses[child.id],
          );
        },
      ),
    );
  }
}
