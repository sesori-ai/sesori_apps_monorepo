import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "background_task_row.dart";
import "background_tasks_toggle.dart";

/// The expandable body of the background-tasks card: a divider under the
/// header, then the scrollable list of task rows. Running tasks come first;
/// completed tasks appear after a "Show N completed" toggle.
class const BackgroundTasksList({
  super.key,
  required final String? projectId,
  required final String? bridgeId,
  required final List<Session> runningTasks,
  required final List<Session> completedTasks,
  required final Map<String, SessionStatus> childStatuses,
  required final bool showCompleted,
  required final VoidCallback onToggleCompleted,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hasRunning = runningTasks.isNotEmpty;
    final hasCompleted = completedTasks.isNotEmpty;

    // When no running tasks, show completed directly (no toggle needed).
    final visibleTasks = hasRunning ? [...runningTasks, if (showCompleted) ...completedTasks] : completedTasks;

    // Show toggle only when there's a mix of running and completed.
    final showToggle = hasRunning && hasCompleted;
    final itemCount = visibleTasks.length + (showToggle ? 1 : 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PregoDivider(flat: true),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              // Toggle button goes after the visible tasks, as the last row.
              if (showToggle && index == visibleTasks.length) {
                return BackgroundTasksToggle(
                  completedCount: completedTasks.length,
                  showCompleted: showCompleted,
                  onTap: onToggleCompleted,
                );
              }

              final child = visibleTasks[index];
              // Suppress the final row's divider only when nothing follows it.
              final isLast = !showToggle && index == visibleTasks.length - 1;
              return BackgroundTaskRow(
                projectId: projectId,
                bridgeId: bridgeId,
                session: child,
                status: childStatuses[child.id],
                isLast: isLast,
              );
            },
          ),
        ),
      ],
    );
  }
}
